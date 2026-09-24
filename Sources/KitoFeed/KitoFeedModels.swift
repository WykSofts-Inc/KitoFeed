//
//  KitoFeedModels.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI

// MARK: - People

/// Someone who posts, comments, likes or can be mentioned.
public struct KitoFeedPerson: Identifiable, Hashable, Sendable {
    public var id: String
    /// Display name, e.g. "Amani Otieno".
    public var name: String
    /// Handle without the "@", e.g. "amani".
    public var handle: String
    public var avatarURL: URL?
    /// Background for the initials avatar when there is no image. `nil` picks one from the id.
    public var avatarColor: Color?
    public var isVerified: Bool
    /// Whether the current user follows this person.
    public var isFollowing: Bool
    /// Whether this person follows the current user ("Follows you").
    public var followsYou: Bool
    /// A short line under the name in lists, e.g. "Designer · Nairobi".
    public var bio: String?

    public init(id: String, name: String, handle: String, avatarURL: URL? = nil, avatarColor: Color? = nil,
                isVerified: Bool = false, isFollowing: Bool = false, followsYou: Bool = false, bio: String? = nil) {
        self.id = id
        self.name = name
        self.handle = handle
        self.avatarURL = avatarURL
        self.avatarColor = avatarColor
        self.isVerified = isVerified
        self.isFollowing = isFollowing
        self.followsYou = followsYou
        self.bio = bio
    }

    /// Up to two initials from the name, e.g. "AO" for "Amani Otieno".
    public var initials: String {
        let words = name.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map { String($0) }
        let joined = letters.joined().uppercased()
        return joined.isEmpty ? String(handle.prefix(1)).uppercased() : joined
    }
}

// MARK: - Media

/// A photo in a post. With no `url` it is drawn from `colors` (and `symbol`), which keeps
/// previews and tests offline.
public struct KitoFeedPhoto: Identifiable, Hashable, Sendable {
    public var id: String
    public var url: URL?
    /// Gradient stops used as the placeholder, or as the picture itself when there's no URL.
    public var colors: [Color]
    /// An SF Symbol drawn over the gradient when there's no URL.
    public var symbol: String?
    /// Width divided by height. Single photos use it, clamped so they are never too tall.
    public var aspectRatio: CGFloat?
    /// Read by VoiceOver.
    public var altText: String?

    public init(id: String = UUID().uuidString, url: URL? = nil, colors: [Color] = [], symbol: String? = nil,
                aspectRatio: CGFloat? = nil, altText: String? = nil) {
        self.id = id
        self.url = url
        self.colors = colors
        self.symbol = symbol
        self.aspectRatio = aspectRatio
        self.altText = altText
    }
}

/// A video shown as a poster with a play button. Playback is up to the app.
public struct KitoFeedVideo: Hashable, Sendable {
    public var poster: KitoFeedPhoto
    public var duration: TimeInterval
    public var url: URL?
    public var viewCount: Int?

    public init(poster: KitoFeedPhoto, duration: TimeInterval, url: URL? = nil, viewCount: Int? = nil) {
        self.poster = poster
        self.duration = duration
        self.url = url
        self.viewCount = viewCount
    }
}

/// The card shown for a shared link.
public struct KitoFeedLink: Hashable, Sendable {
    public var url: URL
    public var title: String
    public var summary: String?
    /// Shown above the title. Defaults to the URL's host without "www.".
    public var siteName: String?
    public var image: KitoFeedPhoto?

    public init(url: URL, title: String, summary: String? = nil, siteName: String? = nil, image: KitoFeedPhoto? = nil) {
        self.url = url
        self.title = title
        self.summary = summary
        self.siteName = siteName
        self.image = image
    }

    /// The site name, or the URL's host without "www.".
    public var displaySite: String {
        if let siteName, !siteName.isEmpty { return siteName }
        let host = url.host() ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

/// One choice in a poll.
public struct KitoFeedPollOption: Identifiable, Hashable, Sendable {
    public var id: String
    public var text: String
    public var votes: Int

    public init(id: String = UUID().uuidString, text: String, votes: Int = 0) {
        self.id = id
        self.text = text
        self.votes = votes
    }
}

/// A poll attached to a post.
public struct KitoFeedPoll: Identifiable, Hashable, Sendable {
    public var id: String
    public var options: [KitoFeedPollOption]
    public var endsAt: Date
    /// The option the current user picked, if any.
    public var votedOptionID: String?

    public init(id: String = UUID().uuidString, options: [KitoFeedPollOption], endsAt: Date, votedOptionID: String? = nil) {
        self.id = id
        self.options = options
        self.endsAt = endsAt
        self.votedOptionID = votedOptionID
    }

    public var totalVotes: Int { options.reduce(0) { $0 + max(0, $1.votes) } }
    public func isClosed(at now: Date = .now) -> Bool { now >= endsAt }
    /// Results show once you've voted or the poll has closed.
    public func showsResults(at now: Date = .now) -> Bool { votedOptionID != nil || isClosed(at: now) }
    /// Whole-number percentages, in option order, that add up to exactly 100.
    public var percentages: [Int] { KitoPollMath.percentages(options.map(\.votes)) }

    /// Records a vote for `optionID`. Does nothing after a vote or once the poll has closed.
    @discardableResult
    public mutating func vote(for optionID: String, at now: Date = .now) -> Bool {
        guard votedOptionID == nil, !isClosed(at: now),
              let index = options.firstIndex(where: { $0.id == optionID }) else { return false }
        options[index].votes += 1
        votedOptionID = optionID
        return true
    }
}

/// What a post carries under its text.
public enum KitoFeedMedia: Hashable, Sendable {
    /// One photo, or a grid of two, three or four with "+N" on the last tile beyond that.
    case photos([KitoFeedPhoto])
    case video(KitoFeedVideo)
    case link(KitoFeedLink)
    case poll(KitoFeedPoll)
}

/// A post quoted inside another post.
public struct KitoFeedQuote: Hashable, Sendable {
    public var author: KitoFeedPerson
    public var text: String
    public var date: Date
    public var photo: KitoFeedPhoto?

    public init(author: KitoFeedPerson, text: String, date: Date, photo: KitoFeedPhoto? = nil) {
        self.author = author
        self.text = text
        self.date = date
        self.photo = photo
    }
}

// MARK: - Posts

/// A post in a feed.
///
/// ```swift
/// KitoFeedPost(id: "p1", author: amani, date: .now.addingTimeInterval(-120),
///              text: "Sunrise over the Ngong hills with @wanjiru #nairobi",
///              media: .photos([sunrise]), location: "Ngong Hills", likes: 1_204, comments: 38)
/// ```
public struct KitoFeedPost: Identifiable, Hashable, Sendable {
    public var id: String
    public var author: KitoFeedPerson
    public var date: Date
    /// Plain text. @mentions, #hashtags and links are found and styled automatically.
    public var text: String
    public var media: KitoFeedMedia?
    public var location: String?
    /// A headline, used by the `.news` style.
    public var title: String?
    public var quote: KitoFeedQuote?
    /// Shown as "Amani reposted" above the post.
    public var repostedBy: KitoFeedPerson?
    public var likes: Int
    public var comments: Int
    public var reposts: Int
    public var isLiked: Bool
    public var isReposted: Bool
    public var isBookmarked: Bool
    /// The link shared by the Share button. `nil` uses a plain share action instead.
    public var shareURL: URL?
    /// A few people who liked it, shown as "Liked by Wanjiru and 1,203 others" in the card style.
    public var likedBy: [KitoFeedPerson]

    public init(id: String, author: KitoFeedPerson, date: Date, text: String, media: KitoFeedMedia? = nil,
                location: String? = nil, title: String? = nil, quote: KitoFeedQuote? = nil,
                repostedBy: KitoFeedPerson? = nil, likes: Int = 0, comments: Int = 0, reposts: Int = 0,
                isLiked: Bool = false, isReposted: Bool = false, isBookmarked: Bool = false,
                shareURL: URL? = nil, likedBy: [KitoFeedPerson] = []) {
        self.id = id
        self.author = author
        self.date = date
        self.text = text
        self.media = media
        self.location = location
        self.title = title
        self.quote = quote
        self.repostedBy = repostedBy
        self.likes = likes
        self.comments = comments
        self.reposts = reposts
        self.isLiked = isLiked
        self.isReposted = isReposted
        self.isBookmarked = isBookmarked
        self.shareURL = shareURL
        self.likedBy = likedBy
    }

    /// Flips the like and moves the count with it.
    public mutating func toggleLike() {
        isLiked.toggle()
        likes = max(0, likes + (isLiked ? 1 : -1))
    }

    /// Flips the repost and moves the count with it.
    public mutating func toggleRepost() {
        isReposted.toggle()
        reposts = max(0, reposts + (isReposted ? 1 : -1))
    }

    public var poll: KitoFeedPoll? {
        if case .poll(let poll) = media { return poll }
        return nil
    }
}

// MARK: - Comments

/// A label beside a commenter's name.
public enum KitoFeedAuthorBadge: Hashable, Sendable {
    /// "Author", for the person who wrote the post.
    case author
    case moderator
    case topFan
    case custom(String, systemImage: String?)

    public var title: String {
        switch self {
        case .author: "Author"
        case .moderator: "Moderator"
        case .topFan: "Top fan"
        case .custom(let title, _): title
        }
    }

    public var systemImage: String? {
        switch self {
        case .author: "pencil"
        case .moderator: "shield.fill"
        case .topFan: "star.fill"
        case .custom(_, let image): image
        }
    }
}

/// A comment with its replies nested inside it.
public struct KitoFeedComment: Identifiable, Hashable, Sendable {
    public var id: String
    public var author: KitoFeedPerson
    public var text: String
    public var date: Date
    public var likes: Int
    public var isLiked: Bool
    /// Pinned comments come first and say "Pinned".
    public var isPinned: Bool
    public var badge: KitoFeedAuthorBadge?
    public var replies: [KitoFeedComment]

    public init(id: String = UUID().uuidString, author: KitoFeedPerson, text: String, date: Date = .now, likes: Int = 0,
                isLiked: Bool = false, isPinned: Bool = false, badge: KitoFeedAuthorBadge? = nil,
                replies: [KitoFeedComment] = []) {
        self.id = id
        self.author = author
        self.text = text
        self.date = date
        self.likes = likes
        self.isLiked = isLiked
        self.isPinned = isPinned
        self.badge = badge
        self.replies = replies
    }

    public mutating func toggleLike() {
        isLiked.toggle()
        likes = max(0, likes + (isLiked ? 1 : -1))
    }
}

// MARK: - Menus

/// Choices in a post's overflow menu.
public enum KitoFeedMenuAction: Hashable, Sendable, CaseIterable {
    case notInterested
    case mute
    case report
    case copyLink
}

/// Repost as-is, or quote with your own words.
public enum KitoFeedRepostKind: Hashable, Sendable {
    case repost
    case undoRepost
    case quote
}
