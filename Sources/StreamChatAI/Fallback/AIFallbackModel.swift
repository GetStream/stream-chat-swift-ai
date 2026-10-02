//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation

/// A model an app answers with when its AI agent can't: the person is offline, the agent
/// reached its usage limit, or the backend isn't responding.
///
/// `AIOnDeviceModel` runs Apple's on-device model. Conform a type of your own to answer with
/// another one, such as a model you ship with the app or a second backend, and list it in
/// `AIModelFallback.models`.
///
/// A fallback model knows only what it is given: the instructions and the conversation so
/// far. It has none of your agent's tools, files or memory, so say so in the instructions.
public protocol AIFallbackModel: Sendable {
    /// The model's name, for people: "On-device model".
    var name: String { get }
    /// Whether the model needs a network connection. One that does is skipped while the
    /// device is offline.
    var requiresNetwork: Bool { get }
    /// Whether the model can answer now, and why not.
    var availability: AIFallbackModelAvailability { get }
    /// Streams the answer to the last turn of `request.turns`. Each element is the whole
    /// answer so far. Cancelling the iteration stops the model.
    func reply(to request: AIFallbackRequest) -> AsyncThrowingStream<String, Error>
}

/// Whether a fallback model can answer now.
public enum AIFallbackModelAvailability: Equatable, Sendable {
    case available
    case unavailable(Reason)

    /// Why a model can't answer. An open set: compare against the reasons you know.
    public struct Reason: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
        public let rawValue: String

        public init(rawValue: String) { self.rawValue = rawValue }
        public init(stringLiteral value: String) { rawValue = value }
        public var description: String { rawValue }

        /// This device can't run the model.
        public static let deviceNotEligible: Reason = "device_not_eligible"
        /// The model is turned off, such as Apple Intelligence in Settings.
        public static let notEnabled: Reason = "not_enabled"
        /// The model is still downloading or getting ready.
        public static let notReady: Reason = "not_ready"
        /// This version of the OS has no such model.
        public static let unsupportedOS: Reason = "unsupported_os"
    }

    public var isAvailable: Bool { self == .available }
}

/// One turn of a conversation, for a fallback model.
public struct AIConversationTurn: Equatable, Sendable {
    public enum Role: String, Sendable {
        /// A person in the conversation.
        case user
        /// The assistant, your agent or a fallback model.
        case assistant
    }

    public var role: Role
    public var text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }

    /// A person's turn.
    public static func user(_ text: String) -> AIConversationTurn {
        AIConversationTurn(role: .user, text: text)
    }

    /// The assistant's turn.
    public static func assistant(_ text: String) -> AIConversationTurn {
        AIConversationTurn(role: .assistant, text: text)
    }
}

/// What a fallback model answers.
public struct AIFallbackRequest: Equatable, Sendable {
    /// What the model is told before the conversation: who it is answering as, why it is
    /// answering, and what it can't do.
    public var instructions: String
    /// The conversation so far, oldest first, ending with the person's question. A model
    /// whose context is smaller leaves out the oldest turns.
    public var turns: [AIConversationTurn]
    /// The longest answer, in tokens. `nil` leaves it to the model.
    public var maximumResponseTokens: Int?
    /// How varied the answer is, from 0 to 1. `nil` leaves it to the model.
    public var temperature: Double?

    public init(
        instructions: String,
        turns: [AIConversationTurn],
        maximumResponseTokens: Int? = nil,
        temperature: Double? = nil
    ) {
        self.instructions = instructions
        self.turns = turns
        self.maximumResponseTokens = maximumResponseTokens
        self.temperature = temperature
    }
}

/// Why a fallback model couldn't answer.
public struct AIFallbackModelError: LocalizedError, Equatable, Sendable {
    /// An open set: compare against the codes you know.
    public struct Code: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
        public let rawValue: String

        public init(rawValue: String) { self.rawValue = rawValue }
        public init(stringLiteral value: String) { rawValue = value }
        public var description: String { rawValue }

        /// The model isn't available on this device now.
        public static let unavailable: Code = "unavailable"
        /// Even the question alone is too long for the model.
        public static let contextTooLong: Code = "context_too_long"
        /// The model declined to answer, or its safety checks stopped the answer.
        public static let refused: Code = "refused"
        /// The model doesn't support the conversation's language.
        public static let unsupportedLanguage: Code = "unsupported_language"
        /// The model is answering something else, or was asked too often.
        public static let busy: Code = "busy"
        /// Anything else.
        public static let failed: Code = "failed"
    }

    public var code: Code
    /// What went wrong, for logs. It isn't shown to people.
    public var debugDescription: String?

    public init(code: Code, debugDescription: String? = nil) {
        self.code = code
        self.debugDescription = debugDescription
    }

    public var errorDescription: String? {
        switch code {
        case .unavailable: L10n.Fallback.errorUnavailable
        case .contextTooLong: L10n.Fallback.errorContextTooLong
        case .refused: L10n.Fallback.errorRefused
        case .unsupportedLanguage: L10n.Fallback.errorUnsupportedLanguage
        case .busy: L10n.Fallback.errorBusy
        default: L10n.Fallback.errorFailed
        }
    }
}

extension AIConversationTurn {
    /// A conservative token estimate: about three bytes of UTF-8 a token, which overcounts
    /// English and roughly matches scripts whose characters take three bytes each.
    static func estimatedTokens(_ text: String) -> Int {
        text.utf8.count / 3 + 1
    }

    /// The newest turns that fit `budget` tokens, oldest first, with consecutive turns of one
    /// role merged. The last turn is always kept, even when it alone is over the budget.
    static func fitting(_ turns: [AIConversationTurn], tokens budget: Int) -> [AIConversationTurn] {
        var merged: [AIConversationTurn] = []
        for turn in turns where !turn.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let last = merged.last, last.role == turn.role {
                merged[merged.count - 1].text = last.text + "\n\n" + turn.text
            } else {
                merged.append(turn)
            }
        }
        guard let question = merged.popLast() else { return [] }
        var kept = [question]
        var remaining = budget - estimatedTokens(question.text)
        for turn in merged.reversed() {
            remaining -= estimatedTokens(turn.text)
            guard remaining >= 0 else { break }
            kept.append(turn)
        }
        // A model's history starts with the person.
        while kept.count > 1, kept.last?.role == .assistant {
            kept.removeLast()
        }
        return kept.reversed()
    }
}
