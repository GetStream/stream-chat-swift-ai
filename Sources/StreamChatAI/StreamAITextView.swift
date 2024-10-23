//
//  StreamAITextView.swift
//  StreamChatAI
//
//  Created by Martin Mitrevski on 23.10.24.
//

import SwiftUI
internal import MarkdownUI
internal import Splash

public struct StreamAITextView: View {
    
    let content: String
    
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
