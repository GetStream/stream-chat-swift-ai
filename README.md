## StreamChat AI UI Components

StreamChat provides UI components for easier integration of AI and LLMs into our SDK.

This repo contains two components that will help you with that:
- `StreamingMessageView` - a component that is able to render text, markdown and code in realtime, using character-by-character animation, similar to ChatGPT.
- `AITypingIndicatorView` - a component that can display different states of the LLM (thinking, checking external sources, etc).

More AI components are planned for the future.

### Installation

The AI components are available via the Swift Package Manager (SPM). Use the following steps to add the SDK via SPM in Xcode:
- Select "Add Packages…" in File menu
- Paste the URL https://github.com/GetStream/stream-chat-swift-ai.git
- In the option "Dependency Rule" choose "Up to next major version", and in the text inputs next to it, enter "0.1.0" and "1.0.0" accordingly.

You can also add the components in your package file as a dependency:

```swift
.package(url: "https://github.com/GetStream/stream-chat-swift-ai.git", from: "0.1.0")
```

The components depend on John Sundell's [Splash](https://github.com/JohnSundell/Splash), as well as Guille Gonzalez's [Swift Markdown UI](https://github.com/gonzalezreal/swift-markdown-ui).

### Usage

#### Streaming Message View

The `StreamingMessageView` is a component that can render markdown content efficiently. It has code syntax highlighting, supporting all the major languages. It can render most of the standard markdown content, such as tables, images, etc. 

Under the hood, it implements letter by letter animation, with a character queue, similar to ChatGPT.

Here's an example how to use it.

```swift
StreamingMessageView(
    content: content,
    isGenerating: true
)
```

Additionally, you can specify the speed of the animation, with the `letterInterval` parameter. The default value is 0.005 (5ms).

#### AI Typing Indicator View

The `AITypingIndicatorView` is used to present different states of the LLM, such as "Thinking", "Checking External Sources", etc. You can specify any text you need. There's also a nice animation when the indicator is shown.

```swift
AITypingIndicatorView(text: "Thinking")
```

The AI components work best with StreamChat's [SwiftUI SDK](https://getstream.io/chat/docs/sdk/ios/swiftui/getting-started/). You can find a sample implementation [here](https://github.com/GetStream/stream-chat-ai-assistant-swift).