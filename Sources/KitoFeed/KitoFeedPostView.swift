//
//  KitoFeedPostView.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A post in one of four styles, with rich text, media, an action bar and an overflow menu.
///
/// ```swift
/// KitoFeedPostView(post: $post, style: .social)
///     .kitoFeedActions(KitoFeedActions(onComment: { openComments($0) }))
/// ```
///
/// Likes, reposts, bookmarks and poll votes update the bound post straight away. "Not
/// interested", "Mute" and "Report" fold the post into a note with Undo.
public struct KitoFeedPostView: View {
    private let binding: Binding<KitoFeedPost>?
    @State private var local: KitoFeedPost
    private let style: KitoFeedPostStyle
    private let lineLimit: Int?
    private let tint: Color?

    @State private var hiddenBy: KitoFeedMenuAction?
    @State private var heartPop = 0
    @Environment(\.kitoTheme) private var theme
    @Environment(\.kitoFeedActions) private var actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A post whose likes, reposts, bookmarks and votes write back to `post`.
    public init(post: Binding<KitoFeedPost>, style: KitoFeedPostStyle = .social, lineLimit: Int? = 5, tint: Color? = nil) {
        self.binding = post
        self._local = State(initialValue: post.wrappedValue)
        self.style = style
        self.lineLimit = lineLimit
        self.tint = tint
    }

    /// A post that keeps its own likes and bookmarks while on screen.
    public init(post: KitoFeedPost, style: KitoFeedPostStyle = .social, lineLimit: Int? = 5, tint: Color? = nil) {
        self.binding = nil
        self._local = State(initialValue: post)
        self.style = style
        self.lineLimit = lineLimit
        self.tint = tint
    }

    private var post: Binding<KitoFeedPost> { binding ?? $local }
    private var value: KitoFeedPost { post.wrappedValue }
    private var accent: Color { tint ?? theme.colors.primary }

    public var body: some View {
        Group {
            if let hiddenBy {
                KitoFeedHiddenPost(action: hiddenBy, author: value.author) { select(nil) }
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.vertical, theme.spacing.sm)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            } else {
                styled
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder private var styled: some View {
        switch style {
        case .social: social
        case .card: card
        case .minimal: minimal
        case .news: news
        }
    }

    // MARK: Styles

    private var social: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            repostHeader.padding(.leading, 52 - 18)
            HStack(alignment: .top, spacing: theme.spacing.md) {
                avatarButton(size: 44)
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        KitoFeedNameLine(author: value.author, date: value.date, tint: tint)
                        Spacer(minLength: 0)
                        menu
                    }
                    .padding(.bottom, -theme.spacing.xs)
                    locationLine
                    textBody
                    media(radius: theme.radii.lg)
                    quote
                    KitoFeedActionBar(post: post, layout: .spread, tint: tint)
                        .padding(.trailing, theme.spacing.sm)
                }
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
        .accessibilityElement(children: .contain)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack(spacing: theme.spacing.sm) {
                avatarButton(size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    KitoFeedNameLine(author: value.author, date: value.date, showsHandle: false, tint: tint)
                    locationLine
                }
                Spacer(minLength: 0)
                menu
            }
            .padding(.horizontal, theme.spacing.lg)
            repostHeader.padding(.horizontal, theme.spacing.lg)
            doubleTapMedia
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                KitoFeedActionBar(post: post, layout: .leading, tint: tint)
                likedByLine
                textBody
                quote
            }
            .padding(.horizontal, theme.spacing.lg)
        }
        .padding(.vertical, theme.spacing.lg)
        .background(cardBackground)
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.sm)
        .accessibilityElement(children: .contain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: theme.radii.xl + 4, style: .continuous)
            .fill(theme.colors.surface)
            .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
            .overlay(RoundedRectangle(cornerRadius: theme.radii.xl + 4, style: .continuous)
                .strokeBorder(theme.colors.border.opacity(0.6), lineWidth: 0.5))
    }

    private var minimal: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.sm) {
                KitoFeedNameLine(author: value.author, date: value.date, showsHandle: false, tint: tint)
                Spacer(minLength: 0)
                menu
            }
            textBody
            media(radius: theme.radii.md)
            quote
            KitoFeedActionBar(post: post, layout: .compact, tint: tint)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
        .accessibilityElement(children: .contain)
    }

    private var news: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            media(radius: theme.radii.xl)
            HStack(spacing: 6) {
                avatarButton(size: 22)
                KitoFeedNameLine(author: value.author, date: value.date, showsHandle: false, tint: tint)
                Spacer(minLength: 0)
                menu
            }
            .padding(.top, theme.spacing.xs)
            if let title = value.title {
                Text(title)
                    .font(theme.typography.titleMedium)
                    .foregroundStyle(theme.colors.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            KitoRichText(value.text, lineLimit: lineLimit.map { min($0, 3) }, font: theme.typography.label.weight(.regular),
                         color: theme.colors.onSurface.opacity(0.72), tint: tint)
            KitoFeedActionBar(post: post, layout: .compact, tint: tint)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
        .accessibilityElement(children: .contain)
    }

    // MARK: Pieces

    @ViewBuilder private var repostHeader: some View {
        if let reposter = value.repostedBy {
            Label("\(reposter.name) reposted", systemImage: "arrow.2.squarepath")
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface.opacity(0.55))
        }
    }

    @ViewBuilder private var locationLine: some View {
        if let location = value.location {
            Label(location, systemImage: "mappin.and.ellipse")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.onSurface.opacity(0.55))
                .lineLimit(1)
        }
    }

    @ViewBuilder private var textBody: some View {
        if !value.text.isEmpty {
            KitoRichText(value.text, lineLimit: lineLimit, tint: tint)
        }
    }

    @ViewBuilder private var quote: some View {
        if let quote = value.quote { KitoFeedQuoteCard(quote: quote) }
    }

    private var menu: some View {
        KitoFeedOverflowMenu(post: value) { action in
            if action == .copyLink {
                UIPasteboard.general.url = value.shareURL
            } else {
                select(action)
            }
            actions.onMenu?(value, action)
        }
    }

    private func avatarButton(size: CGFloat) -> some View {
        Button { actions.onAuthor?(value.author) } label: {
            KitoFeedAvatar(person: value.author, size: size)
        }
        .buttonStyle(KitoFeedPressStyle())
        .accessibilityLabel(value.author.name)
        .accessibilityHint("Opens profile")
    }

    @ViewBuilder private func media(radius: CGFloat) -> some View {
        switch value.media {
        case .photos(let photos):
            KitoFeedPhotoGrid(photos: photos, cornerRadius: radius) { actions.onOpenMedia?(value, $0) }
        case .video(let video):
            KitoFeedVideoPoster(video: video, cornerRadius: radius) { actions.onOpenMedia?(value, 0) }
        case .link(let link):
            KitoLinkPreviewCard(link: link, style: style == .minimal ? .compact : .large, tint: tint)
        case .poll:
            KitoPollView(poll: pollBinding, tint: tint) { option in actions.onVote?(value, option) }
        case nil:
            EmptyView()
        }
    }

    /// Photos in the card style: edge to edge, double-tap to like with a big heart.
    @ViewBuilder private var doubleTapMedia: some View {
        if case .photos(let photos) = value.media {
            KitoFeedPhotoGrid(photos: photos, cornerRadius: 0)
                .overlay { KitoFeedHeartPop(trigger: heartPop) }
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: doubleTapLike)
                .onTapGesture { actions.onOpenMedia?(value, 0) }
                .accessibilityAction(named: "Like") { doubleTapLike() }
        } else {
            media(radius: theme.radii.lg).padding(.horizontal, theme.spacing.lg)
        }
    }

    @ViewBuilder private var likedByLine: some View {
        if value.likes > 0 {
            Button { actions.onShowLikes?(value) } label: { likedByText }
                .buttonStyle(.plain)
                .accessibilityHint("Shows who liked this")
        }
    }

    private var likedByText: some View {
        Text(likedByString)
            .font(theme.typography.label.weight(.regular))
            .foregroundStyle(theme.colors.onSurface)
    }

    private var likedByString: AttributedString {
        let bold = theme.typography.label.weight(.semibold)
        let others = value.likes - 1
        guard let first = value.likedBy.first, others > 0 else {
            var total = AttributedString(value.likes == 1 ? "1 like" : "\(KitoFeedFormat.fullCount(value.likes)) likes")
            total.font = bold
            return total
        }
        var name = AttributedString(first.name)
        name.font = bold
        var rest = AttributedString("\(KitoFeedFormat.fullCount(others)) others")
        rest.font = bold
        return AttributedString("Liked by ") + name + AttributedString(" and ") + rest
    }

    private var pollBinding: Binding<KitoFeedPoll> {
        Binding {
            value.poll ?? KitoFeedPoll(options: [], endsAt: .now)
        } set: { poll in
            post.wrappedValue.media = .poll(poll)
        }
    }

    private func doubleTapLike() {
        if !value.isLiked {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6)) {
                post.wrappedValue.toggleLike()
            }
            actions.onLike?(value)
        }
        heartPop += 1
    }

    private func select(_ action: KitoFeedMenuAction?) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
            hiddenBy = action
        }
    }
}
