![Integrating Stream Chat with AI](/assets/repo_cover.png)

# [Swift UI](https://getstream.io/tutorials/ios-chat/) AI components for Stream Chat

This official repository for Stream Chat's UI components is designed specifically for AI-first applications written in Swift UI. When paired with our real-time [Chat API](https://getstream.io/chat/), it makes integrating with and rendering responses from LLM providers such as ChatGPT, Gemini, Anthropic or any custom backend easier by providing rich with out-of-the-box components able to render Markdown, Code blocks, tables, thinking indicators, images, etc.

To start, this library includes the following components which assist with this task:
- `StreamingMessageView` - a component that is able to render text, markdown and code in real-time, using character-by-character animation, similar to ChatGPT.
- `ComposerView` - a fully featured prompt composer with attachments, suggestion chips and speech input.
- `SpeechToTextButton` - a reusable button that records voice input and streams the recognized transcript back into your UI.
- `AITypingIndicatorView` - a component that can display different states of the LLM (thinking, checking external sources, etc).
- `StreamingReasoningView` - a component that streams a model's reasoning into view while it thinks, then folds it into "Thought for 12s", staying responsive with long, fast-growing reasoning.
- `AIMessagePartsView` - the steps an agent took while replying (reasoning rounds and tool calls, stored as `ai_reasoning` and `ai_tool_call` attachments), in order.
- `AIClientToolRunner` - runs the tool calls an agent addresses to this device and sends back their results.
- `AIToolApprovalView` - asks the person a tool call waits for whether it may run, such as sharing their location, from the question on its `ai_tool_call` step.

Our team plans to keep iterating and adding more components over time. If there's a component you use every day in your apps and would like to see added, please open an issue and we will try to add it 😎.

## 🛠️ Installation

The AI components are available via the Swift Package Manager (SPM). Use the following steps to add the SDK via SPM in Xcode:
- Select "Add Packages…" in File menu
- Paste the URL https://github.com/GetStream/stream-chat-swift-ai.git
- In the option "Dependency Rule" choose "Up to next major version", and in the text inputs next to it, enter "0.4.0" and "1.0.0" accordingly.

You can also add the components in your package file as a dependency:

```swift
.package(url: "https://github.com/GetStream/stream-chat-swift-ai.git", from: "0.4.0")
```

The components depend on John Sundell's [Splash](https://github.com/JohnSundell/Splash), as well as Guille Gonzalez's [Swift Markdown UI](https://github.com/gonzalezreal/swift-markdown-ui).

## ⚙️ Usage

### Streaming Message View

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

### AI Typing Indicator View

The `AITypingIndicatorView` is used to present different states of the LLM, such as "Thinking", "Checking External Sources", etc. You can specify any text you need. There's also a nice animation when the indicator is shown.

```swift
AITypingIndicatorView(text: "Thinking")
```

### Streaming Reasoning View

The `StreamingReasoningView` shows a model's reasoning (its "thinking") alongside its reply. While the model thinks, the reasoning is open under a "Thinking… 7s" header: a panel that grows with the thoughts, then keeps the newest in view (unless the reader scrolls up), revealing new text smoothly as it arrives. Once the model is done, the view folds into "Thought for 12s" and the step's summary, unless the reader opened or closed it themselves, and tapping the header opens the whole reasoning again.

```swift
StreamingReasoningView(
    text: reasoning,
    isThinking: answer.isEmpty,
    duration: thinkingDuration
)
```

Reasoning can run to tens of kilobytes and grow many times a second, so the view only lays out what changes: it renders one paragraph at a time, lazily, so only the paragraph still being written is laid out again. Blank lines separate paragraphs, and inline Markdown (bold, italics, code, links) is rendered.

You can also pass a `footnote` shown under the finished reasoning, `initiallyExpanded` (open once done), `showsLiveReasoning` (open while thinking, on by default), `maxExpandedHeight` (260 by default), the `font`, and `colors`, whose `reasoning` palette sets the header, text, footnote, shimmer and rule colors.

### Message Parts

An agent can describe each step it takes while replying as a custom attachment on its message: a round of reasoning (`ai_reasoning`) or a tool call (`ai_tool_call`). The order of the attachments is the timeline, and the final answer stays in the message text. `AIMessagePart` decodes them from a message's attachments, and `AIMessagePartsView` shows them in order:

```swift
let parts = AIMessagePart.parts(from: message.allAttachments.map { ($0.type.rawValue, $0.payload) })

AIMessagePartsView(parts: parts)
StreamingMessageView(content: message.text, isGenerating: isGenerating)
```

The kinds of step are an open set rather than an enum, so a new kind never breaks your code: `part.kind` is a string-backed value (`.reasoning`, `.toolCall`, or any other `ai_` type), the kinds this SDK reads have typed views (`part.reasoning`, `part.toolCall`), and anything else keeps its payload for `part.decode(_:)`. Statuses and executors are open in the same way, so switch over them with a `default`. Decoding is lenient: missing fields get defaults, a field of the wrong type reads as missing, and a step in a newer format version keeps its payload but has no typed view. Each step has a stable `id` (a tool call uses the provider's tool-call ID), so the list diffs cleanly while it streams.

A reasoning step carries a capped `preview` and a `summary`. To show some steps your own way, such as reasoning your backend streams in full, or a kind of your own, render each part yourself and fall back to `AIMessagePartView`:

```swift
AIMessagePartsView(parts: parts) { part in
    if let reasoning = part.reasoning {
        StreamingReasoningView(part: reasoning, text: fullReasoning[reasoning.id])
    } else if part.kind == "ai_citation", let citation = try? part.decode(Citation.self) {
        CitationView(citation: citation)
    } else {
        AIMessagePartView(part: part)
    }
}
```

`AIToolCallView` shows a single tool call. Both views take `colors`, whose `toolCalls` palette sets the title, detail, accent, success and failure colors.

### Client Tools

A tool call with `executor: client` and `status: awaiting_client` asks a person's device to run a tool. It names the person (`target_user_id`) and the install (`target_client_id`) that should run it, which your backend copies from the custom data (`client_id`) of that person's message. Conform your tools to `AIClientTool` and let an `AIClientToolRunner` run them:

```swift
final class LocationTool: AIClientTool {
    let name = "get_location"
    func run(_ call: AIToolCallPart) async -> AIClientToolResult {
        // Ask the person first, then:
        .completed(["city": "Amsterdam"], summary: "Shared approximate location")
    }
}

let runner = AIClientToolRunner(userID: currentUserID, clientID: AIClientIdentity.installID, tools: [LocationTool()])

// Whenever a reply's parts change:
runner.run(parts) { call, result in
    try await backend.send(result, for: call)
}
```

The runner runs a call only when it awaits this person and this install, and only once. A result that could not be sent is sent again on a later update, without running the tool again. Your backend should still accept a result only from the targeted person and install, only while the call is waiting, and only once. Arguments and summaries are visible to every channel member, so keep private data out of them: a summary like "Shared approximate location" rather than the coordinates.

### Tool Approvals

Some tool calls should wait for a person: the agent wants their location, or to send an email on their behalf. The agent's backend marks such a call on its `ai_tool_call` step with status `awaiting_approval`, addresses it to that person (`target_user_id`, and `target_client_id` for a client tool), and adds the question:

```json
{ "type": "ai_tool_call", "id": "toolu_01A", "name": "get_location", "status": "awaiting_approval",
  "executor": "client", "target_user_id": "u_123", "target_client_id": "ios-7F3A",
  "approval": { "title": "Share your location?", "message": "Only your city is shared.",
                "reason": "to check the local weather", "allow_title": "Share location", "decline_title": "Don't share" } }
```

`part.toolCall?.approval` reads it, and `AIToolApprovalView` asks it under the call. It shows only to that person, on the install the call names (any of their devices for a server tool), and only while the call waits. Give it an `AIToolApprover`, which says who is signed in on this device and sends their answer to your backend:

```swift
let approver = AIToolApprover(userID: currentUserID, clientID: AIClientIdentity.installID) { call, allowed in
    try await backend.answer(call, allowed: allowed)
}

AIToolCallView(part: call)
AIToolApprovalView(call: call, approver: approver)
```

`AIMessagePartsView(parts: parts, approver: approver)` does this for every tool call. While the answer is on its way the buttons are disabled; if `decide` throws, the person can answer again.

The backend holds the call until it gets the answer, and accepts one only from the targeted person (and install), only while the call waits, and only once. It then updates the step: allowed, the call goes on (`approval.decision` is `allowed`, and a client tool's call moves to `awaiting_client`, so `AIClientToolRunner` runs it); declined, the call is `cancelled` with `approval.decision` `declined` and never runs. `part.isDeclined` tells the two cancellations apart, and `AIToolCallView` shows "Waiting for approval" and "Declined". The question is visible to every channel member, so keep private data out of it.

To ask in your own design, pass the content: it gets the question, where the answer is, and a closure that answers.

```swift
AIToolApprovalView(call: call, approver: approver) { approval, state, decide in
    MyApprovalCard(title: approval.title, busy: state.isSending, onAllow: { decide(true) }, onDecline: { decide(false) })
}
```

`AIToolApprovalCard` is the default design, and `colors.toolApprovals` sets its title, message, background, border, button and failure colors.

### Composer View

The `ComposerView` gives users a modern text-entry surface with attachment previews, suggestion chips, and an integrated send button. Inject a `ComposerViewModel` to handle state and pass a closure that receives every `MessageData` payload when the user taps send.

```swift
@available(iOS 16, *)
ComposerView(
    viewModel: ComposerViewModel(),
    colors: colors
) { message in
    print(message.text, message.attachments)
}
```

The view also exposes chat option chips via `chatOptions` on the view model and automatically resets attachments once a message is sent.

### Speech to Text Button

`SpeechToTextButton` turns voice input into text using Apple's Speech framework. When tapped it asks for microphone access, records audio, and forwards the recognized transcript through its closure.

```swift
SpeechToTextButton(
    locale: Locale(identifier: "en-US"),
    colors: colors
) { transcript in
    print("User said:", transcript)
}
```

Display it alongside `ComposerView` to let users dictate prompts when their hands are busy.

These components are designed to work seamlessly with our existing Swift UI [Chat SDK](https://getstream.io/tutorials/ios-chat/). Our [developer guide](https://getstream.io/chat/solutions/ai-integration/) explains how to get started building AI integrations with Stream and Swift UI. 

### Customizing the Composer with View Factory

`ComposerView` accepts a `viewFactory` parameter of any type that conforms to `ComposerViewFactory`. The protocol exposes five independent slots you can override individually — everything else falls back to the built-in default:

| Slot | Factory method | Default |
|------|----------------|---------|
| Left of the text field | `makeLeadingComposerView(options:)` | `AddAttachmentsButton` |
| The text field area | `makeComposerInputView(options:)` | `ComposerInputView` |
| Inside the text field, while it is empty | `makeComposerInputTrailingView(options:)` | `SpeechToTextButton` |
| Right of the text field | `makeTrailingComposerView(options:)` | `EmptyView` |
| Attachment picker sheet | `makeComposerPickerView(options:)` | Built-in photo/camera picker |

#### Replacing a single slot

Create a class that conforms to `ComposerViewFactory` and override only the method you need. Unoverridden methods keep their defaults automatically.

```swift
class MyComposerFactory: ComposerViewFactory {
    // Replace the leading button with a paperclip icon.
    func makeLeadingComposerView(options: LeadingComposerViewOptions) -> some View {
        Button {
            options.onTap()
        } label: {
            Image(systemName: "paperclip")
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}
```

Then pass the factory to `ComposerView`:

```swift
ComposerView(viewFactory: MyComposerFactory()) { message in
    send(message)
}
```

#### Replacing the input area

Override `makeComposerInputView(options:)` to take full control of the text field, send button, and everything in between. The `ComposerInputViewOptions` struct gives you access to the view model, the color palette, the generating state, and the send/stop callbacks:

```swift
class MyComposerFactory: ComposerViewFactory {
    func makeComposerInputView(options: ComposerInputViewOptions) -> some View {
        MyCustomInputView(
            viewModel: options.viewModel,
            isGenerating: options.isGenerating,
            onSend: options.onMessageSend,
            onStop: options.onStopGenerating
        )
    }
}
```

#### Replacing the dictation button

While the text field is empty, `ComposerInputView` shows a `SpeechToTextButton` inside it; once there is text, the send button takes its place. Override `makeComposerInputTrailingView(options:)` to show something else there, or return `EmptyView` to leave dictation out:

```swift
class MyComposerFactory: ComposerViewFactory {
    func makeComposerInputTrailingView(options: ComposerInputTrailingViewOptions) -> some View {
        EmptyView()
    }
}
```

#### Adding a trailing action button

The trailing slot is empty by default. Override `makeTrailingComposerView(options:)` to add a mode toggle, a slash-command trigger, or any other control:

```swift
class MyComposerFactory: ComposerViewFactory {
    func makeTrailingComposerView(options: TrailingComposerViewOptions) -> some View {
        Button {
            toggleMode()
        } label: {
            Image(systemName: "wand.and.sparkles")
        }
    }
}
```

#### Programmatic focus

`ComposerInputView` observes `ComposerViewModel.isTextFieldFocused`. Set it to `true` to show the keyboard and `false` to dismiss it from anywhere that holds a reference to the view model:

```swift
@StateObject private var composerViewModel = ComposerViewModel()

// Focus the keyboard when the screen appears.
composerViewModel.isTextFieldFocused = true
```

### Customizing Colors

The `Colors` class centralizes the palette that the AI components use. Create a single instance and inject it into the views you render to keep them in sync:

```swift
let colors = Colors(
    composer: .init(
        attachmentButtonIcon: .pink,
        selectedOptionForeground: .purple
    ),
    suggestions: .init(background: .mint.opacity(0.3)),
    transcription: .init(icon: .orange)
)

ComposerView(colors: colors) { message in
    // Handle message
}

SuggestionsView(
    suggestions: ["What are the docs for the AI SDK?"],
    colors: colors,
    onMessageSend: handleSuggestion
)

SpeechToTextButton(colors: colors) { transcript in
    print(transcript)
}
```

<br />

<a href="https://getstream.io?utm_source=Github&utm_medium=Github_Repo_Content&utm_content=Developer&utm_campaign=Github_Swift_AI_SDK&utm_term=DevRelOss">
<img src="https://user-images.githubusercontent.com/24237865/138428440-b92e5fb7-89f8-41aa-96b1-71a5486c5849.png" align="right" width="12%"/>
</a>

## 🛥 What is Stream?

Stream allows developers to rapidly deploy scalable feeds, chat messaging and video with an industry leading 99.999% uptime SLA guarantee.

Stream provides UI components and state handling that make it easy to build real-time chat and video calling for your app. Stream runs and maintains a global network of edge servers around the world, ensuring optimal latency and reliability regardless of where your users are located.

## 📕 Tutorials

To learn more about integrating AI and chatbots into your application, we recommend checking out the full list of tutorials across all of our supported frontend SDKs and providers. Stream's Chat SDK is natively supported across:
* [React](https://getstream.io/chat/react-chat/tutorial/)
* [React Native](https://getstream.io/chat/react-native-chat/tutorial/)
* [Angular](https://getstream.io/chat/angular/tutorial/)
* [Jetpack Compose](https://getstream.io/tutorials/android-chat/)
* [SwiftUI](https://getstream.io/tutorials/ios-chat/)
* [Flutter](https://getstream.io/chat/flutter/tutorial/)
* [Javascript/Bring your own](https://getstream.io/chat/docs/javascript/)


## 👩‍💻 Free for Makers 👨‍💻

Stream is free for most side and hobby projects. To qualify, your project/company needs to have < 5 team members and < $10k in monthly revenue. Makers get $100 in monthly credit for video for free.
For more details, check out the [Maker Account](https://getstream.io/maker-account?utm_source=Github&utm_medium=Github_Repo_Content&utm_content=Developer&utm_campaign=Github_Swift_AI_SDK&utm_term=DevRelOss).

## 💼 We are hiring!

We've recently closed a [\$38 million Series B funding round](https://techcrunch.com/2021/03/04/stream-raises-38m-as-its-chat-and-activity-feed-apis-power-communications-for-1b-users/) and we keep actively growing.
Our APIs are used by more than a billion end-users, and you'll have a chance to make a huge impact on the product within a team of the strongest engineers all over the world.
Check out our current openings and apply via [Stream's website](https://getstream.io/team/#jobs).


## License

```
Copyright (c) 2014-2024 Stream.io Inc. All rights reserved.

Licensed under the Stream License;
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   https://github.com/GetStream/stream-chat-swift-ai/blob/main/LICENSE

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
