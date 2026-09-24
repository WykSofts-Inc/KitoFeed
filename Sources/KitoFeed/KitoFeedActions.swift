//
//  KitoFeedActions.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI

/// What happens when someone taps things in a post. Set it once for a whole feed with
/// `.kitoFeedActions(_:)`; everything is optional.
///
/// Likes, reposts, bookmarks and votes already update the post on screen; these closures are
/// where you tell your backend.
///
/// ```swift
/// KitoFeedView(posts: $posts)
///     .kitoFeedActions(KitoFeedActions(
///         onComment: { post in openComments(post) },
///         onRepost: { post, kind in if kind == .quote { quote(post) } },
///         onMention: { handle in openProfile(handle) }))
/// ```
public struct KitoFeedActions {
    public var onLike: ((KitoFeedPost) -> Void)?
    public var onComment: ((KitoFeedPost) -> Void)?
    public var onRepost: ((KitoFeedPost, KitoFeedRepostKind) -> Void)?
    /// Called for Share when the post has no `shareURL` (with one, the system share sheet opens).
    public var onShare: ((KitoFeedPost) -> Void)?
    public var onBookmark: ((KitoFeedPost) -> Void)?
    public var onMenu: ((KitoFeedPost, KitoFeedMenuAction) -> Void)?
    public var onVote: ((KitoFeedPost, KitoFeedPollOption) -> Void)?
    /// A photo or the video was tapped, with the index of the photo.
    public var onOpenMedia: ((KitoFeedPost, Int) -> Void)?
    public var onAuthor: ((KitoFeedPerson) -> Void)?
    /// The like count was tapped, e.g. to show `KitoLikesSheet`.
    public var onShowLikes: ((KitoFeedPost) -> Void)?
    public var onMention: ((String) -> Void)?
    public var onHashtag: ((String) -> Void)?
    /// A link was tapped. `nil` opens it with the system.
    public var onLink: ((URL) -> Void)?

    public init(onLike: ((KitoFeedPost) -> Void)? = nil,
                onComment: ((KitoFeedPost) -> Void)? = nil,
                onRepost: ((KitoFeedPost, KitoFeedRepostKind) -> Void)? = nil,
                onShare: ((KitoFeedPost) -> Void)? = nil,
                onBookmark: ((KitoFeedPost) -> Void)? = nil,
                onMenu: ((KitoFeedPost, KitoFeedMenuAction) -> Void)? = nil,
                onVote: ((KitoFeedPost, KitoFeedPollOption) -> Void)? = nil,
                onOpenMedia: ((KitoFeedPost, Int) -> Void)? = nil,
                onAuthor: ((KitoFeedPerson) -> Void)? = nil,
                onShowLikes: ((KitoFeedPost) -> Void)? = nil,
                onMention: ((String) -> Void)? = nil,
                onHashtag: ((String) -> Void)? = nil,
                onLink: ((URL) -> Void)? = nil) {
        self.onLike = onLike
        self.onComment = onComment
        self.onRepost = onRepost
        self.onShare = onShare
        self.onBookmark = onBookmark
        self.onMenu = onMenu
        self.onVote = onVote
        self.onOpenMedia = onOpenMedia
        self.onAuthor = onAuthor
        self.onShowLikes = onShowLikes
        self.onMention = onMention
        self.onHashtag = onHashtag
        self.onLink = onLink
    }
}

private struct KitoFeedActionsKey: EnvironmentKey {
    static var defaultValue: KitoFeedActions { KitoFeedActions() }
}

public extension EnvironmentValues {
    /// The handlers used by every post, comment and rich text inside this view.
    var kitoFeedActions: KitoFeedActions {
        get { self[KitoFeedActionsKey.self] }
        set { self[KitoFeedActionsKey.self] = newValue }
    }
}

public extension View {
    /// Sets what taps on posts, mentions, hashtags and links do for everything inside this view.
    func kitoFeedActions(_ actions: KitoFeedActions) -> some View {
        environment(\.kitoFeedActions, actions)
    }
}
