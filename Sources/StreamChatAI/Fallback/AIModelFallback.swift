//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Combine
import Foundation

/// Answers with a fallback model when your agent can't: the person is offline, the agent
/// reached its usage limit, or your backend isn't responding.
///
/// List the models to try, in order, and say in the instructions what the model answers as
/// and what it can't do. When a request to your agent fails, ask the policy whether to fall
/// back, then start a reply and show it as it streams:
///
/// ```swift
/// let fallback = AIModelFallback(
///     models: [AIOnDeviceModel()],
///     instructions: "You are Ava, answering on the person's phone because the assistant can't be reached. You have no tools or files."
/// )
///
/// do {
///     try await backend.send(text)
/// } catch {
///     if let reason = fallback.policy.reason(for: error),
///        let reply = fallback.reply(to: history + [.user(text)], reason: reason) {
///         replies.append(reply) // AIFallbackReplyView(reply: reply)
///     }
/// }
/// ```
///
/// A fallback answer is yours to keep or drop: it isn't sent to the channel, and your agent
/// never sees it unless you send it.
@MainActor
public final class AIModelFallback {
    /// The models to try, in order. The first that is available, and online when it needs a
    /// network, answers.
    public var models: [any AIFallbackModel]
    /// When a failed request falls back.
    public var policy: AIFallbackPolicy
    /// What every model is told before the conversation.
    public var instructions: String
    /// The longest answer, in tokens. `nil` leaves it to the model.
    public var maximumResponseTokens: Int?
    /// Tells the models that need a network whether there is one. `AINetworkMonitor.shared`
    /// by default.
    public var networkMonitor: AINetworkMonitor

    public init(
        models: [any AIFallbackModel] = [AIOnDeviceModel()],
        policy: AIFallbackPolicy = AIFallbackPolicy(),
        instructions: String,
        maximumResponseTokens: Int? = nil,
        networkMonitor: AINetworkMonitor? = nil
    ) {
        self.models = models
        self.policy = policy
        self.instructions = instructions
        self.maximumResponseTokens = maximumResponseTokens
        self.networkMonitor = networkMonitor ?? .shared
    }

    /// The model that would answer for `reason` now, if any.
    public func model(for reason: AIFallbackReason) -> (any AIFallbackModel)? {
        let online = reason != .offline && networkMonitor.isOnline
        return models.first { $0.availability.isAvailable && (online || !$0.requiresNetwork) }
    }

    /// Starts answering the last of `turns`, the person's question, with the first model
    /// available for `reason`. Returns `nil` when none is.
    ///
    /// - Parameters:
    ///   - id: The reply's identity, such as the ID of the message it answers.
    ///   - turns: The conversation so far, oldest first, ending with the person's question.
    public func reply(
        id: String = UUID().uuidString,
        to turns: [AIConversationTurn],
        reason: AIFallbackReason
    ) -> AIFallbackReply? {
        guard let model = model(for: reason) else { return nil }
        let request = AIFallbackRequest(instructions: instructions, turns: turns, maximumResponseTokens: maximumResponseTokens)
        return AIFallbackReply(id: id, reason: reason, model: model, request: request)
    }
}

/// One answer from a fallback model, as it streams. It starts when it is made.
@MainActor
public final class AIFallbackReply: ObservableObject, Identifiable {
    public enum State: Equatable, Sendable {
        case generating
        case completed
        /// The model stopped with an error. `text` keeps what it wrote before.
        case failed(AIFallbackModelError)
        case cancelled
    }

    public let id: String
    /// Why the answer comes from a fallback model.
    public let reason: AIFallbackReason
    /// The name of the model answering.
    public let modelName: String
    /// Whether the model answering runs on this device.
    public let isOnDevice: Bool
    /// The answer so far.
    @Published public private(set) var text = ""
    @Published public private(set) var state = State.generating

    private var task: Task<State, Never>?

    public var isGenerating: Bool { state == .generating }

    public init(id: String = UUID().uuidString, reason: AIFallbackReason, model: any AIFallbackModel, request: AIFallbackRequest) {
        self.id = id
        self.reason = reason
        modelName = model.name
        isOnDevice = !model.requiresNetwork
        let stream = model.reply(to: request)
        task = Task { [weak self] in
            do {
                for try await text in stream {
                    self?.text = text
                }
                // A cancelled stream ends without an error.
                try Task.checkCancellation()
                return self?.end(.completed) ?? .cancelled
            } catch is CancellationError {
                return self?.end(.cancelled) ?? .cancelled
            } catch {
                let failure = error as? AIFallbackModelError ?? AIFallbackModelError(code: .failed, debugDescription: String(describing: error))
                return self?.end(.failed(failure)) ?? .cancelled
            }
        }
    }

    /// Stops the model. What it wrote so far stays.
    public func cancel() {
        task?.cancel()
    }

    /// Waits until the answer is complete, failed or cancelled.
    @discardableResult
    public func finished() async -> State {
        await task?.value ?? state
    }

    private func end(_ state: State) -> State {
        if self.state == .generating {
            self.state = state
        }
        return self.state
    }

    deinit {
        task?.cancel()
    }
}
