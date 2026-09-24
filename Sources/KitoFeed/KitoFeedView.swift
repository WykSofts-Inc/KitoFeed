//
//  KitoFeedView.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A scrolling feed: pull to refresh, a "New posts" pill when posts arrive above you, more posts
/// loading as you reach the end with skeletons, and a compose button.
///
/// ```swift
/// KitoFeedView(posts: $posts, style: .social, hasMore: hasMore,
///              onRefresh: { await model.refresh() },
///              onLoadMore: { await model.loadMore() },
///              onCompose: { composing = true })
///     .kitoFeedActions(KitoFeedActions(onComment: { openComments($0) }))
/// ```
///
/// Insert new posts at the front of `posts`. If you're scrolled down, they wait above with a pill
/// ("3 new posts" with their authors) that scrolls to the top when tapped. Posts that arrive during
/// pull to refresh show straight away.
public struct KitoFeedView<Header: View>: View {
    @Binding private var posts: [KitoFeedPost]
    private let style: KitoFeedPostStyle
    private let isLoading: Bool
    private let hasMore: Bool
    private let lineLimit: Int?
    private let composeTitle: String
    private let tint: Color?
    private let onRefresh: (() async -> Void)?
    private let onLoadMore: (() async -> Void)?
    private let onCompose: (() -> Void)?
    private let header: Header

    @State private var tracker = KitoNewPostsTracker<String>()
    @State private var topID: String?
    @State private var lastTopIndex = 0
    @State private var fabExpanded = true
    @State private var isLoadingMore = false
    @State private var isRefreshing = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - posts: Newest first. Likes, bookmarks and votes write back here.
    ///   - isLoading: Shows skeletons while `posts` is empty.
    ///   - hasMore: Whether reaching the end calls `onLoadMore`.
    ///   - onCompose: Shows a floating compose button. `nil` hides it.
    ///   - header: Scrolls above the posts, e.g. a story tray or a composer prompt.
    public init(posts: Binding<[KitoFeedPost]>, style: KitoFeedPostStyle = .social, isLoading: Bool = false,
                hasMore: Bool = false, lineLimit: Int? = 5, composeTitle: String = "Post", tint: Color? = nil,
                onRefresh: (() async -> Void)? = nil, onLoadMore: (() async -> Void)? = nil,
                onCompose: (() -> Void)? = nil, @ViewBuilder header: () -> Header) {
        self._posts = posts
        self.style = style
        self.isLoading = isLoading
        self.hasMore = hasMore
        self.lineLimit = lineLimit
        self.composeTitle = composeTitle
        self.tint = tint
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
        self.onCompose = onCompose
        self.header = header()
    }

    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82) }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                list
                footer
            }
            .padding(.bottom, onCompose == nil ? 0 : 84)
        }
        .scrollPosition(id: $topID, anchor: .top)
        .background(style == .card ? theme.colors.background : theme.colors.surface)
        .refreshable { await refresh() }
        .overlay(alignment: .top) { pill }
        .overlay(alignment: .bottomTrailing) { fab }
        .onAppear { tracker.update(ids: posts.map(\.id)) }
        .onChange(of: posts.map(\.id)) { _, ids in
            withAnimation(spring) { tracker.update(ids: ids, reveal: isRefreshing) }
        }
        .onChange(of: topID) { _, id in topChanged(id) }
    }

    private var list: some View {
        LazyVStack(spacing: 0) {
            if posts.isEmpty && isLoading {
                ForEach(0..<3, id: \.self) { index in
                    KitoFeedSkeletonPost(style: style, showsMedia: index != 1)
                    separator
                }
            }
            ForEach($posts) { $post in
                VStack(spacing: 0) {
                    KitoFeedPostView(post: $post, style: style, lineLimit: lineLimit, tint: tint)
                    separator
                }
                .id(post.id)
                .onAppear { if post.id == posts.last?.id { loadMore() } }
            }
        }
        .scrollTargetLayout()
    }

    @ViewBuilder private var separator: some View {
        if style == .social || style == .minimal {
            Rectangle().fill(theme.colors.border.opacity(0.7)).frame(height: 0.5)
        }
    }

    @ViewBuilder private var footer: some View {
        if !posts.isEmpty && hasMore {
            VStack(spacing: 0) {
                KitoFeedSkeletonPost(style: style, showsMedia: false)
                KitoFeedSkeletonPost(style: style, showsMedia: true)
            }
            .onAppear(perform: loadMore)
        } else if !posts.isEmpty {
            Label("You're all caught up", systemImage: "checkmark.circle")
                .font(theme.typography.label)
                .foregroundStyle(theme.colors.onSurface.opacity(0.5))
                .padding(.vertical, theme.spacing.xl)
        } else if !isLoading {
            VStack(spacing: theme.spacing.sm) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 34, weight: .regular))
                Text("No posts yet").font(theme.typography.titleMedium)
                Text("Posts from people you follow show up here.")
                    .font(theme.typography.label.weight(.regular))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.6))
            }
            .foregroundStyle(theme.colors.onSurface)
            .multilineTextAlignment(.center)
            .padding(.vertical, 80)
            .padding(.horizontal, theme.spacing.xl)
        }
    }

    // MARK: New posts pill

    @ViewBuilder private var pill: some View {
        if tracker.isPillVisible {
            Button(action: showNewPosts) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up").font(.system(size: 12, weight: .bold))
                    pillAvatars
                    Text(tracker.pillTitle).font(theme.typography.label.weight(.semibold))
                }
                .foregroundStyle(theme.colors.surface)
                .padding(.leading, 12)
                .padding(.trailing, 16)
                .frame(height: 40)
                .background(Capsule().fill(tint ?? theme.colors.onSurface))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            }
            .buttonStyle(KitoFeedPressStyle())
            .padding(.top, theme.spacing.sm)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel("\(tracker.pillTitle). Scroll to top")
        }
    }

    private var pillAvatars: some View {
        let authors = newAuthors
        return HStack(spacing: -8) {
            ForEach(authors) { person in
                KitoFeedAvatar(person: person, size: 24)
                    .overlay(Circle().strokeBorder(tint ?? theme.colors.onSurface, lineWidth: 2))
            }
        }
    }

    /// Up to three different authors of the unseen posts.
    private var newAuthors: [KitoFeedPerson] {
        var seen = Set<String>()
        let unseen = Set(tracker.unseen)
        return posts.filter { unseen.contains($0.id) }.map(\.author)
            .filter { seen.insert($0.id).inserted }
            .prefix(3)
            .map { $0 }
    }

    // MARK: Compose button

    @ViewBuilder private var fab: some View {
        if let onCompose {
            Button(action: onCompose) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil").font(.system(size: 19, weight: .semibold))
                    if fabExpanded {
                        Text(composeTitle)
                            .font(theme.typography.button)
                            .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .leading)))
                    }
                }
                .foregroundStyle(theme.colors.surface)
                .padding(.horizontal, fabExpanded ? 20 : 0)
                .frame(minWidth: 58, minHeight: 58)
                .background(Capsule().fill(tint ?? theme.colors.onSurface))
                .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
                .contentShape(Capsule())
            }
            .buttonStyle(KitoFeedPressStyle())
            .padding(.trailing, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
            .accessibilityLabel(composeTitle)
        }
    }

    // MARK: Behaviour

    private func topChanged(_ id: String?) {
        withAnimation(spring) { tracker.visibleTopChanged(to: id) }
        guard let id, let index = posts.firstIndex(where: { $0.id == id }) else {
            withAnimation(spring) { fabExpanded = true }
            return
        }
        let expand = index < lastTopIndex || index == 0
        if expand != fabExpanded { withAnimation(spring) { fabExpanded = expand } }
        lastTopIndex = index
    }

    private func showNewPosts() {
        withAnimation(spring) { tracker.acknowledge() }
        withAnimation(reduceMotion ? nil : .snappy) { topID = posts.first?.id }
    }

    private func refresh() async {
        guard let onRefresh else { return }
        isRefreshing = true
        await onRefresh()
        tracker.update(ids: posts.map(\.id), reveal: true)
        isRefreshing = false
        topID = posts.first?.id
    }

    private func loadMore() {
        guard hasMore, !isLoadingMore, let onLoadMore else { return }
        isLoadingMore = true
        Task {
            await onLoadMore()
            isLoadingMore = false
        }
    }
}

public extension KitoFeedView where Header == EmptyView {
    init(posts: Binding<[KitoFeedPost]>, style: KitoFeedPostStyle = .social, isLoading: Bool = false,
         hasMore: Bool = false, lineLimit: Int? = 5, composeTitle: String = "Post", tint: Color? = nil,
         onRefresh: (() async -> Void)? = nil, onLoadMore: (() async -> Void)? = nil, onCompose: (() -> Void)? = nil) {
        self.init(posts: posts, style: style, isLoading: isLoading, hasMore: hasMore, lineLimit: lineLimit,
                  composeTitle: composeTitle, tint: tint, onRefresh: onRefresh, onLoadMore: onLoadMore,
                  onCompose: onCompose) { EmptyView() }
    }
}
