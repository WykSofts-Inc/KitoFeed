//
//  KitoMentionSearch.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// The logic behind @mention autocomplete: find the "@wa" being typed, rank people for it, and
/// swap it for the chosen handle.
///
/// ```swift
/// if let query = KitoMentionSearch.activeQuery(in: text) {                 // "wa"
///     let matches = KitoMentionSearch.filter(people, query: query)          // Wanjiru first
///     text = KitoMentionSearch.complete(text, with: matches[0])             // "… @wanjiru "
/// }
/// ```
public enum KitoMentionSearch {
    /// The partial handle after an "@" at the end of `text`, or `nil` when the last word isn't a
    /// mention being typed. `"Hi @wa"` gives `"wa"`, `"Hi @"` gives `""`, `"hi@wa"` and
    /// `"Hi @wa "` give `nil`.
    public static func activeQuery(in text: String) -> String? {
        guard let at = text.lastIndex(of: "@") else { return nil }
        let partial = text[text.index(after: at)...]
        guard partial.allSatisfy(isHandleCharacter) else { return nil }
        if at > text.startIndex {
            let before = text[text.index(before: at)]
            guard before.isWhitespace || "([{\"'".contains(before) else { return nil }
        }
        return String(partial)
    }

    /// Replaces the mention being typed with "@handle " (keeping everything before it). When no
    /// mention is being typed, appends one, adding a space first if needed.
    public static func complete(_ text: String, with person: KitoFeedPerson) -> String {
        let mention = "@" + person.handle + " "
        if activeQuery(in: text) != nil, let at = text.lastIndex(of: "@") {
            return String(text[..<at]) + mention
        }
        let needsSpace = !(text.isEmpty || text.last?.isWhitespace == true)
        return text + (needsSpace ? " " : "") + mention
    }

    /// People matching `query`, best first, at most `limit`.
    ///
    /// Ranking ignores case and accents: handle starts with the query, then a word of the name
    /// starts with it, then the handle or name contains it. People you follow come first within a
    /// rank, then by name. An empty query lists people you follow first.
    public static func filter(_ people: [KitoFeedPerson], query: String, limit: Int = 6) -> [KitoFeedPerson] {
        let q = fold(query)
        let ranked: [(person: KitoFeedPerson, rank: Int)] = people.compactMap { person in
            rank(person, query: q).map { (person, $0) }
        }
        let sorted = ranked.sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            if lhs.person.isFollowing != rhs.person.isFollowing { return lhs.person.isFollowing }
            return lhs.person.name.localizedCaseInsensitiveCompare(rhs.person.name) == .orderedAscending
        }
        return Array(sorted.prefix(max(0, limit)).map(\.person))
    }

    /// Where the query matched in a name or handle, for bolding in the list (character offsets).
    public static func matchRange(of query: String, in text: String) -> Range<Int>? {
        let q = fold(query)
        guard !q.isEmpty else { return nil }
        let folded = fold(text)
        guard folded.count == text.count, let range = folded.range(of: q) else { return nil }
        let start = folded.distance(from: folded.startIndex, to: range.lowerBound)
        return start..<(start + q.count)
    }

    private static func rank(_ person: KitoFeedPerson, query q: String) -> Int? {
        if q.isEmpty { return 0 }
        let handle = fold(person.handle)
        let name = fold(person.name)
        if handle.hasPrefix(q) { return 0 }
        if name.hasPrefix(q) || name.split(separator: " ").contains(where: { $0.hasPrefix(q) }) { return 1 }
        if handle.contains(q) || name.contains(q) { return 2 }
        return nil
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func isHandleCharacter(_ character: Character) -> Bool {
        character == "_" || character == "." || (character.isLetter && character.isASCII) || (character.isNumber && character.isASCII)
    }
}

/// Decides when the "New posts" pill shows.
///
/// Posts that arrive at the top after the first load count as new until you scroll up to them
/// or tap the pill. Posts you asked for with pull to refresh are shown straight away.
///
/// ```swift
/// var tracker = KitoNewPostsTracker<String>()
/// tracker.update(ids: posts.map(\.id))                  // first load: nothing new
/// tracker.update(ids: newer.map(\.id))                  // 3 new → pill shows "3 new posts"
/// tracker.visibleTopChanged(to: newer.first?.id)        // scrolled up → pill hides
/// ```
public struct KitoNewPostsTracker<ID: Hashable>: Equatable {
    public private(set) var known: Set<ID> = []
    /// New ids, newest first.
    public private(set) var unseen: [ID] = []
    private var hasLoaded = false

    public init() {}

    public var count: Int { unseen.count }
    public var isPillVisible: Bool { !unseen.isEmpty }

    /// "1 new post", "3 new posts", "99+ new posts".
    public var pillTitle: String {
        count == 1 ? "1 new post" : (count > 99 ? "99+ new posts" : "\(count) new posts")
    }

    /// Call with the feed's ids, top first, whenever they change. New ids at the top become unseen
    /// unless `reveal` is true (pull to refresh) or this is the first load. Ids that disappear are
    /// forgotten. Older posts added at the bottom are never "new".
    public mutating func update(ids: [ID], reveal: Bool = false) {
        let current = Set(ids)
        unseen.removeAll { !current.contains($0) }
        guard hasLoaded else {
            hasLoaded = !ids.isEmpty
            known = current
            return
        }
        let fresh = Array(ids.prefix { !known.contains($0) })
        if reveal {
            unseen.removeAll()
        } else if !fresh.isEmpty {
            unseen = fresh + unseen.filter { !fresh.contains($0) }
        }
        known = current
    }

    /// Call when the post at the top of the screen changes. Reaching any new post, or the top of
    /// the list (`nil`), hides the pill.
    public mutating func visibleTopChanged(to id: ID?) {
        guard let id else { unseen.removeAll(); return }
        if unseen.contains(id) { unseen.removeAll() }
    }

    /// Call when the pill is tapped (then scroll to the top).
    public mutating func acknowledge() { unseen.removeAll() }
}
