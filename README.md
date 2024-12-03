# [Swift UI](https://getstream.io/tutorials/ios-chat/) AI components for Stream Chat

This official repository for Stream Chat's UI components is designed specifically for AI-first applications written in Swift UI. When paired with our real-time [Chat API](https://getstream.io/chat/), it makes integrating with and rendering responses from LLM providers such as ChatGPT, Gemini, Anthropic or any custom backend easier by providing rich with out-of-the-box components able to render Markdown, Code blocks, tables, thinking indicators, images, etc.

To start, this library includes the following components which assist with this task:
- `StreamingMessageView` - a component that is able to render text, markdown and code in real-time, using character-by-character animation, similar to ChatGPT.
- `AITypingIndicatorView` - a component that can display different states of the LLM (thinking, checking external sources, etc).

Our team plans to keep iterating and adding more components over time. If there's a component you use every day in your apps and would like to see added, please open an issue and we will try to add it 😎.

## Installation

The AI components are available via the Swift Package Manager (SPM). Use the following steps to add the SDK via SPM in Xcode:
- Select "Add Packages…" in File menu
- Paste the URL https://github.com/GetStream/stream-chat-swift-ai.git
- In the option "Dependency Rule" choose "Up to next major version", and in the text inputs next to it, enter "0.1.0" and "1.0.0" accordingly.

You can also add the components in your package file as a dependency:

```swift
.package(url: "https://github.com/GetStream/stream-chat-swift-ai.git", from: "0.1.0")
```

The components depend on John Sundell's [Splash](https://github.com/JohnSundell/Splash), as well as Guille Gonzalez's [Swift Markdown UI](https://github.com/gonzalezreal/swift-markdown-ui).

## Usage

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

These components are designed to work seamlessly with our existing Swift UI [Chat SDK](https://getstream.io/tutorials/ios-chat/). Our [developer guide](https://getstream.io/chat/solutions/ai-integration/) explains how to get started building AI integrations with Stream and Swift UI. 

<br />

<a href="https://getstream.io?utm_source=Github&utm_medium=Github_Repo_Content&utm_content=Developer&utm_campaign=Github_Swift_AI_SDK&utm_term=DevRelOss">
<img src="https://user-images.githubusercontent.com/24237865/138428440-b92e5fb7-89f8-41aa-96b1-71a5486c5849.png" align="right" width="12%"/>
</a>

## 🛥 What is Stream?

Stream allows developers to rapidly deploy scalable feeds, chat messaging and video with an industry leading 99.999% uptime SLA guarantee.

Stream provides UI components and state handling that make it easy to build real-time chat and video calling for your app. Stream runs and maintains a global network of edge servers around the world, ensuring optimal latency and reliability regardless of where your users are located.

## 📕 Tutorials

To learn more about integrating AI and chatbots into your application, we recommend checking out the full list of tutorials across all of our supported frontend SDKs and providers. Stream's Chat SDK is natively supported across:
* React
* React Native
* Angular
* Jetpack Compose
* Swift UI
* Flutter
* Javascript/Bring your own


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
