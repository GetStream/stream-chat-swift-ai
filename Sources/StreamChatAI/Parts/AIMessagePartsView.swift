//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI

/// The steps an AI agent took while replying, in order: rounds of reasoning, tool calls,
/// and a neutral placeholder for steps this version can't show. Show it before the reply's
/// text.
///
/// ```swift
/// AIMessagePartsView(parts: parts)
/// ```
///
/// By default a reasoning step shows its preview. An app that streams the full reasoning
/// separately supplies its own view for reasoning steps:
///
/// ```swift
/// AIMessagePartsView(parts: parts) { reasoning in
///     StreamingReasoningView(part: reasoning, text: liveText[reasoning.id])
/// }
/// ```
public struct AIMessagePartsView<Reasoning: View>: View {
    var parts: [AIMessagePart]
    var font: Font
    var colors: Colors
    var reasoning: (AIReasoningPart) -> Reasoning

    public init(
        parts: [AIMessagePart],
        font: Font = .subheadline,
        colors: Colors = Colors(),
        @ViewBuilder reasoning: @escaping (AIReasoningPart) -> Reasoning
    ) {
        self.parts = parts
        self.font = font
        self.colors = colors
        self.reasoning = reasoning
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(parts) { part in
                switch part {
                case let .reasoning(step):
                    reasoning(step)
                case let .toolCall(call):
                    AIToolCallView(part: call, font: font, colors: colors)
                case .unsupported:
                    UnsupportedPartView(font: font, colors: colors.toolCalls)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public extension AIMessagePartsView where Reasoning == StreamingReasoningView {
    /// Shows each reasoning step with its preview.
    init(parts: [AIMessagePart], font: Font = .subheadline, colors: Colors = Colors()) {
        self.init(parts: parts, font: font, colors: colors) { step in
            StreamingReasoningView(part: step, font: font, colors: colors)
        }
    }
}

public extension StreamingReasoningView {
    /// Shows a reasoning step: its live `text` when the app has it, otherwise the step's
    /// preview, with its summary beside "Thought for 12s" once it is done.
    init(
        part: AIReasoningPart,
        text: String? = nil,
        footnote: String? = nil,
        font: Font = .subheadline,
        colors: Colors = Colors()
    ) {
        self.init(
            text: text ?? part.preview ?? part.summary ?? "",
            isThinking: part.isStreaming,
            duration: part.duration,
            summary: part.summary,
            footnote: footnote,
            font: font,
            colors: colors
        )
    }
}

/// One tool call: what it is doing, where it runs, and how it went.
public struct AIToolCallView: View {
    var part: AIToolCallPart
    var font: Font
    var colors: Colors.ToolCalls

    public init(part: AIToolCallPart, font: Font = .subheadline, colors: Colors = Colors()) {
        self.part = part
        self.font = font
        self.colors = colors.toolCalls
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            icon
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(colors.title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(colors.detail)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let duration = part.duration, part.status.isFinished {
                Text(Self.format(duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(colors.detail)
            }
        }
        .font(font)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        part.displayTitle ?? part.name.replacingOccurrences(of: "_", with: " ")
    }

    private var detail: String? {
        switch part.status {
        case .awaitingClient: part.summary ?? L10n.ToolCall.awaitingClient
        case .failed: part.summary ?? L10n.ToolCall.failed
        case .cancelled: part.summary ?? L10n.ToolCall.cancelled
        default: part.summary
        }
    }

    @ViewBuilder private var icon: some View {
        switch part.status {
        case .running, .unknown:
            ProgressView().controlSize(.mini).tint(colors.accent)
        case .awaitingClient:
            Image(systemName: "iphone")
                .foregroundStyle(colors.accent)
                .modifier(Shimmer(isActive: true, highlight: colors.title))
        case .completed:
            Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(colors.success)
        case .failed:
            Image(systemName: "exclamationmark").font(.caption.weight(.bold)).foregroundStyle(colors.failure)
        case .cancelled:
            Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(colors.detail)
        }
    }

    static func format(_ duration: TimeInterval) -> String {
        duration < 1 ? String(format: "%.1fs", duration) : Duration.seconds(Int(duration.rounded()))
            .formatted(.units(allowed: [.minutes, .seconds], width: .narrow))
    }
}

/// A step from a newer SDK: say that something happened without guessing what.
struct UnsupportedPartView: View {
    var font: Font
    var colors: Colors.ToolCalls

    var body: some View {
        Label(L10n.ToolCall.unsupported, systemImage: "sparkles")
            .font(font)
            .foregroundStyle(colors.detail)
    }
}
