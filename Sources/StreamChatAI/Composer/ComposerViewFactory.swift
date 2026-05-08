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
        
    }
}

public struct LeadingComposerViewOptions {
    public let colors: Colors
    public var onTap: () -> Void
}

public struct TrailingComposerViewOptions {}

public struct ComposerInputViewOptions {
    
}
