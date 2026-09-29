//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI
import UIKit

/// Defines the palette that StreamChatAI views rely on.
public class Colors {
    /// Appearance configuration for `ComposerView`.
    public var composer: Composer
    /// Appearance configuration for `SuggestionsView`.
    public var suggestions: Suggestions
    /// Appearance configuration for `TranscribeSpeechButton`.
    public var transcription: Transcription
    /// Appearance configuration for `ReasoningView`.
    public var reasoning: Reasoning
    
    /// Creates a new palette with optional overrides for each supported view.
    public init(
        composer: Composer = .init(),
        suggestions: Suggestions = .init(),
        transcription: Transcription = .init(),
        reasoning: Reasoning = .init()
    ) {
        self.composer = composer
        self.suggestions = suggestions
        self.transcription = transcription
        self.reasoning = reasoning
    }
}

public extension Colors {
    
    /// Palette for all composer-specific elements.
    struct Composer {
        /// Background color of the plus button.
        public var attachmentButtonBackground: Color
        /// Color of the plus icon.
        public var attachmentButtonIcon: Color
        /// Background color of the main composer container.
        public var containerBackground: Color
        /// Foreground color used for text/icons inside the composer.
        public var containerForeground: Color
        /// Background of the selected chat option chip.
        public var selectedOptionBackground: Color
        /// Foreground of the selected chat option chip.
        public var selectedOptionForeground: Color
        
        /// Creates the composer palette with optional overrides.
        public init(
            attachmentButtonBackground: Color = Color(UIColor.secondarySystemBackground),
            attachmentButtonIcon: Color = .gray,
            containerBackground: Color = Color(UIColor.secondarySystemBackground),
            containerForeground: Color = .primary,
            selectedOptionBackground: Color = Color(UIColor.systemBackground),
            selectedOptionForeground: Color = .blue
        ) {
            self.attachmentButtonBackground = attachmentButtonBackground
            self.attachmentButtonIcon = attachmentButtonIcon
            self.containerBackground = containerBackground
            self.containerForeground = containerForeground
            self.selectedOptionBackground = selectedOptionBackground
            self.selectedOptionForeground = selectedOptionForeground
        }
    }
    
    /// Palette for suggestion chips.
    struct Suggestions {
        /// Text color of the suggestion.
        public var text: Color
        /// Background color for each suggestion card.
        public var background: Color
        
        /// Creates the suggestions palette with optional overrides.
        public init(
            text: Color = .primary,
            background: Color = Color(UIColor.secondarySystemBackground)
        ) {
            self.text = text
            self.background = background
        }
    }
    
    /// Palette for the transcription button state.
    struct Transcription {
        /// Color of the microphone / stop icon.
        public var icon: Color
        
        /// Creates the transcription palette with optional overrides.
        public init(icon: Color = .gray) {
            self.icon = icon
        }
    }
    
    /// Palette for the reasoning shown while a response is being prepared.
    struct Reasoning {
        /// Color of the "Thinking" title and its icon.
        public var title: Color
        /// Color of the reasoning text.
        public var text: Color
        /// Color of the leading bar next to the reasoning text.
        public var accent: Color
        
        /// Creates the reasoning palette with optional overrides.
        public init(
            title: Color = .secondary,
            text: Color = .secondary,
            accent: Color = Color(UIColor.separator)
        ) {
            self.title = title
            self.text = text
            self.accent = accent
        }
    }
}
