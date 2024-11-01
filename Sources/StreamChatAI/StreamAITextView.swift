//
//  StreamAITextView.swift
//  StreamChatAI
//
//  Created by Martin Mitrevski on 23.10.24.
//

import Combine
import StreamChat
import SwiftUI
internal import MarkdownUI
internal import Splash

public struct StreamAITextView: View {
    
    var content: String
    
    public init(content: String) {
        self.content = content
    }
    
    public var body: some View {
        Markdown(content)
          .markdownBlockStyle(\.codeBlock) {
            codeBlock($0)
          }
          .markdownCodeSyntaxHighlighter(.splash(theme: self.theme))
    }

    @ViewBuilder
    private func codeBlock(_ configuration: CodeBlockConfiguration) -> some View {
      VStack(spacing: 0) {
        HStack {
          Text(configuration.language ?? "plain text")
            .font(.system(.caption, design: .monospaced))
            .fontWeight(.semibold)
            .foregroundColor(Color(theme.plainTextColor))
          Spacer()

          Image(systemName: "clipboard")
            .onTapGesture {
              copyToClipboard(configuration.content)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background {
          Color(theme.backgroundColor)
        }

        Divider()

        ScrollView(.horizontal) {
          configuration.label
            .relativeLineSpacing(.em(0.25))
            .markdownTextStyle {
              FontFamilyVariant(.monospaced)
              FontSize(.em(0.85))
            }
            .padding()
        }
      }
      .background(Color(.secondarySystemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .markdownMargin(top: .zero, bottom: .em(0.8))
    }

    private var theme: Splash.Theme {
        .sunset(withFont: .init(size: 16))
    }

    private func copyToClipboard(_ string: String) {
        UIPasteboard.general.string = string
    }
}

public struct StreamAITextViewOther: View {
    
    @State var content: String
    
    @StateObject private var textAnimator = TextAnimator()
    
    public init(content: String) {
        self.content = content
    }
    
    public var body: some View {
        if #available(iOS 17.0, *) {
            Markdown(textAnimator.displayedText)
                .markdownBlockStyle(\.codeBlock) {
                    codeBlock($0)
                }
                .markdownCodeSyntaxHighlighter(.splash(theme: self.theme))
                .onChange(of: content) { oldValue, newValue in
                    textAnimator.addText(newValue)
                }
        } else {
            Markdown(content)
                .markdownBlockStyle(\.codeBlock) {
                    codeBlock($0)
                }
                .markdownCodeSyntaxHighlighter(.splash(theme: self.theme))
        }
    }

    @ViewBuilder
    private func codeBlock(_ configuration: CodeBlockConfiguration) -> some View {
      VStack(spacing: 0) {
        HStack {
          Text(configuration.language ?? "plain text")
            .font(.system(.caption, design: .monospaced))
            .fontWeight(.semibold)
            .foregroundColor(Color(theme.plainTextColor))
          Spacer()

          Image(systemName: "clipboard")
            .onTapGesture {
              copyToClipboard(configuration.content)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background {
          Color(theme.backgroundColor)
        }

        Divider()

        ScrollView(.horizontal) {
          configuration.label
            .relativeLineSpacing(.em(0.25))
            .markdownTextStyle {
              FontFamilyVariant(.monospaced)
              FontSize(.em(0.85))
            }
            .padding()
        }
      }
      .background(Color(.secondarySystemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .markdownMargin(top: .zero, bottom: .em(0.8))
    }

    private var theme: Splash.Theme {
        .sunset(withFont: .init(size: 16))
    }

    private func copyToClipboard(_ string: String) {
        UIPasteboard.general.string = string
    }
}

class TextAnimator: ObservableObject {
    @Published var displayedText: String = ""
    
    private var fullText: String = ""
    private var currentIndex: Int = 0
    private var cancellable: AnyCancellable?
    
    func addText(_ newText: String) {
        fullText += newText
        
        // Start the animation if it's not already running
        if cancellable == nil {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        cancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateText()
            }
    }
    
    private func updateText() {
        guard currentIndex < fullText.count else {
            // Animation finished
            cancellable?.cancel()
            cancellable = nil
            return
        }
        
        let index = fullText.index(fullText.startIndex, offsetBy: currentIndex + 1)
        displayedText = String(fullText[..<index])
        currentIndex += 1
    }
    
    deinit {
        cancellable?.cancel()
    }
}
