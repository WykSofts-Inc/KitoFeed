//
//  KitoRichTextTests.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoFeed

// MARK: - Tokenizer

final class KitoRichTextParserTests: XCTestCase {
    private func kinds(_ text: String) -> [KitoRichTextKind] { KitoRichTextParser.tokens(in: text).map(\.kind) }
    private func values(_ text: String) -> [String] { KitoRichTextParser.tokens(in: text).map(\.value) }

    func testSplitsMentionsHashtagsAndBareLinks() {
        let text = "Lunch with @amani at kito.dev #nairobi"
        XCTAssertEqual(kinds(text), [.text, .mention, .text, .link, .text, .hashtag])
        XCTAssertEqual(values(text), ["Lunch with ", "amani", " at ", "https://kito.dev", " ", "nairobi"])
    }

    func testJoiningTokensGivesBackTheInput() {
        let text = "Karibu @wanjiru! 🇰🇪 See https://kito.dev/feed?x=1 and #Jambo, (www.kito.dev). Done"
        XCTAssertEqual(KitoRichTextParser.tokens(in: text).map(\.text).joined(), text)
    }

    func testEmailIsNotAMentionOrALink() {
        let text = "Write to hi@kito.dev today"
        XCTAssertEqual(kinds(text), [.text])
    }

    func testTrailingPunctuationIsLeftOutOfLinks() {
        let tokens = KitoRichTextParser.tokens(in: "See https://kito.dev/feed.")
        XCTAssertEqual(tokens.map(\.kind), [.text, .link, .text])
        XCTAssertEqual(tokens[1].text, "https://kito.dev/feed")
        XCTAssertEqual(tokens[2].text, ".")
    }

    func testUnmatchedClosingParenthesisIsLeftOut() {
        let tokens = KitoRichTextParser.tokens(in: "(see www.kito.dev)")
        XCTAssertEqual(tokens.map(\.text), ["(see ", "www.kito.dev", ")"])
        XCTAssertEqual(tokens[1].url, URL(string: "https://www.kito.dev"))
    }

    func testHashInsideALinkIsPartOfTheLink() {
        XCTAssertEqual(kinds("https://kito.dev/#top"), [.link])
    }

    func testHashtagNeedsALetterAndAWordBoundary() {
        XCTAssertEqual(KitoRichTextParser.hashtags(in: "#1 is not a tag but #ke2026 is"), ["ke2026"])
        XCTAssertEqual(KitoRichTextParser.hashtags(in: "I write C# daily"), [])
    }

    func testUnicodeHashtags() {
        XCTAssertEqual(KitoRichTextParser.hashtags(in: "#Karibu 🇰🇪 #Jambo"), ["Karibu", "Jambo"])
    }

    func testMentionWithInnerDotStopsBeforeFinalDot() {
        let tokens = KitoRichTextParser.tokens(in: "cc @amani.o.")
        XCTAssertEqual(tokens.map(\.kind), [.text, .mention, .text])
        XCTAssertEqual(tokens[1].value, "amani.o")
        XCTAssertEqual(tokens[2].text, ".")
    }

    func testMentionsAreUniqueIgnoringCase() {
        XCTAssertEqual(KitoRichTextParser.mentions(in: "@Amani and @amani and @juma"), ["Amani", "juma"])
    }

    func testLinksAreCollected() {
        XCTAssertEqual(KitoRichTextParser.links(in: "a kito.dev b http://x.co"),
                       [URL(string: "https://kito.dev"), URL(string: "http://x.co")].compactMap { $0 })
    }

    func testEmptyAndPlainText() {
        XCTAssertEqual(KitoRichTextParser.tokens(in: ""), [])
        XCTAssertEqual(kinds("Habari yako"), [.text])
    }

    func testStylerShortensLinksAndRoundTripsInternalURLs() throws {
        XCTAssertEqual(KitoRichTextStyler.displayLink("https://www.kito.dev/feed/"), "kito.dev/feed")
        let mention = KitoRichTextToken(kind: .mention, text: "@amani", value: "amani")
        let url = try XCTUnwrap(KitoRichTextStyler.internalURL(mention))
        XCTAssertEqual(KitoRichTextStyler.target(of: url), .mention("amani"))
        let tag = KitoRichTextToken(kind: .hashtag, text: "#Karibu", value: "Karibu")
        XCTAssertEqual(KitoRichTextStyler.target(of: try XCTUnwrap(KitoRichTextStyler.internalURL(tag))), .hashtag("Karibu"))
        let web = try XCTUnwrap(URL(string: "https://kito.dev"))
        XCTAssertEqual(KitoRichTextStyler.target(of: web), .link(web))
    }
}

// MARK: - Formatting

final class KitoFeedFormatTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 12)) ?? .now
    }

    private func label(_ secondsAgo: TimeInterval) -> String {
        KitoFeedFormat.relativeTime(from: now.addingTimeInterval(-secondsAgo), now: now, calendar: calendar,
                                    locale: Locale(identifier: "en_GB"))
    }

    func testRelativeTimeUnderADay() {
        XCTAssertEqual(label(30), "now")
        XCTAssertEqual(label(-500), "now")
        XCTAssertEqual(label(120), "2m")
        XCTAssertEqual(label(59 * 60), "59m")
        XCTAssertEqual(label(3 * 3_600), "3h")
        XCTAssertEqual(label(23 * 3_600), "23h")
    }

    func testRelativeTimeYesterdayDaysAndDates() {
        XCTAssertEqual(label(30 * 3_600), "Yesterday")
        XCTAssertEqual(label(47 * 3_600), "2d")
        XCTAssertEqual(label(3 * 86_400), "3d")
        XCTAssertEqual(label(10 * 86_400), "10 Mar")
        XCTAssertEqual(label(375 * 86_400), "10 Mar 2025")
    }

    func testCompactCounts() {
        XCTAssertEqual(KitoFeedFormat.compactCount(0), "0")
        XCTAssertEqual(KitoFeedFormat.compactCount(999), "999")
        XCTAssertEqual(KitoFeedFormat.compactCount(1_000), "1K")
        XCTAssertEqual(KitoFeedFormat.compactCount(1_250), "1.2K")
        XCTAssertEqual(KitoFeedFormat.compactCount(1_299), "1.2K")
        XCTAssertEqual(KitoFeedFormat.compactCount(12_400), "12.4K")
        XCTAssertEqual(KitoFeedFormat.compactCount(123_456), "123K")
        XCTAssertEqual(KitoFeedFormat.compactCount(999_999), "999K")
        XCTAssertEqual(KitoFeedFormat.compactCount(1_000_000), "1M")
        XCTAssertEqual(KitoFeedFormat.compactCount(3_450_000), "3.4M")
        XCTAssertEqual(KitoFeedFormat.compactCount(1_100_000_000), "1.1B")
        XCTAssertEqual(KitoFeedFormat.compactCount(-5), "0")
    }

    func testTimeLeft() {
        let start = now
        XCTAssertEqual(KitoFeedFormat.timeLeft(until: start.addingTimeInterval(2 * 3_600), now: start), "2h left")
        XCTAssertEqual(KitoFeedFormat.timeLeft(until: start.addingTimeInterval(90), now: start), "2m left")
        XCTAssertEqual(KitoFeedFormat.timeLeft(until: start.addingTimeInterval(30), now: start), "Less than a minute left")
        XCTAssertEqual(KitoFeedFormat.timeLeft(until: start.addingTimeInterval(3 * 86_400), now: start), "3d left")
        XCTAssertEqual(KitoFeedFormat.timeLeft(until: start.addingTimeInterval(-1), now: start), "Final results")
    }

    func testDuration() {
        XCTAssertEqual(KitoFeedFormat.duration(42), "0:42")
        XCTAssertEqual(KitoFeedFormat.duration(185), "3:05")
        XCTAssertEqual(KitoFeedFormat.duration(3_730), "1:02:10")
    }
}

// MARK: - Polls

final class KitoPollMathTests: XCTestCase {
    func testPercentagesAlwaysSumToHundred() {
        XCTAssertEqual(KitoPollMath.percentages([1, 1, 1]), [34, 33, 33])
        XCTAssertEqual(KitoPollMath.percentages([2, 1]), [67, 33])
        XCTAssertEqual(KitoPollMath.percentages([5]), [100])
        for votes in [[1, 2, 3, 4, 5, 6, 7], [7, 7, 7, 7, 7, 7], [1, 998, 1], [3, 0, 0, 1]] {
            XCTAssertEqual(KitoPollMath.percentages(votes).reduce(0, +), 100, "\(votes)")
        }
    }

    func testNoVotesAndNegativeVotes() {
        XCTAssertEqual(KitoPollMath.percentages([0, 0]), [0, 0])
        XCTAssertEqual(KitoPollMath.percentages([]), [])
        XCTAssertEqual(KitoPollMath.percentages([-3, 3]), [0, 100])
    }

    func testLeaders() {
        XCTAssertEqual(KitoPollMath.leaders([3, 5, 5]), [1, 2])
        XCTAssertEqual(KitoPollMath.leaders([0, 0]), [])
    }

    func testVotingOnceWhileOpen() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        var poll = KitoFeedPoll(options: [KitoFeedPollOption(id: "a", text: "Chai", votes: 2),
                                          KitoFeedPollOption(id: "b", text: "Kahawa", votes: 1)],
                                endsAt: now.addingTimeInterval(3_600))
        XCTAssertFalse(poll.showsResults(at: now))
        XCTAssertTrue(poll.vote(for: "b", at: now))
        XCTAssertEqual(poll.options[1].votes, 2)
        XCTAssertEqual(poll.votedOptionID, "b")
        XCTAssertTrue(poll.showsResults(at: now))
        XCTAssertFalse(poll.vote(for: "a", at: now))
        XCTAssertEqual(poll.totalVotes, 4)
        XCTAssertEqual(poll.percentages, [50, 50])
    }

    func testNoVotingAfterClose() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        var poll = KitoFeedPoll(options: [KitoFeedPollOption(id: "a", text: "Yes")], endsAt: now)
        XCTAssertTrue(poll.isClosed(at: now))
        XCTAssertTrue(poll.showsResults(at: now))
        XCTAssertFalse(poll.vote(for: "a", at: now))
    }
}
