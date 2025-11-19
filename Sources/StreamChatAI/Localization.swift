import Foundation

enum L10n {
    enum Composer {
        static var placeholderAskAnything: String {
            localized("composer.placeholder.ask_anything", comment: "Placeholder shown in the message composer text field.")
        }
        
        static var buttonAllPhotos: String {
            localized("composer.button.all_photos", comment: "Label for the button that shows the full photo library.")
        }
    }
    
    enum StreamingMessage {
        static var codeBlockLanguageFallback: String {
            localized("streaming.code_block.language_fallback", comment: "Fallback name for code blocks when no language is provided.")
        }
    }
    
    enum Transcription {
        static var recognizerUnavailable: String {
            localized("transcription.error.recognizer_unavailable", comment: "Error shown when the speech recognizer cannot be used.")
        }
    }
    
    private static func localized(_ key: String, comment: StaticString) -> String {
        String(
            localized: String.LocalizationValue(key),
            bundle: localizationBundle,
            comment: comment
        )
    }
    
    private static let localizationBundle: Bundle = {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: BundleToken.self)
        #endif
    }()
    
    private final class BundleToken {}
}
