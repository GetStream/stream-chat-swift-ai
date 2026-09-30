//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import XCTest
@testable import StreamChatAI

final class AIMessagePartTests: XCTestCase {

    private func payload(_ json: String) -> Data { Data(json.utf8) }

    func testStepsDecodeInOrderAndOtherAttachmentsAreSkipped() {
        let parts = AIMessagePart.parts(from: [
            ("ai_reasoning", payload(#"{"type":"ai_reasoning","v":1,"id":"r1","status":"completed","summary":"Needs the user's location first","duration_ms":3200}"#)),
            ("athena_image", payload(#"{"artifact_id":"a1"}"#)),
            ("ai_tool_call", payload(#"{"type":"ai_tool_call","v":1,"id":"toolu_01A","name":"get_location","display_title":"Checking your location","status":"awaiting_client","executor":"client","target_user_id":"u_123","target_client_id":"ios-7F3A","arguments":{"accuracy":"city"}}"#)),
            ("ai_reasoning", payload(#"{"id":"r2","status":"streaming","preview":"Now that I know the city…"}"#)),
        ])

        XCTAssertEqual(parts.map(\.id), ["r1", "toolu_01A", "r2"])
        guard case let .reasoning(first) = parts[0], case let .toolCall(call) = parts[1], case let .reasoning(live) = parts[2] else {
            return XCTFail("unexpected parts \(parts)")
        }
        XCTAssertEqual(first.status, .completed)
        XCTAssertEqual(first.summary, "Needs the user's location first")
        XCTAssertEqual(first.duration, 3.2)
        XCTAssertEqual(call.status, .awaitingClient)
        XCTAssertEqual(call.executor, .client)
        XCTAssertEqual(call.displayTitle, "Checking your location")
        XCTAssertTrue(call.isAwaiting(userID: "u_123", clientID: "ios-7F3A"))
        XCTAssertFalse(call.isAwaiting(userID: "u_123", clientID: "ios-OTHER"))
        XCTAssertFalse(call.isAwaiting(userID: "u_456", clientID: "ios-7F3A"))
        struct Arguments: Decodable { let accuracy: String }
        XCTAssertEqual(try call.decodeArguments(as: Arguments.self).accuracy, "city")
        XCTAssertTrue(live.isStreaming)
        XCTAssertEqual(live.preview, "Now that I know the city…")
    }

    func testDecodingIsLenient() {
        let parts = AIMessagePart.parts(from: [
            ("ai_tool_call", payload(#"{"id":"c1","name":"search","status":"paused_for_review","duration_ms":"fast"}"#)),
            ("ai_reasoning", payload("not json")),
            ("ai_tool_call", payload(#"{"id":"c2","v":2,"name":"future"}"#)),
            ("ai_citation", payload(#"{"id":"s1"}"#)),
        ])

        guard case let .toolCall(call) = parts[0] else { return XCTFail("\(parts)") }
        XCTAssertEqual(call.status, .unknown("paused_for_review"))
        XCTAssertEqual(call.executor, .server)
        XCTAssertNil(call.durationMS, "a field of the wrong type reads as missing")
        guard case let .reasoning(broken) = parts[1] else { return XCTFail("\(parts)") }
        XCTAssertEqual(broken.id, "ai_reasoning-1", "a step without an ID is known by its position")
        XCTAssertEqual(broken.status, .completed)
        XCTAssertEqual(parts[2], .unsupported(AIUnsupportedPart(id: "c2", type: "ai_tool_call", version: 2)))
        XCTAssertEqual(parts[3], .unsupported(AIUnsupportedPart(id: "s1", type: "ai_citation", version: 1)))
    }

    func testAReasoningStepShowsItsLiveTextOrItsPreview() {
        let step = AIReasoningPart(id: "r1", status: .completed, summary: "Weighing it", preview: "Weighing it up", durationMS: 12400)

        XCTAssertEqual(StreamingReasoningView(part: step).text, "Weighing it up")
        XCTAssertEqual(StreamingReasoningView(part: step, text: "Weighing it up, then more").text, "Weighing it up, then more")
        XCTAssertEqual(StreamingReasoningView(part: step).summary, "Weighing it")
        XCTAssertFalse(StreamingReasoningView(part: step).isThinking)
    }
}

@MainActor
final class AIClientToolRunnerTests: XCTestCase {

    final class CountingTool: AIClientTool {
        let name = "athena_device_location"
        var runs = 0
        func run(_ call: AIToolCallPart) async -> AIClientToolResult {
            runs += 1
            return .completed(["city": "Skopje"], summary: "Shared approximate location")
        }
    }

    private func awaiting(_ id: String = "toolu_01A", user: String = "u_1", client: String = "ios-1", name: String = "athena_device_location") -> [AIMessagePart] {
        [.toolCall(AIToolCallPart(id: id, name: name, status: .awaitingClient, executor: .client, targetUserID: user, targetClientID: client))]
    }

    private func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    func testACallRunsOnceAndOnlyOnTheDeviceItIsAddressedTo() async {
        let tool = CountingTool()
        let runner = AIClientToolRunner(userID: "u_1", clientID: "ios-1", tools: [tool])
        var sent: [AIClientToolResult] = []
        let send: @MainActor (AIToolCallPart, AIClientToolResult) async throws -> Void = { _, result in sent.append(result) }

        runner.run(awaiting(), send: send)
        runner.run(awaiting(), send: send)
        await settle()
        runner.run(awaiting(), send: send)
        runner.run(awaiting("toolu_02", client: "ios-2"), send: send)
        runner.run(awaiting("toolu_03", user: "u_2"), send: send)
        runner.run(awaiting("toolu_04", name: "unknown_tool"), send: send)
        await settle()

        XCTAssertEqual(tool.runs, 1)
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?.summary, "Shared approximate location")
    }

    func testAResultThatCouldNotBeSentIsSentAgainWithoutRunningTheToolAgain() async {
        struct Offline: Error {}
        let tool = CountingTool()
        let runner = AIClientToolRunner(userID: "u_1", clientID: "ios-1", tools: [tool])
        var attempts = 0
        let send: @MainActor (AIToolCallPart, AIClientToolResult) async throws -> Void = { _, _ in
            attempts += 1
            if attempts == 1 { throw Offline() }
        }

        runner.run(awaiting(), send: send)
        await settle()
        runner.run(awaiting(), send: send)
        await settle()
        runner.run(awaiting(), send: send)
        await settle()

        XCTAssertEqual(tool.runs, 1)
        XCTAssertEqual(attempts, 2)
    }
}
