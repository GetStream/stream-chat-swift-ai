//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device language model (Foundation Models), on iOS 26 and later with Apple
/// Intelligence turned on. It answers without a network connection, and the conversation
/// never leaves the device.
///
/// It is a small model: good for short answers, drafting, rewording and summarising what is
/// in the conversation, not for facts it would have to look up. Its context holds a few
/// thousand tokens, so the oldest turns of a longer conversation are left out.
///
/// On earlier versions of iOS, or where Apple Intelligence is off or still downloading,
/// `availability` says why and `AIModelFallback` moves on to the next model.
public struct AIOnDeviceModel: AIFallbackModel {
    /// Tokens of the context kept free for the answer.
    public var reservedResponseTokens: Int

    public init(reservedResponseTokens: Int = 1024) {
        self.reservedResponseTokens = reservedResponseTokens
    }

    public var name: String { L10n.Fallback.onDeviceModel }

    public var requiresNetwork: Bool { false }

    public var availability: AIFallbackModelAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .unavailable(.deviceNotEligible)
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable(.notEnabled)
            case .unavailable:
                return .unavailable(.notReady)
            }
        }
        #endif
        return .unavailable(.unsupportedOS)
    }

    public func reply(to request: AIFallbackRequest) -> AsyncThrowingStream<String, Error> {
        let reserved = reservedResponseTokens
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    #if canImport(FoundationModels)
                    if #available(iOS 26.0, macOS 26.0, *) {
                        try await OnDeviceGeneration.stream(request, reservedResponseTokens: reserved) { continuation.yield($0) }
                        continuation.finish()
                        return
                    }
                    #endif
                    throw AIFallbackModelError(code: .unavailable)
                } catch {
                    continuation.finish(throwing: OnDeviceGeneration.fallbackError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

enum OnDeviceGeneration {
    /// Reads Foundation Models' errors as `AIFallbackModelError`s. Cancellation stays a
    /// `CancellationError`.
    static func fallbackError(_ error: Error) -> Error {
        if error is AIFallbackModelError || error is CancellationError { return error }
        let debug = String(describing: error)
        #if canImport(FoundationModels)
        // The iOS 27 SDK (Xcode 27, Swift 6.4) reports most failures as `LanguageModelError`.
        #if compiler(>=6.4)
        if #available(iOS 27.0, macOS 27.0, *) {
            if let error = error as? LanguageModelError {
                switch error {
                case .contextSizeExceeded: return AIFallbackModelError(code: .contextTooLong, debugDescription: debug)
                case .guardrailViolation, .refusal: return AIFallbackModelError(code: .refused, debugDescription: debug)
                case .unsupportedLanguageOrLocale: return AIFallbackModelError(code: .unsupportedLanguage, debugDescription: debug)
                case .rateLimited: return AIFallbackModelError(code: .busy, debugDescription: debug)
                default: return AIFallbackModelError(code: .failed, debugDescription: debug)
                }
            }
            if error is SystemLanguageModel.Error {
                return AIFallbackModelError(code: .unavailable, debugDescription: debug)
            }
        }
        #endif
        if #available(iOS 26.0, macOS 26.0, *), let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize: return AIFallbackModelError(code: .contextTooLong, debugDescription: debug)
            case .assetsUnavailable: return AIFallbackModelError(code: .unavailable, debugDescription: debug)
            case .guardrailViolation, .refusal: return AIFallbackModelError(code: .refused, debugDescription: debug)
            case .unsupportedLanguageOrLocale: return AIFallbackModelError(code: .unsupportedLanguage, debugDescription: debug)
            case .rateLimited, .concurrentRequests: return AIFallbackModelError(code: .busy, debugDescription: debug)
            default: return AIFallbackModelError(code: .failed, debugDescription: debug)
            }
        }
        #endif
        return AIFallbackModelError(code: .failed, debugDescription: debug)
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
extension OnDeviceGeneration {
    /// Streams the answer, each snapshot the whole answer so far. When the conversation
    /// still overflows the context before anything is written, the older half is left out
    /// and the model asked again.
    static func stream(
        _ request: AIFallbackRequest,
        reservedResponseTokens: Int,
        yield: (String) -> Void
    ) async throws {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { throw AIFallbackModelError(code: .unavailable) }
        let budget = model.contextSize - reservedResponseTokens - AIConversationTurn.estimatedTokens(request.instructions)
        var turns = AIConversationTurn.fitting(request.turns, tokens: budget)
        guard let last = turns.last, last.role == .user else {
            throw AIFallbackModelError(code: .failed, debugDescription: "The conversation doesn't end with a question.")
        }
        let options = GenerationOptions(temperature: request.temperature, maximumResponseTokens: request.maximumResponseTokens)
        while true {
            var wrote = false
            do {
                let session = LanguageModelSession(model: model, transcript: transcript(request.instructions, history: turns.dropLast()))
                for try await snapshot in session.streamResponse(to: last.text, options: options) {
                    try Task.checkCancellation()
                    wrote = true
                    yield(snapshot.content)
                }
                return
            } catch {
                let failure = fallbackError(error)
                guard !wrote, turns.count > 1, (failure as? AIFallbackModelError)?.code == .contextTooLong else { throw failure }
                turns = AIConversationTurn.fitting(Array(turns.suffix(turns.count / 2)), tokens: budget)
            }
        }
    }

    private static func transcript(_ instructions: String, history: ArraySlice<AIConversationTurn>) -> Transcript {
        var entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(segments: [.text(Transcript.TextSegment(content: instructions))], toolDefinitions: []))
        ]
        for turn in history {
            let segments: [Transcript.Segment] = [.text(Transcript.TextSegment(content: turn.text))]
            switch turn.role {
            case .user: entries.append(.prompt(Transcript.Prompt(segments: segments)))
            case .assistant: entries.append(.response(Transcript.Response(assetIDs: [], segments: segments)))
            }
        }
        return Transcript(entries: entries)
    }
}
#endif
