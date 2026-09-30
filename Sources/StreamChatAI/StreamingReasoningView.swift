//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI

/// A model's reasoning (its "thinking"), shown alongside its reply.
///
/// While the model thinks, a shimmering "Thinking…" header sits above a short preview of
/// its latest thoughts, fading in at the top. When it is done the view folds into
/// "Thought for 12s", and tapping the header opens the whole reasoning in a panel that
/// scrolls once it is taller than `maxExpandedHeight` and follows new text while the model
/// is still thinking.
///
/// Reasoning can run to tens of kilobytes and grow many times a second, so the view only
/// lays out what changes: the preview renders the last few lines, and the open panel
/// splits the text into paragraphs that render lazily, so only the paragraph still being
/// written is laid out again.
///
/// ```swift
/// StreamingReasoningView(text: reasoning, isThinking: answer.isEmpty, duration: 12)
/// ```
public struct StreamingReasoningView: View {
    var text: String
    var isThinking: Bool
    var duration: TimeInterval?
    var footnote: String?
    var maxExpandedHeight: CGFloat
    var font: Font
    var colors: Colors.Reasoning

    @State private var isExpanded: Bool

    /// Creates a reasoning view.
    /// - Parameters:
    ///   - text: The reasoning so far. Blank lines separate paragraphs, and inline Markdown
    ///     (bold, italics, code and links) is rendered.
    ///   - isThinking: Whether the model is still thinking. While it is, the header shimmers
    ///     and, when the view is collapsed, it previews the latest thoughts.
    ///   - duration: How long the model thought, shown as "Thought for 12s" once it is done.
    ///   - footnote: A note under the open reasoning, such as how long it is kept.
    ///   - initiallyExpanded: Whether the whole reasoning starts open.
    ///   - maxExpandedHeight: How tall the open reasoning grows before it scrolls.
    ///   - font: The font of the reasoning. The header uses it in a medium weight.
    ///   - colors: The palette. The view uses its `reasoning` colors.
    public init(
        text: String,
        isThinking: Bool,
        duration: TimeInterval? = nil,
        footnote: String? = nil,
        initiallyExpanded: Bool = false,
        maxExpandedHeight: CGFloat = 320,
        font: Font = .subheadline,
        colors: Colors = Colors()
    ) {
        self.text = text
        self.isThinking = isThinking
        self.duration = duration
        self.footnote = footnote
        self.maxExpandedHeight = maxExpandedHeight
        self.font = font
        self.colors = colors.reasoning
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if isExpanded {
                ReasoningPanel(text: text, isThinking: isThinking, maxHeight: maxExpandedHeight, color: colors.text)
                if let footnote {
                    Text(footnote)
                        .font(.caption2)
                        .foregroundStyle(colors.footnote)
                }
            } else if isThinking && !text.isEmpty {
                ReasoningPreview(text: text, color: colors.text)
            }
        }
        .font(font)
        .padding(.leading, 12)
        .overlay(alignment: .leading) {
            Capsule().fill(colors.rule).frame(width: 2)
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .animation(.easeInOut(duration: 0.2), value: isThinking)
    }

    private var header: some View {
        let title = Self.title(isThinking: isThinking, duration: duration)
        return Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                Text(title)
                    .modifier(Shimmer(isActive: isThinking, highlight: colors.shimmer))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .font(font.weight(.medium))
            .foregroundStyle(colors.title)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(isExpanded ? L10n.Reasoning.hideHint : L10n.Reasoning.showHint)
        .accessibilityAddTraits(.isButton)
    }

    /// "Thinking…" while the model thinks, then how long it thought.
    static func title(isThinking: Bool, duration: TimeInterval?, locale: Locale = .autoupdatingCurrent) -> String {
        if isThinking { return L10n.Reasoning.thinking }
        guard let duration else { return L10n.Reasoning.thought }
        let seconds = Duration.seconds(max(1, Int(duration.rounded())))
        return L10n.Reasoning.thoughtFor(seconds.formatted(.units(allowed: [.minutes, .seconds], width: .narrow).locale(locale)))
    }
}

/// The latest thoughts in three lines that fade in at the top. Only the end of the text
/// is laid out, however long the reasoning is.
struct ReasoningPreview: View {
    let text: String
    let color: Color

    var body: some View {
        // Three hidden lines give the preview its height in whatever font it is shown in.
        Text(verbatim: "A\nA\nA")
            .hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottomLeading) {
                Text(Self.tail(of: text))
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .clipped()
            .mask(
                LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // It changes several times a second and repeats the reasoning, which the header
            // opens for assistive technologies.
            .accessibilityHidden(true)
    }

    /// The last few hundred characters, starting at a word, with whitespace folded so the
    /// thoughts read as one stream.
    static func tail(of text: String, limit: Int = 320) -> String {
        var start = text.index(text.endIndex, offsetBy: -limit, limitedBy: text.startIndex) ?? text.startIndex
        if start > text.startIndex, let space = text[start...].firstIndex(where: \.isWhitespace) {
            start = text.index(after: space)
        }
        return text[start...].split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// The whole reasoning, one paragraph at a time, scrolling once it is taller than
/// `maxHeight`.
struct ReasoningPanel: View {
    let text: String
    let isThinking: Bool
    let maxHeight: CGFloat
    let color: Color

    @State private var contentHeight: CGFloat = 0
    @State private var following = true
    private let bottom = "reasoning.bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(ReasoningParagraph.split(text)) { paragraph in
                        ReasoningParagraphView(text: paragraph.text, color: color)
                            .equatable()
                    }
                    Color.clear.frame(height: 1).id(bottom)
                }
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: ReasoningHeightKey.self, value: geometry.size.height)
                    }
                }
            }
            .frame(height: min(max(contentHeight, 1), maxHeight))
            .onPreferenceChange(ReasoningHeightKey.self) { contentHeight = $0 }
            .modifier(FollowsReader(following: $following))
            .onAppear {
                if isThinking { proxy.scrollTo(bottom, anchor: .bottom) }
            }
            // The last thoughts can land as the model stops thinking, so new text keeps a
            // reader who is following at the end either way. A finished trace opens at its start.
            .modifier(OnTextChange(text: text) {
                if following { proxy.scrollTo(bottom, anchor: .bottom) }
            })
        }
    }
}

/// One paragraph of reasoning. It is equatable so that only the paragraph still being
/// written is rendered again as the reasoning grows.
struct ReasoningParagraphView: View, Equatable {
    let text: String
    let color: Color

    var body: some View {
        Text(ReasoningParagraph.attributed(text))
            .foregroundStyle(color)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}

struct ReasoningParagraph: Identifiable, Equatable {
    let id: Int
    let text: String

    /// Splits reasoning at blank lines. Reasoning only grows at its end, so a paragraph's
    /// position is a stable identity.
    static func split(_ text: String) -> [ReasoningParagraph] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { ReasoningParagraph(id: $0.offset, text: $0.element) }
    }

    /// Inline Markdown as reasoning models write it: bold, italics, code and links. A
    /// heading reads as a bold line, since a paragraph of thinking has no document to
    /// structure.
    static func attributed(_ paragraph: String) -> AttributedString {
        let source = paragraph
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let trimmed = line.drop { $0 == " " }
                guard trimmed.hasPrefix("#") else { return String(line) }
                let heading = trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                return heading.isEmpty ? String(line) : "**\(heading)**"
            }
            .joined(separator: "\n")
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(paragraph)
    }
}

private struct ReasoningHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Stops following new text while the reader has scrolled up, and resumes once they are
/// back at the end. Only the reader's own scrolling counts: the panel growing, or the
/// list around it moving, never stops it following. Earlier systems always follow.
private struct FollowsReader: ViewModifier {
    @Binding var following: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { old, phase, context in
                guard phase == .idle, old == .interacting || old == .decelerating else { return }
                let geometry = context.geometry
                following = geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 24
            }
        } else {
            content
        }
    }
}

private struct OnTextChange: ViewModifier {
    let text: String
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: text) { action() }
        } else {
            content.onChange(of: text) { _ in action() }
        }
    }
}

/// A highlight sweeping across the content while something is in progress. It stays
/// still when Reduce Motion is on.
struct Shimmer: ViewModifier {
    let isActive: Bool
    let highlight: Color

    @State private var moving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isActive && !reduceMotion {
            content
                .overlay {
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        LinearGradient(colors: [.clear, highlight, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: width * 0.6)
                            .offset(x: moving ? width : -width * 0.6)
                            .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: moving)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
                .onAppear { moving = true }
                .onDisappear { moving = false }
        } else {
            content
        }
    }
}
