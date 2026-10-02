//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import XCTest
@testable import StreamChatAI

/// A model that writes the given pieces, then finishes or fails.
private struct ScriptedModel: AIFallbackModel {
    var name = "Scripted"
    var requiresNetwork = false
    var availability = AIFallbackModelAvailability.available
    var pieces: [String] = ["Hel", "Hello", "Hello there"]
    var failure: Error?
    var pause: Duration = .zero
    var requests: Requests? = nil

    final class Requests: @unchecked Sendable {
        var all: [AIFallbackRequest] = []
    }

    func reply(to request: AIFallbackRequest) -> AsyncThrowingStream<String, Error> {
        requests?.all.append(request)
        let pieces = pieces, failure = failure, pause = pause
        return AsyncThrowingStream { continuation in
            let task = Task {
                for piece in pieces {
                    if pause > .zero { try? await Task.sleep(for: pause) }
                    if Task.isCancelled { break }
                    continuation.yield(piece)
                }
                continuation.finish(throwing: failure)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private struct BackendError: Error {
    let status: Int
}

@MainActor
final class AIModelFallbackTests: XCTestCase {

    func testThePolicyReadsURLErrorsAndStatuses() {
        let policy = AIFallbackPolicy()

        XCTAssertEqual(policy.reason(for: URLError(.notConnectedToInternet)), .offline)
        XCTAssertEqual(policy.reason(for: URLError(.networkConnectionLost)), .offline)
        XCTAssertEqual(policy.reason(for: URLError(.cannotConnectToHost)), .unavailable)
        XCTAssertEqual(policy.reason(for: URLError(.timedOut)), .unavailable)
        XCTAssertNil(policy.reason(for: URLError(.cancelled)))
        XCTAssertNil(policy.reason(for: URLError(.badServerResponse)))
        XCTAssertNil(policy.reason(for: BackendError(status: 429)), "only the app knows its own errors")

        XCTAssertEqual(AIFallbackPolicy.reason(forHTTPStatus: 429), .limitReached)
        XCTAssertEqual(AIFallbackPolicy.reason(forHTTPStatus: 503), .unavailable)
        XCTAssertNil(AIFallbackPolicy.reason(forHTTPStatus: 400))
        XCTAssertNil(AIFallbackPolicy.reason(forHTTPStatus: 500))
    }

    func testTheAppsReadingComesFirstAndTheReasonsGateIt() {
        var policy = AIFallbackPolicy { error in
            (error as? BackendError).flatMap { AIFallbackPolicy.reason(forHTTPStatus: $0.status) }
        }

        XCTAssertEqual(policy.reason(for: BackendError(status: 429)), .limitReached)
        XCTAssertEqual(policy.reason(for: URLError(.notConnectedToInternet)), .offline, "the built-in reading still applies")
        XCTAssertNil(policy.reason(for: BackendError(status: 404)))

        policy.reasons = [.offline]
        XCTAssertNil(policy.reason(for: BackendError(status: 429)), "a reason left out shows the error instead")
        XCTAssertEqual(policy.reason(for: URLError(.notConnectedToInternet)), .offline)
    }

    func testReasonsDescribeThemselves() {
        XCTAssertEqual(AIFallbackReason.offline.localizedDescription, "You're offline")
        XCTAssertEqual(AIFallbackReason.limitReached.localizedDescription, "Usage limit reached")
        XCTAssertNil(AIFallbackReason.chosen.localizedDescription)
        XCTAssertNil(AIFallbackReason(rawValue: "maintenance").localizedDescription, "a reason of the app's own has no description")
    }

    func testTheFirstAvailableModelAnswersAndOnlineModelsWaitForANetwork() throws {
        let off = ScriptedModel(name: "Off", availability: .unavailable(.notEnabled))
        let cloud = ScriptedModel(name: "Cloud", requiresNetwork: true)
        let local = ScriptedModel(name: "Local")
        let fallback = AIModelFallback(models: [off, cloud, local], instructions: "Be brief.")

        XCTAssertEqual(fallback.model(for: .limitReached)?.name, "Cloud")
        XCTAssertEqual(fallback.model(for: .offline)?.name, "Local")

        fallback.models = [off]
        XCTAssertNil(fallback.model(for: .unavailable))
        XCTAssertNil(fallback.reply(to: [.user("Hi")], reason: .unavailable), "no reply when no model can answer")
    }

    func testAReplyStreamsTheAnswerAndCompletes() async throws {
        let requests = ScriptedModel.Requests()
        let fallback = AIModelFallback(
            models: [ScriptedModel(requests: requests)],
            instructions: "Be brief.",
            maximumResponseTokens: 200
        )
        let reply = try XCTUnwrap(fallback.reply(id: "m1", to: [.user("Hi"), .assistant("Hello"), .user("How are you?")], reason: .offline))

        XCTAssertEqual(reply.id, "m1")
        XCTAssertEqual(reply.reason, .offline)
        XCTAssertEqual(reply.modelName, "Scripted")
        XCTAssertTrue(reply.isOnDevice)
        XCTAssertTrue(reply.isGenerating)

        let state = await reply.finished()

        XCTAssertEqual(state, .completed)
        XCTAssertEqual(reply.state, .completed)
        XCTAssertEqual(reply.text, "Hello there")
        let request = try XCTUnwrap(requests.all.first)
        XCTAssertEqual(request.instructions, "Be brief.")
        XCTAssertEqual(request.turns.last, .user("How are you?"))
        XCTAssertEqual(request.maximumResponseTokens, 200)
    }

    func testAFailedReplyKeepsWhatItWroteAndWhy() async {
        let model = ScriptedModel(pieces: ["Partly"], failure: AIFallbackModelError(code: .refused))
        let reply = AIFallbackReply(reason: .limitReached, model: model, request: AIFallbackRequest(instructions: "", turns: [.user("Hi")]))

        let state = await reply.finished()

        XCTAssertEqual(state, .failed(AIFallbackModelError(code: .refused)))
        XCTAssertEqual(reply.text, "Partly")
        XCTAssertEqual(AIFallbackModelError(code: .refused).localizedDescription, "This model can't help with that.")
    }

    func testAnUnexpectedErrorReadsAsFailed() async {
        let model = ScriptedModel(pieces: [], failure: BackendError(status: 500))
        let reply = AIFallbackReply(reason: .offline, model: model, request: AIFallbackRequest(instructions: "", turns: [.user("Hi")]))

        guard case let .failed(error) = await reply.finished() else { return XCTFail("expected a failure") }
        XCTAssertEqual(error.code, .failed)
    }

    func testCancellingStopsTheModel() async throws {
        let model = ScriptedModel(pieces: ["One", "One two", "One two three"], pause: .milliseconds(200))
        let reply = AIFallbackReply(reason: .offline, model: model, request: AIFallbackRequest(instructions: "", turns: [.user("Count")]))

        try await Task.sleep(for: .milliseconds(300))
        reply.cancel()
        let state = await reply.finished()

        XCTAssertEqual(state, .cancelled)
        XCTAssertNotEqual(reply.text, "One two three")
    }

    func testTheNewestTurnsFitTheBudget() {
        let long = String(repeating: "word ", count: 300) // about 500 estimated tokens
        let turns: [AIConversationTurn] = [
            .user("First question \(long)"),
            .assistant("First answer \(long)"),
            .user("Second question"),
            .assistant("Second answer"),
            .user("Third question"),
        ]

        XCTAssertEqual(AIConversationTurn.fitting(turns, tokens: 4000), turns, "everything fits")
        XCTAssertEqual(
            AIConversationTurn.fitting(turns, tokens: 600).map(\.text),
            ["Second question", "Second answer", "Third question"],
            "the oldest turns go first, and the history still starts with the person"
        )
        XCTAssertEqual(AIConversationTurn.fitting(turns, tokens: 1), [.user("Third question")], "the question always stays")
        XCTAssertEqual(AIConversationTurn.fitting([], tokens: 100), [])
    }

    func testRepeatedTurnsOfOneRoleMergeAndEmptyOnesGo() {
        let turns: [AIConversationTurn] = [.user("Are you there?"), .user("  "), .user("Hello?"), .assistant(""), .user("Anyone?")]

        XCTAssertEqual(AIConversationTurn.fitting(turns, tokens: 1000), [.user("Are you there?\n\nHello?\n\nAnyone?")])
    }

    func testTheOnDeviceModelSaysWhetherItCanAnswer() async {
        let model = AIOnDeviceModel()

        XCTAssertFalse(model.requiresNetwork)
        XCTAssertEqual(model.name, "On-device model")
        if !model.availability.isAvailable {
            // Without Apple Intelligence the reply fails at once instead of hanging.
            let reply = AIFallbackReply(reason: .offline, model: model, request: AIFallbackRequest(instructions: "", turns: [.user("Hi")]))
            let state = await reply.finished()
            XCTAssertEqual(state, .failed(AIFallbackModelError(code: .unavailable)))
        }
    }
}
