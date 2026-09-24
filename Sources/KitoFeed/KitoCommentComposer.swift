//
//  KitoCommentComposer.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// The bar for writing a comment: an emoji quick-bar, "Replying to …", @mention autocomplete
/// that filters people as you type, and a send button that appears once there's something to send.
///
/// ```swift
/// KitoCommentComposer(text: $draft, author: me, people: followers,
///                     replyingTo: replyTarget?.author, onCancelReply: { replyTarget = nil }) { text in
///     post(text)
/// }
/// ```
public struct KitoCommentComposer: View {
    /// Emoji shown in the quick-bar by default.
    public static let defaultEmoji = ["❤️", "🙌", "🔥", "👏", "😢", "😍", "😮", "😂"]

    @Binding private var text: String
    private let author: KitoFeedPerson?
    private let people: [KitoFeedPerson]
    private let replyingTo: KitoFeedPerson?
    private let placeholder: String
    private let emoji: [String]
    private let tint: Color?
    private let focus: Binding<Bool>?
    private let onCancelReply: (() -> Void)?
    private let onSend: (String) -> Void

    @FocusState private var focused: Bool
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - author: The current user, shown beside the field.
    ///   - people: Who can be @mentioned.
    ///   - replyingTo: Shows "Replying to …" with a cancel button.
    ///   - emoji: The quick-bar. Empty hides it.
    ///   - isFocused: Mirrors (and can set) keyboard focus, e.g. to focus when Reply is tapped.
    ///   - onSend: Called with the trimmed text; clear `text` yourself or let `KitoCommentsView` do it.
    public init(text: Binding<String>, author: KitoFeedPerson? = nil, people: [KitoFeedPerson] = [],
                replyingTo: KitoFeedPerson? = nil, placeholder: String = "Add a comment…",
                emoji: [String] = KitoCommentComposer.defaultEmoji, tint: Color? = nil,
                isFocused: Binding<Bool>? = nil, onCancelReply: (() -> Void)? = nil,
                onSend: @escaping (String) -> Void) {
        self._text = text
        self.author = author
        self.people = people
        self.replyingTo = replyingTo
        self.placeholder = placeholder
        self.emoji = emoji
        self.tint = tint
        self.focus = isFocused
        self.onCancelReply = onCancelReply
        self.onSend = onSend
    }

    private var accent: Color { tint ?? theme.colors.onSurface }
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !trimmed.isEmpty }
    private var mentionQuery: String? { people.isEmpty ? nil : KitoMentionSearch.activeQuery(in: text) }
    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.8) }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
            if let replyingTo { replyBanner(replyingTo) }
            if !emoji.isEmpty { emojiBar }
            field
        }
        .background(.bar)
        .overlay(alignment: .top) { suggestions }
        .animation(spring, value: replyingTo?.id)
        .animation(spring, value: mentionQuery)
        .onChange(of: focus?.wrappedValue ?? false) { _, wants in if wants != focused { focused = wants } }
        .onChange(of: focused) { _, now in if focus?.wrappedValue != now { focus?.wrappedValue = now } }
    }

    private func replyBanner(_ person: KitoFeedPerson) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrowshape.turn.up.left.fill").font(.system(size: 11, weight: .semibold))
            HStack(spacing: 0) {
                Text("Replying to ")
                Text(person.name).fontWeight(.semibold)
            }
            Spacer()
            Button {
                onCancelReply?()
            } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel reply")
        }
        .font(theme.typography.caption)
        .foregroundStyle(theme.colors.onSurface.opacity(0.7))
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, 8)
        .background(theme.colors.surfaceMuted.opacity(0.7))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var emojiBar: some View {
        HStack(spacing: 0) {
            ForEach(emoji, id: \.self) { symbol in
                Button { insert(symbol) } label: {
                    Text(symbol)
                        .font(.system(size: 24))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(KitoEmojiPressStyle())
                .accessibilityLabel("Add \(symbol)")
            }
        }
        .padding(.horizontal, theme.spacing.sm)
        .padding(.top, 4)
    }

    private var field: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if let author { KitoFeedAvatar(person: author, size: 34).padding(.bottom, 3) }
            HStack(alignment: .bottom, spacing: 6) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .font(theme.typography.label.weight(.regular))
                    .focused($focused)
                    .tint(accent)
                    .padding(.vertical, 10)
                if canSend {
                    sendButton.transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 5)
            .background(Capsule().fill(theme.colors.surfaceMuted))
            .overlay(Capsule().strokeBorder(focused ? accent.opacity(0.35) : theme.colors.border.opacity(0.6), lineWidth: 1))
            .animation(spring, value: canSend)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, 8)
    }

    private var sendButton: some View {
        Button(action: send) {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.colors.surface)
                .frame(width: 32, height: 32)
                .background(Circle().fill(accent))
        }
        .buttonStyle(KitoFeedPressStyle())
        .padding(.bottom, 4)
        .accessibilityLabel("Send")
    }

    @ViewBuilder private var suggestions: some View {
        if let query = mentionQuery {
            KitoMentionSuggestionList(people: KitoMentionSearch.filter(people, query: query, limit: 4), query: query,
                                      tint: tint) { person in
                text = KitoMentionSearch.complete(text, with: person)
            }
            .padding(.horizontal, theme.spacing.lg)
            .alignmentGuide(.top) { $0[.bottom] + 8 }
            .transition(.scale(scale: 0.96, anchor: .bottom).combined(with: .opacity))
        }
    }

    private func insert(_ symbol: String) {
        text += symbol
    }

    private func send() {
        guard canSend else { return }
        onSend(trimmed)
    }
}

private struct KitoEmojiPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.35 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
