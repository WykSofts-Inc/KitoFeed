//
//  KitoCommentThread.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Comments with nested replies joined by connector lines, "View 4 more replies", likes,
/// Reply and pinned comments first.
///
/// ```swift
/// KitoCommentThread(comments: $comments, onReply: { comment in
///     draft = "@\(comment.author.handle) "      // or use KitoCommentsView, which does this for you
/// })
/// ```
public struct KitoCommentThread: View {
    @Binding private var comments: [KitoFeedComment]
    private let previewReplies: Int
    private let maxDepth: Int
    private let tint: Color?
    private let externalExpanded: Binding<Set<String>>?
    private let onReply: ((KitoFeedComment) -> Void)?
    private let onLike: ((KitoFeedComment) -> Void)?

    @State private var localExpanded: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - previewReplies: Replies shown under each comment before "View N more replies".
    ///   - maxDepth: How far replies indent. Replies to deeper replies line up at this level.
    ///   - expanded: Comments showing all their replies, if you want to control it.
    ///   - onReply: Reply was tapped.
    ///   - onLike: A comment's heart was tapped (after the like is already shown).
    public init(comments: Binding<[KitoFeedComment]>, previewReplies: Int = 1, maxDepth: Int = 2, tint: Color? = nil,
                expanded: Binding<Set<String>>? = nil, onReply: ((KitoFeedComment) -> Void)? = nil,
                onLike: ((KitoFeedComment) -> Void)? = nil) {
        self._comments = comments
        self.previewReplies = previewReplies
        self.maxDepth = maxDepth
        self.tint = tint
        self.externalExpanded = expanded
        self.onReply = onReply
        self.onLike = onLike
    }

    private var expanded: Binding<Set<String>> { externalExpanded ?? $localExpanded }

    private var rows: [KitoCommentRow] {
        KitoCommentThreading.rows(for: comments, expanded: expanded.wrappedValue,
                                  previewReplies: previewReplies, maxDepth: maxDepth)
    }

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                rowView(row)
                    .id(row.id)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder private func rowView(_ row: KitoCommentRow) -> some View {
        switch row.kind {
        case .comment(let comment):
            KitoCommentRowView(comment: comment, row: row, tint: tint,
                               onReply: { onReply?(comment) },
                               onLike: { like(comment) })
        case .moreReplies(let parentID, let count):
            KitoCommentToggleRow(row: row, title: count == 1 ? "View 1 more reply" : "View \(count) more replies") {
                setExpanded(parentID, true)
            }
        case .hideReplies(let parentID):
            KitoCommentToggleRow(row: row, title: "Hide replies") { setExpanded(parentID, false) }
        }
    }

    private func setExpanded(_ id: String, _ isExpanded: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86)) {
            if isExpanded { expanded.wrappedValue.insert(id) } else { expanded.wrappedValue.remove(id) }
        }
    }

    private func like(_ comment: KitoFeedComment) {
        var liked = comment
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6)) {
            _ = KitoCommentThreading.update(comment.id, in: &comments) { $0.toggleLike(); liked = $0 }
        }
        onLike?(liked)
    }
}

// MARK: - Metrics and connectors

enum KitoCommentMetrics {
    static let step: CGFloat = 44
    static let top: CGFloat = 10
    static func avatar(_ depth: Int) -> CGFloat { depth == 0 ? 36 : 28 }
    /// The x of the line that leaves a depth's avatar.
    static func lineX(_ depth: Int) -> CGFloat { CGFloat(depth) * step + avatar(depth) / 2 }
    static func indent(_ depth: Int) -> CGFloat { CGFloat(depth) * step }
}

/// The lines drawn behind one row: straight lines for ancestors, an elbow into this row, and a
/// stem down to its replies.
struct KitoCommentConnector: Shape {
    let row: KitoCommentRow
    /// Where the elbow meets the row, from the top.
    let targetY: CGFloat
    /// Where the stem starts, from the top.
    let stemY: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for level in row.passThroughLevels {
            vertical(&path, x: KitoCommentMetrics.lineX(level), from: rect.minY, to: rect.maxY)
        }
        if row.depth > 0 { elbow(&path, in: rect) }
        if row.hasVisibleReplies {
            vertical(&path, x: KitoCommentMetrics.lineX(row.depth), from: rect.minY + stemY, to: rect.maxY)
        }
        return path
    }

    private func elbow(_ path: inout Path, in rect: CGRect) {
        let x = KitoCommentMetrics.lineX(row.depth - 1)
        let endX = KitoCommentMetrics.indent(row.depth) - 4
        let y = rect.minY + targetY
        let radius = min(12, max(0, endX - x))
        path.move(to: CGPoint(x: x, y: rect.minY))
        path.addLine(to: CGPoint(x: x, y: y - radius))
        path.addQuadCurve(to: CGPoint(x: x + radius, y: y), control: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: endX, y: y))
        if row.continuesBelow {
            vertical(&path, x: x, from: y - radius, to: rect.maxY)
        }
    }

    private func vertical(_ path: inout Path, x: CGFloat, from top: CGFloat, to bottom: CGFloat) {
        guard bottom > top else { return }
        path.move(to: CGPoint(x: x, y: top))
        path.addLine(to: CGPoint(x: x, y: bottom))
    }
}

// MARK: - Rows

struct KitoCommentRowView: View {
    let comment: KitoFeedComment
    let row: KitoCommentRow
    let tint: Color?
    let onReply: () -> Void
    let onLike: () -> Void

    @Environment(\.kitoTheme) private var theme
    @Environment(\.kitoFeedActions) private var actions

    private var size: CGFloat { KitoCommentMetrics.avatar(row.depth) }
    private var muted: Color { theme.colors.onSurface.opacity(0.55) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button { actions.onAuthor?(comment.author) } label: {
                KitoFeedAvatar(person: comment.author, size: size)
            }
            .buttonStyle(KitoFeedPressStyle())
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if comment.isPinned { pinnedLabel }
                header
                KitoRichText(comment.text, lineLimit: 6, font: theme.typography.label.weight(.regular), tint: tint)
                footer
            }
            Spacer(minLength: 0)
            likeColumn
        }
        .padding(.leading, KitoCommentMetrics.indent(row.depth))
        .padding(.trailing, theme.spacing.lg)
        .padding(.vertical, KitoCommentMetrics.top)
        .background(alignment: .topLeading) { connector }
        .padding(.leading, theme.spacing.lg)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Reply", systemImage: "arrowshape.turn.up.backward", action: onReply)
            Button("Copy text", systemImage: "doc.on.doc") { UIPasteboard.general.string = comment.text }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAction(named: "Reply", onReply)
        .accessibilityAction(named: comment.isLiked ? "Unlike" : "Like", onLike)
    }

    private var connector: some View {
        KitoCommentConnector(row: row, targetY: KitoCommentMetrics.top + size / 2,
                             stemY: KitoCommentMetrics.top + size + 4)
            .stroke(theme.colors.border, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    }

    private var pinnedLabel: some View {
        Label("Pinned", systemImage: "pin.fill")
            .font(theme.typography.caption.weight(.semibold))
            .foregroundStyle(muted)
            .frame(height: 16)
    }

    private var header: some View {
        HStack(spacing: 5) {
            Text(comment.author.name)
                .font(theme.typography.label.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface)
                .lineLimit(1)
            if comment.author.isVerified { KitoFeedVerifiedBadge(size: 12, tint: tint) }
            if let badge = comment.badge { KitoCommentBadge(badge: badge, tint: tint) }
            Text(KitoFeedFormat.relativeTime(from: comment.date))
                .font(theme.typography.caption)
                .foregroundStyle(muted)
                .fixedSize()
        }
    }

    private var footer: some View {
        HStack(spacing: theme.spacing.lg) {
            Button("Reply", action: onReply)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(muted)
                .buttonStyle(.plain)
                .frame(minHeight: 24)
            if comment.likes > 0 {
                Text(comment.likes == 1 ? "1 like" : "\(KitoFeedFormat.compactCount(comment.likes)) likes")
                    .font(theme.typography.caption)
                    .foregroundStyle(muted)
                    .contentTransition(.numericText(value: Double(comment.likes)))
            }
        }
    }

    private var likeColumn: some View {
        KitoFeedLikeButton(isLiked: .constant(comment.isLiked), count: .constant(comment.likes), showsCount: false,
                           size: 14, tint: tint) { _ in onLike() }
            .padding(.top, comment.isPinned ? 20 : 4)
    }

    private var accessibilityText: String {
        var parts = [comment.author.name]
        if comment.isPinned { parts.insert("Pinned", at: 0) }
        if let badge = comment.badge { parts.append(badge.title) }
        parts.append(comment.text)
        parts.append(KitoFeedFormat.spokenRelativeTime(from: comment.date))
        if comment.likes > 0 { parts.append("\(comment.likes) likes") }
        return parts.joined(separator: ", ")
    }
}

struct KitoCommentBadge: View {
    let badge: KitoFeedAuthorBadge
    let tint: Color?
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        let color = tint ?? theme.colors.primary
        HStack(spacing: 3) {
            if let symbol = badge.systemImage { Image(systemName: symbol).font(.system(size: 8, weight: .bold)) }
            Text(badge.title)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.12)))
        .fixedSize()
    }
}

struct KitoCommentToggleRow: View {
    let row: KitoCommentRow
    let title: String
    let action: () -> Void
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: title == "Hide replies" ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(theme.typography.caption.weight(.semibold))
            .foregroundStyle(theme.colors.onSurface.opacity(0.6))
            .frame(height: 32)
            .padding(.leading, KitoCommentMetrics.indent(row.depth))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .topLeading) {
                KitoCommentConnector(row: row, targetY: 16, stemY: 32)
                    .stroke(theme.colors.border, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
            .padding(.leading, theme.spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
