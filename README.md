# KitoFeed

**[Documentation](https://wyksofts-inc.github.io/KitoFeed/documentation/kitofeed/)**

Social feeds and comments for SwiftUI: posts in four styles with tappable @mentions, #hashtags and
links, photo grids, video posters, link cards and polls; a like button that bursts; a feed with pull
to refresh, a "New posts" pill, endless loading and a compose button; threaded comments with
connector lines and @mention autocomplete; a likes sheet with follow buttons; and a post composer
with a character ring, live highlighting, photos, polls and an audience picker. Part of the
[Kito](https://github.com/WykSofts-Inc/KitoDevKit) ecosystem.

## A feed in one view

```swift
@State private var posts: [KitoFeedPost] = []

KitoFeedView(posts: $posts, style: .social, isLoading: posts.isEmpty, hasMore: model.hasMore,
             onRefresh: { await model.refresh() },
             onLoadMore: { await model.loadMore() },
             onCompose: { composing = true })
    .kitoFeedActions(KitoFeedActions(
        onComment: { post in openComments(post) },
        onRepost: { post, kind in if kind == .quote { quote(post) } },
        onShowLikes: { post in likesFor = post },
        onMention: { handle in openProfile(handle) },
        onHashtag: { tag in openTag(tag) }))
```

Insert newer posts at the front of `posts`. If you're scrolled down they wait above you and a pill
("3 new posts", with their authors) slides in; tapping it scrolls to the top. Posts that arrive
during pull to refresh show straight away. Reaching the end shows skeletons and calls `onLoadMore`.

## Posts

```swift
let post = KitoFeedPost(id: "p1", author: amani, date: .now.addingTimeInterval(-120),
                        text: "Sunrise over the Ngong hills with @wanjiru #nairobi",
                        media: .photos(photos), location: "Ngong Hills",
                        likes: 1_204, comments: 38, reposts: 12)

KitoFeedPostView(post: $post, style: .social)   // .card, .minimal, .news
```

- `.social` puts the avatar in a column with counts spread along the bottom.
- `.card` is a raised card with edge-to-edge photos (double-tap to like), and "Liked by Wanjiru and
  1,203 others".
- `.minimal` is name, text and small icons.
- `.news` shows media first, then the source, a headline (`title`) and a summary.

Media is `.photos([...])` (one, two, three, a 2×2 grid, and "+N" past four), `.video(...)` (a poster
with a play button and running time), `.link(...)` (`KitoLinkPreviewCard`) or `.poll(...)`
(`KitoPollView`). A post can also carry a `quote` and `repostedBy`.

The action bar likes with a heart burst and a rolling count, reposts or quotes from a menu, shares
(with `shareURL`, the system share sheet) and bookmarks. The "…" menu offers Not interested, Mute and
Report; each folds the post into a note with Undo.

## Rich text

```swift
KitoRichText("Lunch with @amani at example.com #nairobi", lineLimit: 3,
             onMention: { openProfile($0) }, onHashtag: { openTag($0) })

KitoRichTextParser.tokens(in: text)      // text, mention, hashtag and link runs
KitoRichTextParser.mentions(in: text)    // ["amani"]
```

Long text is cut with "Read more" and expands in place. An email address is not a mention, "#1" is
not a hashtag, and trailing punctuation stays out of links.

## Comments

```swift
KitoCommentsView(comments: $comments, currentUser: me, people: following,
                 onSend: { comment, parentID in api.add(comment, replyingTo: parentID) }) {
    KitoFeedPostView(post: $post, style: .minimal)
}
```

Replies nest with connector lines; each comment shows one reply and "View 4 more replies". Pinned
comments come first. Reply fills in "@name " and focuses the composer, which has an emoji quick-bar
and suggests people as you type "@". Use `KitoCommentThread` and `KitoCommentComposer` on their own
for your own layout, and `KitoCommentThreading` to flatten, insert and update comments.

## Polls, links, likes and following

```swift
KitoPollView(poll: $poll) { option in api.vote(option.id) }      // bars grow, "1,204 votes · 2h left"
KitoLinkPreviewCard(link: link, style: .compact)
KitoFollowButton(isFollowing: $person.isFollowing, name: person.name, followsYou: person.followsYou)

.sheet(item: $likesFor) { post in
    KitoLikesSheet(people: $likers, total: post.likes) { person, following in api.follow(person, following) }
}
```

`KitoPollMath.percentages` rounds so the choices always add up to 100.

## Composer

```swift
.sheet(isPresented: $composing) {
    KitoPostComposer(author: me, people: following, onCancel: { composing = false }) { composed in
        posts.insert(composed.makePost(author: me), at: 0)
        composing = false
    }
}
```

Mentions, hashtags and links are coloured as you type, and "@" suggests people. Attach up to four
photos or a poll (not both), pick who can see it, and watch the ring count down the last 20
characters. `KitoPostDraft` holds the rules for when Post is enabled if you build your own.

Picking photos uses `PhotosPicker`, which needs no permission prompt.

## Formatting

```swift
KitoFeedFormat.relativeTime(from: date)   // "now", "2m", "3h", "Yesterday", "4d", "12 Mar"
KitoFeedFormat.compactCount(1_240)        // "1.2K"
KitoFeedFormat.timeLeft(until: endsAt)    // "2h left"
```

## Right-to-left

Posts, comments, photo grids, polls and the composer mirror with the layout direction (poll bars
grow from the leading edge; the shimmer sweeps leading to trailing). Poll percentages are formatted
with the environment locale, and the comment Reply symbol points the reading way. There are no
horizontal drag gestures to adjust.

## Installation

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoFeed.git", from: "0.1.0")
```

## License

MIT — see [LICENSE](LICENSE).
