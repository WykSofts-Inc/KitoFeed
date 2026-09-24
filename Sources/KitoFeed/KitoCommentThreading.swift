//
//  KitoCommentThreading.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// One line of a flattened comment thread.
public struct KitoCommentRow: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case comment(KitoFeedComment)
        /// "View 4 more replies" under `parentID`.
        case moreReplies(parentID: String, count: Int)
        /// "Hide replies" under an expanded `parentID`.
        case hideReplies(parentID: String)
    }

    public var kind: Kind
    /// 0 for top-level comments; replies deeper than the thread's `maxDepth` share the last level.
    public var depth: Int
    /// Ancestor levels whose connector line runs straight through this row.
    public var passThroughLevels: [Int]
    /// Whether the elbow into this row carries on down to a later sibling.
    public var continuesBelow: Bool
    /// Whether a line leaves this row's avatar downward to its visible replies.
    public var hasVisibleReplies: Bool

    public var id: String {
        switch kind {
        case .comment(let comment): comment.id
        case .moreReplies(let parentID, _): "more-" + parentID
        case .hideReplies(let parentID): "hide-" + parentID
        }
    }

    public var comment: KitoFeedComment? {
        if case .comment(let comment) = kind { return comment }
        return nil
    }
}

/// Pure functions behind `KitoCommentThread`: flatten nested comments into rows with connector
/// lines and "View N more replies", and edit the tree.
///
/// ```swift
/// let rows = KitoCommentThreading.rows(for: comments, expanded: expandedIDs, previewReplies: 1)
/// KitoCommentThreading.insert(reply, under: parent.id, in: &comments)
/// ```
public enum KitoCommentThreading {
    /// Pinned comments first, keeping everything else in its order.
    public static func pinnedFirst(_ comments: [KitoFeedComment]) -> [KitoFeedComment] {
        comments.filter(\.isPinned) + comments.filter { !$0.isPinned }
    }

    /// Every comment and reply, counted.
    public static func totalCount(_ comments: [KitoFeedComment]) -> Int {
        comments.reduce(0) { $0 + 1 + totalCount($1.replies) }
    }

    /// Flattens the thread for display.
    ///
    /// - Parameters:
    ///   - expanded: Comments whose replies are all shown. Others show `previewReplies` replies and
    ///     a "View N more replies" row.
    ///   - collapsed: Comments whose replies are hidden entirely (a "View N replies" row remains).
    ///   - previewReplies: How many replies show before "View more".
    ///   - maxDepth: Deepest indent. Deeper replies stay at this level.
    public static func rows(for comments: [KitoFeedComment], expanded: Set<String> = [], collapsed: Set<String> = [],
                            previewReplies: Int = 1, maxDepth: Int = 2) -> [KitoCommentRow] {
        let options = Options(expanded: expanded, collapsed: collapsed,
                              preview: max(0, previewReplies), maxDepth: max(0, maxDepth))
        var items: [(kind: KitoCommentRow.Kind, depth: Int)] = []
        flatten(pinnedFirst(comments), depth: 0, options: options, into: &items)
        return connect(items)
    }

    private struct Options {
        let expanded: Set<String>
        let collapsed: Set<String>
        let preview: Int
        let maxDepth: Int
    }

    private static func flatten(_ siblings: [KitoFeedComment], depth: Int, options: Options,
                                into items: inout [(kind: KitoCommentRow.Kind, depth: Int)]) {
        for comment in siblings {
            items.append((.comment(comment), depth))
            let childDepth = min(depth + 1, options.maxDepth)
            let visible = visibleReplies(of: comment, options: options)
            flatten(visible, depth: childDepth, options: options, into: &items)
            let hidden = comment.replies.count - visible.count
            if hidden > 0 {
                items.append((.moreReplies(parentID: comment.id, count: hidden), childDepth))
            } else if options.expanded.contains(comment.id), comment.replies.count > options.preview {
                items.append((.hideReplies(parentID: comment.id), childDepth))
            }
        }
    }

    /// Works out connector lines from the depths alone, scanning from the bottom. `open[k]` says
    /// whether a row at depth `k + 1` follows before anything at depth `k` or shallower, which is
    /// exactly when the line at level `k` must keep going.
    private static func connect(_ items: [(kind: KitoCommentRow.Kind, depth: Int)]) -> [KitoCommentRow] {
        let deepest = (items.map(\.depth).max() ?? 0) + 1
        var open = Array(repeating: false, count: deepest)
        var rows: [KitoCommentRow] = []
        rows.reserveCapacity(items.count)
        for index in items.indices.reversed() {
            let depth = items[index].depth
            let next = index + 1 < items.count ? items[index + 1].depth : -1
            var isComment = false
            if case .comment = items[index].kind { isComment = true }
            let pass = depth > 1 ? (0..<(depth - 1)).filter { open[$0] } : []
            rows.append(KitoCommentRow(kind: items[index].kind, depth: depth, passThroughLevels: pass,
                                       continuesBelow: depth > 0 && open[depth - 1],
                                       hasVisibleReplies: isComment && next == depth + 1))
            for level in depth..<deepest { open[level] = false }
            if depth > 0 { open[depth - 1] = true }
        }
        return rows.reversed()
    }

    private static func visibleReplies(of comment: KitoFeedComment, options: Options) -> [KitoFeedComment] {
        if options.collapsed.contains(comment.id) { return [] }
        if options.expanded.contains(comment.id) { return comment.replies }
        return Array(comment.replies.prefix(options.preview))
    }

    // MARK: Editing

    /// Adds `reply` at the end of the replies to `parentID` (at any depth), or at the top level
    /// when `parentID` is `nil`. Returns `false` if the parent wasn't found.
    @discardableResult
    public static func insert(_ reply: KitoFeedComment, under parentID: String?, in comments: inout [KitoFeedComment]) -> Bool {
        guard let parentID else { comments.append(reply); return true }
        for index in comments.indices {
            if comments[index].id == parentID {
                comments[index].replies.append(reply)
                return true
            }
            if insert(reply, under: parentID, in: &comments[index].replies) { return true }
        }
        return false
    }

    /// Changes the comment with `id` (at any depth). Returns `false` if it wasn't found.
    @discardableResult
    public static func update(_ id: String, in comments: inout [KitoFeedComment], _ change: (inout KitoFeedComment) -> Void) -> Bool {
        for index in comments.indices {
            if comments[index].id == id {
                change(&comments[index])
                return true
            }
            if update(id, in: &comments[index].replies, change) { return true }
        }
        return false
    }

    /// The comment with `id`, at any depth.
    public static func find(_ id: String, in comments: [KitoFeedComment]) -> KitoFeedComment? {
        for comment in comments {
            if comment.id == id { return comment }
            if let found = find(id, in: comment.replies) { return found }
        }
        return nil
    }

    /// The top-level comment that `id` sits under (itself if it's top-level).
    public static func root(of id: String, in comments: [KitoFeedComment]) -> KitoFeedComment? {
        comments.first { $0.id == id || find(id, in: $0.replies) != nil }
    }
}
