//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import XCTest
@testable import StreamChatAI

final class AIMessagePartTests: XCTestCase {

    private func payload(_ json: String) -> Data { Data(json.utf8) }

    func testStepsDecodeInOrderAndOtherAttachmentsAreSkipped() throws {
        let parts = AIMessagePart.parts(from: [
            ("ai_reasoning", payload(#"{"type":"ai_reasoning","v":1,"id":"r1","status":"completed","summary":"Needs the user's location first","duration_ms":3200}"#)),
            ("athena_image", payload(#"{"artifact_id":"a1"}"#)),
            ("ai_tool_call", payload(#"{"type":"ai_tool_call","v":1,"id":"toolu_01A","name":"get_location","display_title":"Checking your location","status":"awaiting_client","executor":"client","target_user_id":"u_123","target_client_id":"ios-7F3A","arguments":{"accuracy":"city"}}"#)),
            ("ai_reasoning", payload(#"{"id":"r2","status":"streaming","preview":"Now that I know the city…"}"#)),
        ])

        XCTAssertEqual(parts.map(\.id), ["r1", "toolu_01A", "r2"])
        XCTAssertEqual(parts.map(\.kind), [.reasoning, .toolCall, .reasoning])
        let first = try XCTUnwrap(parts[0].reasoning)
        let call = try XCTUnwrap(parts[1].toolCall)
        let live = try XCTUnwrap(parts[2].reasoning)
        XCTAssertNil(parts[0].toolCall)
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

    func testNewKindsAndStatusesNeverBreakDecoding() throws {
        let parts = AIMessagePart.parts(from: [
            ("ai_tool_call", payload(#"{"id":"c1","name":"search","status":"paused_for_review","duration_ms":"fast"}"#)),
            ("ai_reasoning", payload("not json")),
            ("ai_tool_call", payload(#"{"id":"c2","v":2,"name":"future"}"#)),
            ("ai_citation", payload(#"{"id":"s1","url":"https://getstream.io","title":"Stream"}"#)),
        ])

        let call = try XCTUnwrap(parts[0].toolCall)
        XCTAssertEqual(call.status.rawValue, "paused_for_review", "an unknown status keeps its value")
        XCTAssertFalse(call.status.isFinished)
        XCTAssertEqual(call.executor, .server)
        XCTAssertNil(call.durationMS, "a field of the wrong type reads as missing")

        let broken = try XCTUnwrap(parts[1].reasoning)
        XCTAssertEqual(broken.id, "ai_reasoning-1", "a step without an ID is known by its position")
        XCTAssertEqual(broken.status, .completed)

        XCTAssertEqual(parts[2].kind, .toolCall)
        XCTAssertEqual(parts[2].version, 2)
        XCTAssertNil(parts[2].toolCall, "a newer format of a known kind has no typed view")
        XCTAssertFalse(parts[2].isSupported)

        XCTAssertEqual(parts[3].kind, "ai_citation")
        XCTAssertFalse(parts[3].isSupported)
        struct Citation: Decodable { let url: String; let title: String }
        XCTAssertEqual(try parts[3].decode(Citation.self).title, "Stream", "a kind of your own reads from its payload")
    }

    func testAReasoningStepShowsItsLiveTextOrItsPreview() {
        let step = AIReasoningPart(id: "r1", status: .completed, summary: "Weighing it", preview: "Weighing it up", durationMS: 12400)

        XCTAssertEqual(StreamingReasoningView(part: step).text, "Weighing it up")
        XCTAssertEqual(StreamingReasoningView(part: step, text: "Weighing it up, then more").text, "Weighing it up, then more")
        XCTAssertEqual(StreamingReasoningView(part: step).summary, "Weighing it")
        XCTAssertFalse(StreamingReasoningView(part: step).isThinking)
    }
}

final class AIToolApprovalTests: XCTestCase {

    private func call(_ json: String) throws -> AIToolCallPart {
        try XCTUnwrap(AIMessagePart(type: "ai_tool_call", payload: Data(json.utf8))?.toolCall)
    }

    func testACallThatAsksFirstCarriesItsQuestion() throws {
        let waiting = try call(#"{"id":"toolu_01A","name":"athena_device_location","status":"awaiting_approval","executor":"client","target_user_id":"u_1","target_client_id":"ios-1","approval":{"title":"Share your location?","message":"Only your city is shared.","reason":"to check the local weather","allow_title":"Share location","decline_title":"Don't share"}}"#)
        XCTAssertEqual(waiting.status, .awaitingApproval)
        XCTAssertEqual(waiting.approval, AIToolApproval(title: "Share your location?", message: "Only your city is shared.",
                                                        reason: "to check the local weather", allowTitle: "Share location", declineTitle: "Don't share"))
        XCTAssertTrue(waiting.isAwaitingApproval(userID: "u_1", clientID: "ios-1"))
        XCTAssertFalse(waiting.isAwaitingApproval(userID: "u_1", clientID: "ios-2"), "a client tool is answered on its install")
        XCTAssertFalse(waiting.isAwaitingApproval(userID: "u_2", clientID: "ios-1"))
        XCTAssertFalse(waiting.isAwaiting(userID: "u_1", clientID: "ios-1"), "the device doesn't run it yet")
        XCTAssertFalse(waiting.status.isFinished)
        XCTAssertEqual(AIToolApprovalCard.lines(of: try XCTUnwrap(waiting.approval)), ["To check the local weather.", "Only your city is shared."])
    }

    func testAServerToolsQuestionIsAnsweredFromAnyOfThePersonsDevices() throws {
        let waiting = try call(#"{"id":"call-1","name":"send_email","status":"awaiting_approval","target_user_id":"u_1","approval":{"title":"Send this email?"}}"#)
        XCTAssertTrue(waiting.isAwaitingApproval(userID: "u_1", clientID: "web-1"))
        XCTAssertEqual(waiting.approval?.allowTitle, "Allow")
        XCTAssertEqual(waiting.approval?.declineTitle, "Don't Allow")
        XCTAssertEqual(AIToolApprovalCard.lines(of: try XCTUnwrap(waiting.approval)), [])
    }

    func testAnsweredQuestionsSayHowAndADeclinedCallIsOver() throws {
        let allowed = try call(#"{"id":"toolu_01A","status":"awaiting_client","executor":"client","target_user_id":"u_1","target_client_id":"ios-1","approval":{"title":"Share your location?","decision":"allowed"}}"#)
        XCTAssertEqual(allowed.approval?.decision, .allowed)
        XCTAssertFalse(allowed.isDeclined)
        XCTAssertTrue(allowed.isAwaiting(userID: "u_1", clientID: "ios-1"), "allowed, the device runs it")
        XCTAssertFalse(allowed.isAwaitingApproval(userID: "u_1", clientID: "ios-1"))

        let declined = try call(#"{"id":"toolu_01B","status":"cancelled","summary":"Location not shared","approval":{"title":"Share your location?","decision":"declined"}}"#)
        XCTAssertTrue(declined.isDeclined)
        XCTAssertTrue(declined.status.isFinished)
    }

    func testAQuestionWithoutATitleAsksNothing() throws {
        let odd = try call(#"{"id":"toolu_01A","status":"awaiting_approval","target_user_id":"u_1","approval":{"message":"?"}}"#)
        XCTAssertNil(odd.approval)
        XCTAssertFalse(odd.isAwaitingApproval(userID: "u_1", clientID: "ios-1"))
        let notAnObject = try call(#"{"id":"toolu_01A","status":"awaiting_approval","approval":"yes"}"#)
        XCTAssertNil(notAnObject.approval)
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
        let json = #"{"id":"\#(id)","name":"\#(name)","status":"awaiting_client","executor":"client","target_user_id":"\#(user)","target_client_id":"\#(client)"}"#
        return [AIMessagePart(type: "ai_tool_call", payload: Data(json.utf8))!]
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
