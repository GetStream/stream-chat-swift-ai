//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI

/// A factory protocol that controls which views are rendered inside ``ComposerView``.
///
/// `ComposerViewFactory` gives you four independent extension points, each backed by
/// a default implementation so you only need to override the slots you want to change:
///
/// | Slot | Default |
/// |------|---------|
/// | Leading (left of the input field) | ``AddAttachmentsButton`` |
/// | Input (the text field area) | ``ComposerInputView`` |
/// | Trailing (right of the input field) | `EmptyView` |
/// | Picker (attachment sheet) | `ComposerPickerView` |
///
/// ## Creating a custom factory
///
/// Subclass or conform to `ComposerViewFactory`, override only the methods you need,
/// and pass your factory to ``ComposerView``:
///
/// ```swift
/// class MyFactory: ComposerViewFactory {
///     // Override just the leading button — everything else stays at its default.
///     func makeLeadingComposerView(options: LeadingComposerViewOptions) -> some View {
///         Button {
///             options.onTap()
///         } label: {
///             Image(systemName: "paperclip")
///                 .padding(10)
///                 .background(.ultraThinMaterial, in: Circle())
///         }
///     }
/// }
///
/// ComposerView(viewFactory: MyFactory()) { message in
///     send(message)
/// }
/// ```
///
/// All four `make*` methods have default implementations provided by the protocol
/// extension on `ComposerViewFactory`, so conforming types are free to override none,
/// some, or all of them.
public protocol ComposerViewFactory {

    /// The view type returned by ``makeLeadingComposerView(options:)``.
    associatedtype LeadingComposerViewType: View
    /// Returns the view rendered to the left of the input field.
    ///
    /// The default implementation renders ``AddAttachmentsButton``.
    /// - Parameter options: Colors and the tap handler that opens the attachment picker.
    func makeLeadingComposerView(options: LeadingComposerViewOptions) -> LeadingComposerViewType

    /// The view type returned by ``makeTrailingComposerView(options:)``.
    associatedtype TrailingComposerViewType: View
    /// Returns the view rendered to the right of the input field.
    ///
    /// The default implementation returns `EmptyView`. Override to add a custom action
    /// button, a mode toggle, or any other control.
    /// - Parameter options: Reserved for future configuration; currently empty.
    func makeTrailingComposerView(options: TrailingComposerViewOptions) -> TrailingComposerViewType

    /// The view type returned by ``makeComposerInputView(options:)``.
    associatedtype ComposerInputViewType: View
    /// Returns the central input view that contains the text field, send button, and
    /// optional speech-to-text control.
    ///
    /// The default implementation renders ``ComposerInputView``.
    /// Replace this to take full control of the text-entry surface, while keeping
    /// the rest of the composer chrome intact.
    /// - Parameter options: View model, colors, generating state, send and stop callbacks.
    func makeComposerInputView(options: ComposerInputViewOptions) -> ComposerInputViewType

    /// The view type returned by ``makeComposerPickerView(options:)``.
    associatedtype ComposerPickerViewType: View
    /// Returns the view presented in the attachment picker sheet.
    ///
    /// The default implementation renders the built-in `ComposerPickerView` which
    /// shows recent photos, a camera option, and the chat-option chips.
    /// - Parameter options: The shared ``ComposerViewModel``.
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
            speechHandler: options.speechHandler,
            colors: options.colors,
            isGenerating: options.isGenerating,
            onMessageSend: options.onMessageSend,
            onStopGenerating: options.onStopGenerating
        )
    }

    func makeComposerPickerView(options: ComposerPickerViewOptions) -> some View {
        ComposerPickerView(viewModel: options.viewModel)
    }
}

/// The default ``ComposerViewFactory`` used when no custom factory is provided.
///
/// All four factory methods fall through to the protocol-extension defaults,
/// producing the standard Stream AI composer appearance. Pass `DefaultViewFactory.shared`
/// explicitly or omit the `viewFactory` argument on ``ComposerView`` — both are
/// equivalent.
public class DefaultViewFactory: ComposerViewFactory {
    public static let shared = DefaultViewFactory()
}

// MARK: - Options

/// Configuration passed to ``ComposerViewFactory/makeLeadingComposerView(options:)``.
public struct LeadingComposerViewOptions {
    /// The color palette in use for the composer.
    public let colors: Colors
    /// Called when the user taps the leading button to open the attachment picker.
    public var onTap: () -> Void
}

/// Configuration passed to ``ComposerViewFactory/makeTrailingComposerView(options:)``.
///
/// Currently empty; reserved for future additions.
public struct TrailingComposerViewOptions {}

/// Configuration passed to ``ComposerViewFactory/makeComposerInputView(options:)``.
public struct ComposerInputViewOptions {
    /// The shared view model that holds text, attachments, and chat-option state.
    public var viewModel: ComposerViewModel
    /// The shared speech handler owned by ``ComposerView``. Passing it through options
    /// rather than letting ``ComposerInputView`` own it keeps the handler alive at the
    /// outermost view level, preventing identity resets when the input area is recreated.
    public var speechHandler: SpeechHandler
    /// The color palette in use for the composer.
    public let colors: Colors
    /// `true` while an AI response is being streamed; hides the send button and shows
    /// the stop-generating control.
    public let isGenerating: Bool
    /// Called with the composed ``MessageData`` when the user taps send.
    let onMessageSend: (MessageData) -> Void
    /// Called when the user taps the stop-generating button. `nil` if stopping is not
    /// supported by the host.
    let onStopGenerating: (() -> Void)?
}

/// Configuration passed to ``ComposerViewFactory/makeComposerPickerView(options:)``.
public struct ComposerPickerViewOptions {
    /// The shared view model used to read and write attachment and chat-option state.
    public var viewModel: ComposerViewModel
}
