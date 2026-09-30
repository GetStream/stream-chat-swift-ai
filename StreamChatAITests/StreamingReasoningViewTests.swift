//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI
import XCTest
@testable import StreamChatAI

final class StreamingReasoningViewTests: XCTestCase {

    func testParagraphsSplitAtBlankLines() {
        let paragraphs = ReasoningParagraph.split("First thought.\nStill first.\n\n\n\nSecond thought.\n\n")

        XCTAssertEqual(paragraphs.map(\.text), ["First thought.\nStill first.", "Second thought."])
        XCTAssertEqual(paragraphs.map(\.id), [0, 1])
    }

    func testAGrowingParagraphKeepsItsIdentity() {
        let before = ReasoningParagraph.split("Settled.\n\nGrow")
        let after = ReasoningParagraph.split("Settled.\n\nGrowing now")

        XCTAssertEqual(before.first, after.first)
        XCTAssertEqual(before.last?.id, after.last?.id)
    }

    func testThePreviewStartsAtAWordAndFoldsWhitespace() {
        let text = String(repeating: "alpha ", count: 100) + "the latest\n\nthought"
        let tail = ReasoningPreview.tail(of: text, limit: 40)

        XCTAssertTrue(tail.hasSuffix("the latest thought"))
        XCTAssertTrue(tail.hasPrefix("alpha"), "the preview began mid-word: \(tail)")
        XCTAssertLessThanOrEqual(tail.count, 40)
        XCTAssertEqual(ReasoningPreview.tail(of: "short\nthought"), "short thought")
    }

    func testInlineMarkdownAndHeadingsReadAsText() {
        let text = ReasoningParagraph.attributed("### Plan\nCheck the **order** first")

        XCTAssertEqual(String(text.characters), "Plan\nCheck the order first")
        let bold = text.runs.filter { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
            .map { String(text[$0.range].characters) }
        XCTAssertEqual(bold, ["Plan", "order"])
    }

    func testUnclosedMarkdownIsShownAsWritten() {
        XCTAssertEqual(String(ReasoningParagraph.attributed("a **half").characters), "a **half")
    }

    func testTheTitleFollowsTheThinking() {
        let locale = Locale(identifier: "en_US")

        XCTAssertEqual(StreamingReasoningView.title(isThinking: true, duration: 4, locale: locale), "Thinking…")
        XCTAssertEqual(StreamingReasoningView.title(isThinking: false, duration: 12.4, locale: locale), "Thought for 12s")
        XCTAssertEqual(StreamingReasoningView.title(isThinking: false, duration: 65, locale: locale), "Thought for 1m 5s")
        XCTAssertEqual(StreamingReasoningView.title(isThinking: false, duration: 0.2, locale: locale), "Thought for 1s")
        XCTAssertEqual(StreamingReasoningView.title(isThinking: false, duration: nil, locale: locale), "Thought process")
    }
}
