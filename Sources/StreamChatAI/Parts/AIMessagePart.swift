//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation

/// One step an AI agent took while replying: a round of reasoning, a tool call, or a step
/// this version of the SDK does not know how to show.
///
/// The agent writes each step as a custom attachment on its reply (`ai_reasoning`,
/// `ai_tool_call`), and the order of the attachments is the order of the steps. The final
/// answer stays in the message text and is shown after them. Decoding is lenient: missing
/// fields get defaults, unknown statuses become `.unknown`, and a step newer than this SDK
/// understands becomes `.unsupported` rather than disappearing.
///
/// ```swift
/// let parts = AIMessagePart.parts(from: message.allAttachments.map { ($0.type.rawValue, $0.payload) })
/// ```
public enum AIMessagePart: Identifiable, Equatable, Sendable {
    case reasoning(AIReasoningPart)
    case toolCall(AIToolCallPart)
    /// An AI step this version can't show. Show a neutral placeholder rather than nothing.
    case unsupported(AIUnsupportedPart)

    /// The attachment type prefix every AI step uses.
    public static let typePrefix = "ai_"
    /// The newest format version this SDK understands.
    public static let supportedVersion = 1

    /// The step's stable identity, for diffing and animating while it streams. Tool calls
    /// use the model provider's tool-call ID.
    public var id: String {
        switch self {
        case let .reasoning(part): part.id
        case let .toolCall(part): part.id
        case let .unsupported(part): part.id
        }
    }

    /// Decodes the AI steps among a message's attachments, in order. Attachments that are
    /// not AI steps (images, files and so on) are skipped.
    public static func parts(from attachments: [(type: String, payload: Data)]) -> [AIMessagePart] {
        attachments.enumerated().compactMap { index, attachment in
            AIMessagePart(type: attachment.type, payload: attachment.payload, position: index)
        }
    }

    /// Decodes one attachment, or returns `nil` when it is not an AI step.
    /// - Parameter position: The attachment's index, used as the identity of a step that
    ///   carries no ID of its own.
    public init?(type: String, payload: Data, position: Int = 0) {
        guard type.hasPrefix(Self.typePrefix) else { return nil }
        let object = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any] ?? [:]
        let fields = Fields(object)
        let id = fields.string("id") ?? "\(type)-\(position)"
        let version = fields.int("v") ?? 1
        guard version <= Self.supportedVersion else {
            self = .unsupported(AIUnsupportedPart(id: id, type: type, version: version))
            return
        }
        switch type {
        case AIReasoningPart.attachmentType:
            self = .reasoning(AIReasoningPart(id: id, fields))
        case AIToolCallPart.attachmentType:
            self = .toolCall(AIToolCallPart(id: id, fields))
        default:
            self = .unsupported(AIUnsupportedPart(id: id, type: type, version: version))
        }
    }
}

/// A round of the model's reasoning.
public struct AIReasoningPart: Identifiable, Equatable, Sendable {
    public static let attachmentType = "ai_reasoning"

    public enum Status: Equatable, Sendable {
        case streaming
        case completed
        case unknown(String)

        init(_ raw: String?) {
            switch raw {
            case "streaming": self = .streaming
            case "completed", nil: self = .completed
            case let other?: self = .unknown(other)
            }
        }
    }

    public var id: String
    public var status: Status
    /// A one-line summary of the reasoning, once it is done.
    public var summary: String?
    /// A capped excerpt: the latest thoughts while streaming, the opening once done. The
    /// full reasoning, when an app has it, arrives separately.
    public var preview: String?
    public var durationMS: Int?

    public var duration: TimeInterval? { durationMS.map { TimeInterval($0) / 1000 } }
    public var isStreaming: Bool { status == .streaming }

    public init(id: String, status: Status, summary: String? = nil, preview: String? = nil, durationMS: Int? = nil) {
        self.id = id
        self.status = status
        self.summary = summary
        self.preview = preview
        self.durationMS = durationMS
    }

    init(id: String, _ fields: Fields) {
        self.init(
            id: id,
            status: Status(fields.string("status")),
            summary: fields.string("summary"),
            preview: fields.string("preview"),
            durationMS: fields.int("duration_ms")
        )
    }
}

/// A tool the agent called, run by the agent's backend or by a person's device.
public struct AIToolCallPart: Identifiable, Equatable, Sendable {
    public static let attachmentType = "ai_tool_call"

    public enum Status: Equatable, Sendable {
        case running
        /// Waiting for the targeted device to run the tool and send its result.
        case awaitingClient
        case completed
        case failed
        case cancelled
        case unknown(String)

        init(_ raw: String?) {
            switch raw {
            case "running", "queued", nil: self = .running
            case "awaiting_client": self = .awaitingClient
            case "completed": self = .completed
            case "failed": self = .failed
            case "cancelled": self = .cancelled
            case let other?: self = .unknown(other)
            }
        }

        /// Whether the call has finished, one way or another.
        public var isFinished: Bool {
            switch self {
            case .completed, .failed, .cancelled: true
            default: false
            }
        }
    }

    public enum Executor: Equatable, Sendable {
        case server
        case client
        case unknown(String)

        init(_ raw: String?) {
            switch raw {
            case "server", nil: self = .server
            case "client": self = .client
            case let other?: self = .unknown(other)
            }
        }
    }

    /// The model provider's tool-call ID. A device's result is matched against it.
    public var id: String
    public var name: String
    /// What the call is doing, in words for people, such as "Checking your location".
    public var displayTitle: String?
    public var status: Status
    public var executor: Executor
    /// The person whose device must run a client tool.
    public var targetUserID: String?
    /// The install that must run a client tool, from the custom data of the person's
    /// triggering message.
    public var targetClientID: String?
    /// The call's arguments as JSON, present for client tools, which need them to run.
    /// Every channel member can see them.
    public var arguments: Data?
    /// A short, shareable outcome, such as "Found your location".
    public var summary: String?
    public var durationMS: Int?

    public var duration: TimeInterval? { durationMS.map { TimeInterval($0) / 1000 } }

    public init(
        id: String,
        name: String,
        displayTitle: String? = nil,
        status: Status,
        executor: Executor = .server,
        targetUserID: String? = nil,
        targetClientID: String? = nil,
        arguments: Data? = nil,
        summary: String? = nil,
        durationMS: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.displayTitle = displayTitle
        self.status = status
        self.executor = executor
        self.targetUserID = targetUserID
        self.targetClientID = targetClientID
        self.arguments = arguments
        self.summary = summary
        self.durationMS = durationMS
    }

    init(id: String, _ fields: Fields) {
        self.init(
            id: id,
            name: fields.string("name") ?? "",
            displayTitle: fields.string("display_title"),
            status: Status(fields.string("status")),
            executor: Executor(fields.string("executor")),
            targetUserID: fields.string("target_user_id"),
            targetClientID: fields.string("target_client_id"),
            arguments: fields.json("arguments"),
            summary: fields.string("summary"),
            durationMS: fields.int("duration_ms")
        )
    }

    /// Whether this call is waiting for this device: a client tool, still awaiting its
    /// result, targeted at this person and this install.
    public func isAwaiting(userID: String, clientID: String) -> Bool {
        executor == .client && status == .awaitingClient && targetUserID == userID && targetClientID == clientID
    }

    /// Decodes the arguments into a type of your own.
    public func decodeArguments<T: Decodable>(as type: T.Type = T.self) throws -> T {
        try JSONDecoder().decode(T.self, from: arguments ?? Data("{}".utf8))
    }
}

/// An AI step from a newer SDK or an unknown step type.
public struct AIUnsupportedPart: Identifiable, Equatable, Sendable {
    public var id: String
    public var type: String
    public var version: Int
}

/// Lenient reads from a JSON object: a field of the wrong type reads as missing.
struct Fields {
    let object: [String: Any]

    init(_ object: [String: Any]) { self.object = object }

    func string(_ key: String) -> String? {
        guard let value = object[key] as? String, !value.isEmpty else { return nil }
        return value
    }

    func int(_ key: String) -> Int? {
        guard let number = object[key] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number.intValue
    }

    func json(_ key: String) -> Data? {
        guard let value = object[key], !(value is NSNull), JSONSerialization.isValidJSONObject(value) else { return nil }
        return try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }
}
