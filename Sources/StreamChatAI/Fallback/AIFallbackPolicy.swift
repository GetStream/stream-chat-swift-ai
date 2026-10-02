//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation

/// Why an answer comes from a fallback model instead of your agent. An open set: compare
/// against the reasons you know.
public struct AIFallbackReason: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }
    public var description: String { rawValue }

    /// The device has no network connection.
    public static let offline: AIFallbackReason = "offline"
    /// The agent turned the request down because the person, or the app, reached a usage
    /// limit.
    public static let limitReached: AIFallbackReason = "limit_reached"
    /// The agent or its backend isn't responding.
    public static let unavailable: AIFallbackReason = "unavailable"
    /// The person asked for the fallback model.
    public static let chosen: AIFallbackReason = "chosen"

    /// The reason in a few words, for people: "You're offline". `nil` for `chosen` and for
    /// reasons of your own.
    public var localizedDescription: String? {
        switch self {
        case .offline: L10n.Fallback.reasonOffline
        case .limitReached: L10n.Fallback.reasonLimitReached
        case .unavailable: L10n.Fallback.reasonUnavailable
        default: nil
        }
    }
}

/// Decides when a request your agent couldn't take is answered by a fallback model.
///
/// It reads URL errors itself. Teach it your backend's errors with `classify`, which runs
/// first; return `nil` from it to leave an error to the built-in reading.
///
/// ```swift
/// let policy = AIFallbackPolicy { error in
///     guard let error = error as? BackendError else { return nil }
///     return AIFallbackPolicy.reason(forHTTPStatus: error.status)
/// }
/// ```
///
/// Fall back only when the agent did not take the request, or when sending it again later is
/// safe. A request that timed out may still have reached your agent, so give each one an ID
/// your backend deduplicates.
public struct AIFallbackPolicy: Sendable {
    /// The reasons that fall back. All of `offline`, `limitReached` and `unavailable` by
    /// default: remove one to show the error instead.
    public var reasons: Set<AIFallbackReason>
    /// Reads an error as a reason before the built-in reading does.
    public var classify: (@Sendable (Error) -> AIFallbackReason?)?

    public init(
        reasons: Set<AIFallbackReason> = [.offline, .limitReached, .unavailable],
        classify: (@Sendable (Error) -> AIFallbackReason?)? = nil
    ) {
        self.reasons = reasons
        self.classify = classify
    }

    /// Why a request that failed with `error` should be answered by a fallback model, or
    /// `nil` when it shouldn't.
    public func reason(for error: Error) -> AIFallbackReason? {
        let reason = classify?(error) ?? (error as? URLError).flatMap(Self.reason(for:))
        return reason.flatMap { reasons.contains($0) ? $0 : nil }
    }

    /// Reads a URL error: no connection is `offline`; a host that can't be found or reached,
    /// or a request that timed out, is `unavailable`.
    public static func reason(for error: URLError) -> AIFallbackReason? {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            return .offline
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .timedOut:
            return .unavailable
        default:
            return nil
        }
    }

    /// Reads an HTTP status: 429 is `limitReached`; 502, 503 and 504 are `unavailable`.
    public static func reason(forHTTPStatus status: Int) -> AIFallbackReason? {
        switch status {
        case 429: .limitReached
        case 502, 503, 504: .unavailable
        default: nil
        }
    }
}
