//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI

public protocol ComposerViewFactory {
    
    associatedtype LeadingComposerViewType: View
    func makeLeadingComposerView(options: LeadingComposerViewOptions) -> LeadingComposerViewType
    
    associatedtype TrailingComposerViewType: View
    func makeTrailingComposerView(options: TrailingComposerViewOptions) -> TrailingComposerViewType
    
    associatedtype ComposerInputViewType: View
    func makeComposerInputView(options: ComposerInputViewOptions) -> ComposerInputViewType
    
    associatedtype ComposerPickerViewType: View
    func makeComposerPickerView(options: ComposerPickerViewOptions) -> ComposerPickerViewType
}

public extension ComposerViewFactory {
    func makeLeadingComposerView(options: LeadingComposerViewOptions) -> some View {
        AddAttachmentsButton(colors: options.colors) {
            options.onTap()
        }
    }
    
    func makeTrailingComposerView(options: TrailingComposerViewOptions) -> some View {
        EmptyView()
    }
    
    func makeComposerInputView(options: ComposerInputViewOptions) -> some View {
        ComposerInputView(
            viewModel: options.viewModel,
            colors: options.colors,
            isGenerating: options.isGenerating,
            isFocused: options.focusState,
            onMessageSend: options.onMessageSend,
            onStopGenerating: options.onStopGenerating
        )
    }
    
    func makeComposerPickerView(options: ComposerPickerViewOptions) -> some View {
        ComposerPickerView(viewModel: options.viewModel)
    }
}

public class DefaultViewFactory: ComposerViewFactory {
    public static let shared = DefaultViewFactory()
}

public struct LeadingComposerViewOptions {
    public let colors: Colors
    public var onTap: () -> Void
}

public struct TrailingComposerViewOptions {}

public struct ComposerInputViewOptions {
    public var viewModel: ComposerViewModel
    public let colors: Colors
    public let isGenerating: Bool
    @FocusState public var isFocused: Bool
    let onMessageSend: (MessageData) -> Void
    let onStopGenerating: (() -> Void)?

    var focusState: FocusState<Bool> { _isFocused }
}

public struct ComposerPickerViewOptions {
    public var viewModel: ComposerViewModel
}
