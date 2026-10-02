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
    
    enum Reasoning {
        static var thinking: String {
            localized("reasoning.title.thinking", comment: "Header of a model's reasoning while the model is still thinking.")
        }
        
        static func thinkingFor(_ duration: String) -> String {
            String(
                format: localized("reasoning.title.thinking_for", comment: "Header of a model's reasoning while it thinks. The argument is how long so far, such as 7s."),
                duration
            )
        }
        
        static var thought: String {
            localized("reasoning.title.thought", comment: "Header of a model's finished reasoning when its duration is unknown.")
        }
        
        static func thoughtFor(_ duration: String) -> String {
            String(
                format: localized("reasoning.title.thought_for", comment: "Header of a model's finished reasoning. The argument is a duration such as 12s."),
                duration
            )
        }
        
        static var showHint: String {
            localized("reasoning.accessibility.show", comment: "Accessibility hint of the reasoning header while the reasoning is hidden.")
        }
        
        static var hideHint: String {
            localized("reasoning.accessibility.hide", comment: "Accessibility hint of the reasoning header while the reasoning is shown.")
        }
    }
    
    enum ToolCall {
        static var awaitingClient: String {
            localized("tool_call.status.awaiting_client", comment: "A tool call waiting for a person's device to run it.")
        }
        
        static var awaitingApproval: String {
            localized("tool_call.status.awaiting_approval", comment: "A tool call waiting for a person to allow or decline it.")
        }
        
        static var declined: String {
            localized("tool_call.status.declined", comment: "A tool call the person declined, so it never ran.")
        }
        
        static var failed: String {
            localized("tool_call.status.failed", comment: "A tool call that failed, when the agent gave no reason.")
        }
        
        static var cancelled: String {
            localized("tool_call.status.cancelled", comment: "A tool call that was cancelled.")
        }
        
        static var unsupported: String {
            localized("ai_part.unsupported", comment: "Placeholder for an AI step this version of the app can't show.")
        }
    }
    
    enum ToolApproval {
        static var allow: String {
            localized("tool_approval.button.allow", comment: "Button that allows a tool call the AI agent asked to make.")
        }
        
        static var decline: String {
            localized("tool_approval.button.decline", comment: "Button that declines a tool call the AI agent asked to make, so it never runs.")
        }
        
        static var notSent: String {
            localized("tool_approval.error.not_sent", comment: "Shown under a tool call's question when the person's answer could not be sent.")
        }
    }
    
    enum Fallback {
        static var onDeviceModel: String {
            localized("fallback.model.on_device", comment: "Name of Apple's on-device language model, which answers when the AI agent can't.")
        }
        
        static var answeredOnDevice: String {
            localized("fallback.title.on_device", comment: "Label of an answer written by a model on this device, because the AI agent couldn't answer.")
        }
        
        static func answeredBy(_ model: String) -> String {
            String(
                format: localized("fallback.title.answered_by", comment: "Label of an answer written by another model, because the AI agent couldn't answer. The argument is the model's name."),
                model
            )
        }
        
        static var answering: String {
            localized("fallback.status.answering", comment: "Shown while a fallback model starts writing its answer.")
        }
        
        static var reasonOffline: String {
            localized("fallback.reason.offline", comment: "Why a fallback model answered: the device has no network connection.")
        }
        
        static var reasonLimitReached: String {
            localized("fallback.reason.limit_reached", comment: "Why a fallback model answered: the AI agent's usage limit was reached.")
        }
        
        static var reasonUnavailable: String {
            localized("fallback.reason.unavailable", comment: "Why a fallback model answered: the AI agent isn't responding.")
        }
        
        static var errorUnavailable: String {
            localized("fallback.error.unavailable", comment: "A fallback model couldn't answer because it isn't available on this device now.")
        }
        
        static var errorContextTooLong: String {
            localized("fallback.error.context_too_long", comment: "A fallback model couldn't answer because the question is too long for it.")
        }
        
        static var errorRefused: String {
            localized("fallback.error.refused", comment: "A fallback model declined to answer, or its safety checks stopped the answer.")
        }
        
        static var errorUnsupportedLanguage: String {
            localized("fallback.error.unsupported_language", comment: "A fallback model couldn't answer because it doesn't support the conversation's language.")
        }
        
        static var errorBusy: String {
            localized("fallback.error.busy", comment: "A fallback model couldn't answer because it is busy.")
        }
        
        static var errorFailed: String {
            localized("fallback.error.failed", comment: "A fallback model couldn't answer, for any other reason.")
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
