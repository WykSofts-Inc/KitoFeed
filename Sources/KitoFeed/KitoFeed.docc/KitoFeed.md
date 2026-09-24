# ``KitoFeed``

Social feeds, rich-text posts, threaded comments, and a post composer for SwiftUI.

## Overview

KitoFeed provides the building blocks of a social app. ``KitoFeedView`` shows a
list of ``KitoFeedPost`` values with pull to refresh, endless loading with
skeleton posts, a compose button, and a "New posts" pill that appears when newer
posts arrive while you are scrolled down. Each post renders in one of four
``KitoFeedPostStyle`` styles (social, card, minimal, and news) with tappable
@mentions, #hashtags and links, photo grids, video posters, link cards, and
polls.

Taps on posts, authors, mentions, hashtags and links are routed through a single
``KitoFeedActions`` value, applied to everything inside a view with
`kitoFeedActions(_:)`:

```swift
@State private var posts: [KitoFeedPost] = []

KitoFeedView(posts: $posts, style: .social, isLoading: posts.isEmpty, hasMore: model.hasMore,
             onRefresh: { await model.refresh() },
             onLoadMore: { await model.loadMore() },
             onCompose: { composing = true })
    .kitoFeedActions(KitoFeedActions(
        onComment: { post in openComments(post) },
        onMention: { handle in openProfile(handle) },
        onHashtag: { tag in openTag(tag) }))
```

``KitoCommentsView`` shows threaded comments with connector lines, pinned
comments first, and a composer with an emoji quick-bar and @mention
autocomplete. ``KitoPostComposer`` writes new posts with live highlighting,
photos or a poll, an audience picker, and a character ring.

The logic behind the views is available as plain values you can use and test on
their own: ``KitoRichTextParser`` finds mentions, hashtags and links,
``KitoMentionSearch`` drives autocomplete, ``KitoCommentThreading`` flattens and
updates comment trees, ``KitoPostDraft`` decides when a post can be sent, and
``KitoFeedFormat`` formats relative times and compact counts.

## Topics

### Feeds

- ``KitoFeedView``
- ``KitoFeedActions``
- ``KitoNewPostsTracker``
- ``KitoFeedSkeletonPost``

### Posts

- ``KitoFeedPost``
- ``KitoFeedPostView``
- ``KitoFeedPostStyle``
- ``KitoFeedPerson``
- ``KitoFeedAuthorBadge``
- ``KitoFeedQuote``
- ``KitoFeedQuoteCard``
- ``KitoFeedMenuAction``
- ``KitoFeedRepostKind``

### Media, Links, and Polls

- ``KitoFeedMedia``
- ``KitoFeedPhoto``
- ``KitoFeedPhotoGrid``
- ``KitoFeedPhotoView``
- ``KitoFeedVideo``
- ``KitoFeedVideoPoster``
- ``KitoFeedLink``
- ``KitoLinkPreviewCard``
- ``KitoLinkPreviewStyle``
- ``KitoFeedPoll``
- ``KitoFeedPollOption``
- ``KitoPollView``
- ``KitoPollMath``

### Rich Text

- ``KitoRichText``
- ``KitoRichTextParser``
- ``KitoRichTextToken``
- ``KitoRichTextKind``

### Comments

- ``KitoFeedComment``
- ``KitoCommentsView``
- ``KitoCommentThread``
- ``KitoCommentComposer``
- ``KitoCommentThreading``
- ``KitoCommentRow``
- ``KitoMentionSearch``
- ``KitoMentionSuggestionList``

### Composing Posts

- ``KitoPostComposer``
- ``KitoComposedPost``
- ``KitoPostDraft``
- ``KitoPostAudience``
- ``KitoPollDraft``
- ``KitoPollDuration``
- ``KitoCharacterCounterRing``

### Engagement and Components

- ``KitoFeedActionBar``
- ``KitoFeedLikeButton``
- ``KitoLikesSheet``
- ``KitoFollowButton``
- ``KitoFollowButtonSize``
- ``KitoFeedAvatar``
- ``KitoFeedVerifiedBadge``
- ``KitoFeedFormat``
