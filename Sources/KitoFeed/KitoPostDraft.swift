//
//  KitoPostDraft.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// Who can see a new post.
public enum KitoPostAudience: String, CaseIterable, Hashable, Sendable, Identifiable {
    case everyone
    case followers
    case closeFriends
    case onlyMe

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .everyone: "Everyone"
        case .followers: "Followers"
        case .closeFriends: "Close friends"
        case .onlyMe: "Only me"
        }
    }

    public var subtitle: String {
        switch self {
        case .everyone: "Anyone on or off the app"
        case .followers: "People who follow you"
        case .closeFriends: "Your close friends list"
        case .onlyMe: "A private note to yourself"
        }
    }

    public var systemImage: String {
        switch self {
        case .everyone: "globe.africa.fill"
        case .followers: "person.2.fill"
        case .closeFriends: "star.circle.fill"
        case .onlyMe: "lock.fill"
        }
    }
}

/// How long a poll runs.
public struct KitoPollDuration: Hashable, Sendable, Identifiable {
    public var title: String
    public var seconds: TimeInterval
    public var id: TimeInterval { seconds }

    public init(_ title: String, seconds: TimeInterval) {
        self.title = title
        self.seconds = seconds
    }
}

/// A poll being written in the composer.
public struct KitoPollDraft: Hashable, Sendable {
    public static let minOptions = 2
    public static let maxOptions = 4
    public static let maxOptionLength = 25

    public var options: [String]
    public var duration: TimeInterval

    public init(options: [String] = ["", ""], duration: TimeInterval = 86_400) {
        self.options = options
        self.duration = duration
    }

    /// Choices offered for how long a poll runs.
    public static let durations: [KitoPollDuration] = [
        KitoPollDuration("1 hour", seconds: 3_600), KitoPollDuration("6 hours", seconds: 21_600),
        KitoPollDuration("1 day", seconds: 86_400), KitoPollDuration("3 days", seconds: 259_200),
        KitoPollDuration("7 days", seconds: 604_800),
    ]

    public var canAddOption: Bool { options.count < Self.maxOptions }

    /// Why the poll can't be posted yet, or `nil` when it's ready.
    public var problem: String? {
        let trimmed = options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let filled = trimmed.filter { !$0.isEmpty }
        if filled.count < Self.minOptions { return "Add at least two choices" }
        if filled.count != trimmed.count { return "Fill in or remove empty choices" }
        if trimmed.contains(where: { $0.count > Self.maxOptionLength }) { return "Keep choices to \(Self.maxOptionLength) characters" }
        if Set(filled.map { $0.lowercased() }).count != filled.count { return "Choices must be different" }
        return nil
    }

    public var isValid: Bool { problem == nil }

    /// The poll to publish, starting now.
    public func makePoll(now: Date = .now) -> KitoFeedPoll {
        let choices = options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return KitoFeedPoll(options: choices.map { KitoFeedPollOption(text: $0) }, endsAt: now.addingTimeInterval(duration))
    }
}

/// What the composer hands back when you tap Post, and the rules for when Post is enabled.
///
/// ```swift
/// var draft = KitoPostDraft(text: "Habari @amani #nairobi")
/// draft.canPost                        // true
/// draft.remaining                      // 258 of 280
/// draft.mentions                       // ["amani"]
/// ```
public struct KitoPostDraft: Hashable, Sendable {
    public var text: String
    /// How many photos are attached.
    public var photoCount: Int
    public var poll: KitoPollDraft?
    public var audience: KitoPostAudience
    public var characterLimit: Int
    public var isPosting: Bool

    public init(text: String = "", photoCount: Int = 0, poll: KitoPollDraft? = nil, audience: KitoPostAudience = .everyone,
                characterLimit: Int = 280, isPosting: Bool = false) {
        self.text = text
        self.photoCount = photoCount
        self.poll = poll
        self.audience = audience
        self.characterLimit = characterLimit
        self.isPosting = isPosting
    }

    public static let maxPhotos = 4

    /// Characters used, counting each emoji or accented letter once.
    public var characterCount: Int { text.count }
    /// Characters left; negative when over the limit.
    public var remaining: Int { characterLimit - characterCount }
    /// 0…1 for the counter ring, past 1 when over.
    public var progress: Double { characterLimit > 0 ? Double(characterCount) / Double(characterLimit) : 0 }
    public var isOverLimit: Bool { remaining < 0 }
    /// The counter shows a number once 20 or fewer characters are left.
    public var showsRemaining: Bool { remaining <= 20 }

    public var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var hasContent: Bool { hasText || photoCount > 0 || poll != nil }

    /// A poll and photos can't go together.
    public var canAttachPhotos: Bool { poll == nil && photoCount < Self.maxPhotos }
    public var canAddPoll: Bool { poll == nil && photoCount == 0 }

    /// Post is enabled with text, photos or a poll, nothing over the limit, a complete poll (with
    /// a question in the text), and not already posting.
    public var canPost: Bool { blocker == nil }

    /// Why Post is disabled, for VoiceOver and a hint under the field; `nil` when it's enabled.
    public var blocker: String? {
        if isPosting { return "Posting…" }
        if !hasContent { return "Write something or add a photo" }
        if isOverLimit { return "\(-remaining) over the limit" }
        if photoCount > Self.maxPhotos { return "Up to \(Self.maxPhotos) photos" }
        if let poll {
            if !hasText { return "Ask a question for your poll" }
            if let problem = poll.problem { return problem }
        }
        return nil
    }

    public var mentions: [String] { KitoRichTextParser.mentions(in: text) }
    public var hashtags: [String] { KitoRichTextParser.hashtags(in: text) }
}
