//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI

/// Says that an answer came from a fallback model, and why: "Answered on this device ·
/// You're offline".
public struct AIFallbackLabel: View {
    var title: String
    var detail: String?
    var systemImage: String
    var font: Font
    var colors: Colors.Fallback

    /// - Parameters:
    ///   - reason: Why the answer comes from a fallback model, shown after the title.
    ///   - isOnDevice: Whether the model ran on this device, for the default title.
    ///   - modelName: The model's name, for the default title of one that isn't on this device.
    ///   - title: Replaces the default title, such as "Answered on this iPhone".
    ///   - detail: Replaces the reason's description, such as "Out of allowance".
    public init(
        reason: AIFallbackReason,
        isOnDevice: Bool = true,
        modelName: String? = nil,
        title: String? = nil,
        detail: String? = nil,
        font: Font = .footnote,
        colors: Colors = Colors()
    ) {
        self.title = title ?? (isOnDevice || modelName == nil ? L10n.Fallback.answeredOnDevice : L10n.Fallback.answeredBy(modelName ?? ""))
        self.detail = detail ?? reason.localizedDescription
        systemImage = isOnDevice ? "iphone" : "sparkles"
        self.font = font
        self.colors = colors.fallback
    }

    /// Labels `reply`.
    public init(reply: AIFallbackReply, title: String? = nil, detail: String? = nil, font: Font = .footnote, colors: Colors = Colors()) {
        self.init(
            reason: reply.reason,
            isOnDevice: reply.isOnDevice,
            modelName: reply.modelName,
            title: title,
            detail: detail,
            font: font,
            colors: colors
        )
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(colors.icon)
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(colors.title)
            if let detail {
                Text("·")
                    .foregroundStyle(colors.detail)
                    .accessibilityHidden(true)
                Text(detail)
                    .foregroundStyle(colors.detail)
            }
        }
        .font(font)
        .accessibilityElement(children: .combine)
    }
}

/// A fallback model's answer as it streams: its label, the answer, and why the model stopped
/// when it couldn't finish.
///
/// ```swift
/// AIFallbackReplyView(reply: reply)
/// ```
public struct AIFallbackReplyView: View {
    @ObservedObject var reply: AIFallbackReply
    var colors: Colors

    public init(reply: AIFallbackReply, colors: Colors = Colors()) {
        self.reply = reply
        self.colors = colors
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AIFallbackLabel(reply: reply, colors: colors)
            if reply.text.isEmpty && reply.isGenerating {
                AITypingIndicatorView(text: L10n.Fallback.answering)
            } else if !reply.text.isEmpty {
                StreamingMessageView(content: reply.text, isGenerating: reply.isGenerating)
            }
            if case let .failed(error) = reply.state {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(colors.fallback.failure)
            }
        }
    }
}
