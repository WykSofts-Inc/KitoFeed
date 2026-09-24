//
//  KitoFeedActionBar.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Like, comment, repost (or quote), share and bookmark for a post.
///
/// ```swift
/// KitoFeedActionBar(post: $post, layout: .spread)
/// ```
public struct KitoFeedActionBar: View {
    /// How the buttons are arranged.
    public enum Layout: Sendable {
        /// Spread across the width with counts, like a timeline.
        case spread
        /// Like, comment and share on the left, bookmark on the right, like a photo app.
        case leading
        /// Small icons with counts, tight together.
        case compact
    }

    @Binding private var post: KitoFeedPost
    private let layout: Layout
    private let tint: Color?

    @State private var bookmarkBounce = 0
    @Environment(\.kitoTheme) private var theme
    @Environment(\.kitoFeedActions) private var actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(post: Binding<KitoFeedPost>, layout: Layout = .spread, tint: Color? = nil) {
        self._post = post
        self.layout = layout
        self.tint = tint
    }

    private var iconSize: CGFloat { layout == .compact ? 15 : (layout == .leading ? 22 : 18) }
    private var idle: Color { theme.colors.onSurface.opacity(0.62) }
    private var reposted: Color { theme.colors.success }
    private var showsCounts: Bool { layout != .leading }

    public var body: some View {
        HStack(spacing: layout == .compact ? theme.spacing.lg : theme.spacing.md) {
            switch layout {
            case .spread:
                comment
                Spacer(minLength: 0)
                repost
                Spacer(minLength: 0)
                like
                Spacer(minLength: 0)
                bookmark
                share
            case .leading:
                like
                comment
                share
                Spacer()
                bookmark
            case .compact:
                like
                comment
                repost
                Spacer()
                bookmark
            }
        }
        .foregroundStyle(idle)
    }

    private var like: some View {
        KitoFeedLikeButton(isLiked: $post.isLiked, count: $post.likes, showsCount: showsCounts, size: iconSize,
                           tint: tint) { _ in
            actions.onLike?(post)
        }
    }

    private var comment: some View {
        Button { actions.onComment?(post) } label: {
            iconAndCount("bubble.right", count: post.comments)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Comment")
        .accessibilityValue("\(KitoFeedFormat.fullCount(post.comments)) comments")
    }

    private var repost: some View {
        Menu {
            Button(post.isReposted ? "Undo repost" : "Repost", systemImage: "arrow.2.squarepath") {
                toggleRepost()
            }
            Button("Quote", systemImage: "quote.bubble") {
                actions.onRepost?(post, .quote)
            }
        } label: {
            iconAndCount("arrow.2.squarepath", count: post.reposts, color: post.isReposted ? reposted : nil)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: post.isReposted) { _, new in new }
        .accessibilityLabel(post.isReposted ? "Reposted" : "Repost")
        .accessibilityValue("\(KitoFeedFormat.fullCount(post.reposts)) reposts")
    }

    @ViewBuilder private var share: some View {
        if let url = post.shareURL {
            ShareLink(item: url) { iconOnly("square.and.arrow.up") }
                .buttonStyle(.plain)
                .accessibilityLabel("Share")
        } else {
            Button { actions.onShare?(post) } label: { iconOnly("square.and.arrow.up") }
                .buttonStyle(.plain)
                .accessibilityLabel("Share")
        }
    }

    private var bookmark: some View {
        Button(action: toggleBookmark) {
            Image(systemName: post.isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(post.isBookmarked ? (tint ?? theme.colors.onSurface) : idle)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: bookmarkBounce)
                .frame(minWidth: 32, minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: post.isBookmarked)
        .accessibilityLabel(post.isBookmarked ? "Remove bookmark" : "Bookmark")
    }

    private func iconOnly(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: iconSize, weight: .semibold))
            .frame(minWidth: 32, minHeight: 36)
            .contentShape(Rectangle())
    }

    private func iconAndCount(_ symbol: String, count: Int, color: Color? = nil) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .semibold))
            if showsCounts {
                KitoFeedRollingCount(count: count)
            }
        }
        .foregroundStyle(color ?? idle)
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }

    private func toggleRepost() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
            post.toggleRepost()
        }
        actions.onRepost?(post, post.isReposted ? .repost : .undoRepost)
    }

    private func toggleBookmark() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
            post.isBookmarked.toggle()
        }
        if !reduceMotion { bookmarkBounce += 1 }
        actions.onBookmark?(post)
    }
}
