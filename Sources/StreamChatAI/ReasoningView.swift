//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI
internal import MarkdownUI

/// Shows the model's reasoning while it works, before the answer starts streaming.
public struct ReasoningView: View {

    var text: String
    private let colors: Colors

    @State private var animate = false

    public init(
        text: String,
        colors: Colors = Colors()
    ) {
        self.text = text
        self.colors = colors
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text(L10n.Reasoning.title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(colors.reasoning.title)
            .opacity(animate ? 1 : 0.4)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: animate
            )

            Markdown(text)
                .markdownTextStyle {
                    ForegroundColor(colors.reasoning.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(colors.reasoning.accent)
                        .frame(width: 2)
                }
        }
        .onAppear {
            animate = true
        }
    }
}
