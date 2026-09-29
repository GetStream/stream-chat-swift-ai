//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI
import XCTest
@testable import StreamChatAI

@MainActor
final class ComposerViewFactoryTests: XCTestCase {

    func testTheInputDictatesByDefault() {
        let input = DefaultViewFactory.shared.makeComposerInputView(options: inputOptions())

        XCTAssertTrue(input is ComposerInputView<SpeechToTextButton>)
    }

    func testAFactoryReplacesTheViewInsideTheInput() {
        let input = NoDictationFactory().makeComposerInputView(options: inputOptions())

        XCTAssertTrue(input is ComposerInputView<EmptyView>)
    }

    private func inputOptions() -> ComposerInputViewOptions {
        ComposerInputViewOptions(
            viewModel: ComposerViewModel(),
            speechHandler: SpeechHandler(),
            colors: Colors(),
            isGenerating: false,
            onMessageSend: { _ in },
            onStopGenerating: nil
        )
    }
}

private final class NoDictationFactory: ComposerViewFactory {
    func makeComposerInputTrailingView(options: ComposerInputTrailingViewOptions) -> some View {
        EmptyView()
    }
}
