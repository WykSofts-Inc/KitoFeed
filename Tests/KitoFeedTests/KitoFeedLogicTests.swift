//
//  KitoFeedLogicTests.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoFeed

private enum People {
    static let wanjiru = KitoFeedPerson(id: "1", name: "Wanjiru Kamau", handle: "wanjiru")
    static let amani = KitoFeedPerson(id: "2", name: "Amani Otieno", handle: "amani_o")
    static let juma = KitoFeedPerson(id: "3", name: "Juma Wafula", handle: "jwafula")
    static let zawadi = KitoFeedPerson(id: "4", name: "Zawadi Achieng", handle: "zawadi", isFollowing: true)
    static let emile = KitoFeedPerson(id: "5", name: "Émile Nkurunziza", handle: "emile")
    static let all = [wanjiru, amani, juma, zawadi, emile]
}

// MARK: - Mention autocomplete

final class KitoMentionSearchTests: XCTestCase {
    func testActiveQuery() {
        XCTAssertEqual(KitoMentionSearch.activeQuery(in: "Hi @wa"), "wa")
        XCTAssertEqual(KitoMentionSearch.activeQuery(in: "Hi @"), "")
        XCTAssertEqual(KitoMentionSearch.activeQuery(in: "@"), "")
        XCTAssertEqual(KitoMentionSearch.activeQuery(in: "(@am"), "am")
        XCTAssertNil(KitoMentionSearch.activeQuery(in: "hi@wa"))
        XCTAssertNil(KitoMentionSearch.activeQuery(in: "Hi @wa "))
        XCTAssertNil(KitoMentionSearch.activeQuery(in: "No mention"))
    }

    func testCompleteReplacesTheTypedMention() {
        XCTAssertEqual(KitoMentionSearch.complete("Hi @wa", with: People.wanjiru), "Hi @wanjiru ")
        XCTAssertEqual(KitoMentionSearch.complete("Hi", with: People.wanjiru), "Hi @wanjiru ")
        XCTAssertEqual(KitoMentionSearch.complete("", with: People.wanjiru), "@wanjiru ")
    }

    func testFilterRanksHandleThenNameWordThenContains() {
        let result = KitoMentionSearch.filter(People.all, query: "wa").map(\.handle)
        XCTAssertEqual(result, ["wanjiru", "jwafula", "zawadi"])
    }

    func testFilterIgnoresCaseAndAccents() {
        XCTAssertEqual(KitoMentionSearch.filter(People.all, query: "EMI").map(\.handle), ["emile"])
        XCTAssertEqual(KitoMentionSearch.filter(People.all, query: "nkuru").map(\.handle), ["emile"])
    }

    func testEmptyQueryListsFollowedPeopleFirstAndRespectsLimit() {
        let everyone = KitoMentionSearch.filter(People.all, query: "")
        XCTAssertEqual(everyone.count, 5)
        XCTAssertEqual(everyone.first?.handle, "zawadi")
        XCTAssertEqual(KitoMentionSearch.filter(People.all, query: "", limit: 2).count, 2)
        XCTAssertEqual(KitoMentionSearch.filter(People.all, query: "xyz"), [])
    }

    func testMatchRange() {
        XCTAssertEqual(KitoMentionSearch.matchRange(of: "wa", in: "Juma Wafula"), 5..<7)
        XCTAssertEqual(KitoMentionSearch.matchRange(of: "wa", in: "@wanjiru"), 1..<3)
        XCTAssertNil(KitoMentionSearch.matchRange(of: "", in: "Juma"))
    }
}

// MARK: - New posts pill

final class KitoNewPostsTrackerTests: XCTestCase {
    func testFirstLoadIsNotNew() {
        var tracker = KitoNewPostsTracker<String>()
        tracker.update(ids: ["a", "b"])
        XCTAssertFalse(tracker.isPillVisible)
    }

    func testEmptyFirstLoadWaitsForRealPosts() {
        var tracker = KitoNewPostsTracker<String>()
        tracker.update(ids: [])
        tracker.update(ids: ["a"])
        XCTAssertFalse(tracker.isPillVisible)
    }

    func testPostsArrivingAtTheTopShowThePill() {
        var tracker = KitoNewPostsTracker<String>()
        tracker.update(ids: ["a", "b"])
        tracker.update(ids: ["x", "y", "a", "b"])
        XCTAssertTrue(tracker.isPillVisible)
        XCTAssertEqual(tracker.unseen, ["x", "y"])
        XCTAssertEqual(tracker.pillTitle, "2 new posts")
        tracker.update(ids: ["z", "x", "y", "a", "b"])
        XCTAssertEqual(tracker.unseen, ["z", "x", "y"])
    }

    func testScrollingUpToANewPostHidesThePill() {
        var tracker = KitoNewPostsTracker<String>()
        tracker.update(ids: ["a", "b"])
        tracker.update(ids: ["x", "y", "a", "b"])
        tracker.visibleTopChanged(to: "a")
        XCTAssertTrue(tracker.isPillVisible)
        tracker.visibleTopChanged(to: "y")
        XCTAssertFalse(tracker.isPillVisible)
    }

    func testRefreshRevealsAndOlderPostsAreNeverNew() {
        var tracker = KitoNewPostsTracker<String>()
        tracker.update(ids: ["a"])
        tracker.update(ids: ["a", "old"])
        XCTAssertFalse(tracker.isPillVisible)
        tracker.update(ids: ["n", "a", "old"], reveal: true)
        XCTAssertFalse(tracker.isPillVisible)
    }

    func testAcknowledgeAndRemovedPosts() {
        var tracker = KitoNewPostsTracker<String>()
        tracker.update(ids: ["a"])
        tracker.update(ids: ["x", "a"])
        XCTAssertEqual(tracker.pillTitle, "1 new post")
        tracker.update(ids: ["a"])
        XCTAssertFalse(tracker.isPillVisible)
        tracker.update(ids: ["y", "a"])
        tracker.acknowledge()
        XCTAssertFalse(tracker.isPillVisible)
    }
}

// MARK: - Comment threads

final class KitoCommentThreadingTests: XCTestCase {
    private func comment(_ id: String, pinned: Bool = false, replies: [KitoFeedComment] = []) -> KitoFeedComment {
        KitoFeedComment(id: id, author: People.amani, text: id, date: Date(timeIntervalSince1970: 0),
                        isPinned: pinned, replies: replies)
    }

    private var thread: [KitoFeedComment] {
        [comment("c1", replies: [comment("r1", replies: [comment("rr1")]), comment("r2"), comment("r3")]),
         comment("c2", pinned: true),
         comment("c3")]
    }

    func testFlattensWithPinnedFirstAndMoreRow() {
        let rows = KitoCommentThreading.rows(for: thread)
        XCTAssertEqual(rows.map(\.id), ["c2", "c1", "r1", "rr1", "more-c1", "c3"])
        XCTAssertEqual(rows.map(\.depth), [0, 0, 1, 2, 1, 0])
        XCTAssertEqual(rows[4].kind, .moreReplies(parentID: "c1", count: 2))
    }

    func testConnectorLines() {
        let rows = KitoCommentThreading.rows(for: thread)
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        XCTAssertEqual(byID["c1"]?.hasVisibleReplies, true)
        XCTAssertEqual(byID["c2"]?.hasVisibleReplies, false)
        XCTAssertEqual(byID["r1"]?.hasVisibleReplies, true)
        XCTAssertEqual(byID["r1"]?.continuesBelow, true)
        XCTAssertEqual(byID["rr1"]?.passThroughLevels, [0])
        XCTAssertEqual(byID["rr1"]?.continuesBelow, false)
        XCTAssertEqual(byID["more-c1"]?.continuesBelow, false)
    }

    func testExpandedShowsEveryReplyAndHide() {
        let rows = KitoCommentThreading.rows(for: thread, expanded: ["c1"])
        XCTAssertEqual(rows.map(\.id), ["c2", "c1", "r1", "rr1", "r2", "r3", "hide-c1", "c3"])
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        XCTAssertEqual(byID["r2"]?.continuesBelow, true)
        XCTAssertEqual(byID["r3"]?.continuesBelow, true)
        XCTAssertEqual(byID["hide-c1"]?.continuesBelow, false)
    }

    func testCollapsedHidesAllReplies() {
        let rows = KitoCommentThreading.rows(for: thread, collapsed: ["c1"])
        XCTAssertEqual(rows.map(\.id), ["c2", "c1", "more-c1", "c3"])
        XCTAssertEqual(rows[2].kind, .moreReplies(parentID: "c1", count: 3))
    }

    func testRepliesPastMaxDepthStayAtTheLastLevel() {
        let rows = KitoCommentThreading.rows(for: thread, maxDepth: 1)
        XCTAssertEqual(rows.first { $0.id == "rr1" }?.depth, 1)
        XCTAssertEqual(rows.first { $0.id == "r1" }?.hasVisibleReplies, false)
        XCTAssertEqual(rows.first { $0.id == "r1" }?.continuesBelow, true)
    }

    func testCountingAndEditing() throws {
        var comments = thread
        XCTAssertEqual(KitoCommentThreading.totalCount(comments), 7)
        XCTAssertTrue(KitoCommentThreading.insert(comment("new"), under: "rr1", in: &comments))
        XCTAssertEqual(KitoCommentThreading.find("rr1", in: comments)?.replies.map(\.id), ["new"])
        XCTAssertFalse(KitoCommentThreading.insert(comment("lost"), under: "nope", in: &comments))
        XCTAssertTrue(KitoCommentThreading.insert(comment("top"), under: nil, in: &comments))
        XCTAssertEqual(comments.last?.id, "top")
        XCTAssertTrue(KitoCommentThreading.update("r2", in: &comments) { $0.toggleLike() })
        let liked = try XCTUnwrap(KitoCommentThreading.find("r2", in: comments))
        XCTAssertTrue(liked.isLiked)
        XCTAssertEqual(liked.likes, 1)
        XCTAssertEqual(KitoCommentThreading.root(of: "new", in: comments)?.id, "c1")
    }
}

// MARK: - Composer rules

final class KitoPostDraftTests: XCTestCase {
    func testNeedsSomethingToPost() {
        let empty = KitoPostDraft(text: "   \n")
        XCTAssertFalse(empty.canPost)
        XCTAssertEqual(empty.blocker, "Write something or add a photo")
        XCTAssertTrue(KitoPostDraft(text: "Habari").canPost)
        XCTAssertTrue(KitoPostDraft(photoCount: 2).canPost)
    }

    func testCharacterLimit() {
        let draft = KitoPostDraft(text: "Habari")
        XCTAssertEqual(draft.remaining, 274)
        XCTAssertFalse(draft.showsRemaining)
        let over = KitoPostDraft(text: String(repeating: "a", count: 281))
        XCTAssertTrue(over.isOverLimit)
        XCTAssertFalse(over.canPost)
        XCTAssertEqual(over.blocker, "1 over the limit")
        XCTAssertTrue(KitoPostDraft(text: String(repeating: "a", count: 265)).showsRemaining)
        XCTAssertEqual(KitoPostDraft(text: "🇰🇪👍🏽").characterCount, 2)
    }

    func testPollRules() {
        var draft = KitoPostDraft(poll: KitoPollDraft(options: ["Yes", "No"]))
        XCTAssertEqual(draft.blocker, "Ask a question for your poll")
        draft.text = "Chai or kahawa?"
        XCTAssertTrue(draft.canPost)
        XCTAssertFalse(draft.canAttachPhotos)
        XCTAssertFalse(draft.canAddPoll)
        draft.poll = KitoPollDraft(options: ["Yes", ""])
        XCTAssertEqual(draft.blocker, "Add at least two choices")
        draft.poll = KitoPollDraft(options: ["Yes", "No", ""])
        XCTAssertEqual(draft.blocker, "Fill in or remove empty choices")
        draft.poll = KitoPollDraft(options: ["Yes", "yes"])
        XCTAssertEqual(draft.blocker, "Choices must be different")
        draft.poll = KitoPollDraft(options: ["Yes", String(repeating: "n", count: 26)])
        XCTAssertEqual(draft.blocker, "Keep choices to 25 characters")
    }

    func testPhotosAndPollDontMix() {
        let draft = KitoPostDraft(text: "Look", photoCount: 1)
        XCTAssertFalse(draft.canAddPoll)
        XCTAssertTrue(draft.canAttachPhotos)
        XCTAssertFalse(KitoPostDraft(photoCount: 4).canAttachPhotos)
    }

    func testPostingDisablesPost() {
        XCTAssertFalse(KitoPostDraft(text: "Habari", isPosting: true).canPost)
    }

    func testMentionsHashtagsAndMadePoll() {
        let draft = KitoPostDraft(text: "Habari @amani #nairobi #Nairobi")
        XCTAssertEqual(draft.mentions, ["amani"])
        XCTAssertEqual(draft.hashtags, ["nairobi"])
        let now = Date(timeIntervalSince1970: 0)
        let poll = KitoPollDraft(options: [" Chai ", "Kahawa"], duration: 3_600).makePoll(now: now)
        XCTAssertEqual(poll.options.map(\.text), ["Chai", "Kahawa"])
        XCTAssertEqual(poll.endsAt, now.addingTimeInterval(3_600))
    }
}

// MARK: - Models and layout helpers

final class KitoFeedModelTests: XCTestCase {
    func testToggleLikeAndRepostMoveCounts() {
        var post = KitoFeedPost(id: "p", author: People.juma, date: .now, text: "Hi", likes: 0, reposts: 3)
        post.toggleLike()
        XCTAssertEqual(post.likes, 1)
        post.toggleLike()
        XCTAssertEqual(post.likes, 0)
        post.toggleRepost()
        XCTAssertEqual(post.reposts, 4)
        XCTAssertTrue(post.isReposted)
    }

    func testInitialsAndSite() throws {
        XCTAssertEqual(People.wanjiru.initials, "WK")
        XCTAssertEqual(KitoFeedPerson(id: "x", name: "", handle: "kito").initials, "K")
        let link = KitoFeedLink(url: try XCTUnwrap(URL(string: "https://www.kito.dev/a")), title: "A")
        XCTAssertEqual(link.displaySite, "kito.dev")
    }

    func testPhotoGridOverflowAndAspect() {
        XCTAssertNil(KitoFeedPhotoGrid.overflow(for: 4))
        XCTAssertEqual(KitoFeedPhotoGrid.overflow(for: 5), 2)
        XCTAssertEqual(KitoFeedPhotoGrid.overflow(for: 9), 6)
        XCTAssertEqual(KitoFeedPhotoGrid.aspectRatio(for: [KitoFeedPhoto(aspectRatio: 3)]), 1.9)
        XCTAssertEqual(KitoFeedPhotoGrid.aspectRatio(for: [KitoFeedPhoto(aspectRatio: 0.5)]), 0.8)
        XCTAssertEqual(KitoFeedPhotoGrid.aspectRatio(for: [KitoFeedPhoto(), KitoFeedPhoto()]), 1.6)
    }
}
