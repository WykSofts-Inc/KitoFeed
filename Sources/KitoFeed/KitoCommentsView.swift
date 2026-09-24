//
//  KitoCommentsView.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A full comments screen: the thread above, the composer pinned to the bottom. Reply fills in
/// "@name ", shows "Replying to …" and focuses the field; sending adds the reply under the
/// right comment, opens its replies and scrolls to it.
///
/// ```swift
/// KitoCommentsView(comments: $comments, currentUser: me, people: followers) { comment, parentID in
///     try? await api.addComment(comment, replyingTo: parentID)
/// }
/// ```
public struct KitoCommentsView<Header: View>: View {
    @Binding private var comments: [KitoFeedComment]
    private let currentUser: KitoFeedPerson
    private let people: [KitoFeedPerson]
    private let previewReplies: Int
    private let tint: Color?
    private let onSend: ((KitoFeedComment, String?) -> Void)?
    private let header: Header

    @State private var draft = ""
    @State private var replyTarget: KitoFeedComment?
    @State private var expanded: Set<String> = []
    @State private var composerFocused = false
    @State private var scrollTarget: String?
    @Environment(\.kitoTheme) private var theme

    /// - Parameters:
    ///   - currentUser: Author of new comments, shown beside the field.
    ///   - people: Who can be @mentioned. Commenters are added automatically.
    ///   - onSend: The new comment and the id of the comment it replies to (`nil` at the top level).
    ///   - header: Shown above the comments, e.g. the post.
    public init(comments: Binding<[KitoFeedComment]>, currentUser: KitoFeedPerson, people: [KitoFeedPerson] = [],
                previewReplies: Int = 1, tint: Color? = nil,
                onSend: ((KitoFeedComment, String?) -> Void)? = nil,
                @ViewBuilder header: () -> Header) {
        self._comments = comments
        self.currentUser = currentUser
        self.people = people
        self.previewReplies = previewReplies
        self.tint = tint
        self.onSend = onSend
        self.header = header()
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    countLine
                    KitoCommentThread(comments: $comments, previewReplies: previewReplies, tint: tint,
                                      expanded: $expanded, onReply: startReply)
                }
                .padding(.bottom, theme.spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: scrollTarget) { _, id in
                guard let id else { return }
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .background(theme.colors.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            KitoCommentComposer(text: $draft, author: currentUser, people: mentionable, replyingTo: replyTarget?.author,
                                tint: tint, isFocused: $composerFocused,
                                onCancelReply: cancelReply, onSend: send)
        }
    }

    private var countLine: some View {
        let count = KitoCommentThreading.totalCount(comments)
        return Text(count == 1 ? "1 comment" : "\(KitoFeedFormat.fullCount(count)) comments")
            .font(theme.typography.label.weight(.semibold))
            .foregroundStyle(theme.colors.onSurface.opacity(0.6))
            .contentTransition(.numericText(value: Double(count)))
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.sm)
    }

    /// Given people plus everyone in the thread, without repeats or the current user.
    private var mentionable: [KitoFeedPerson] {
        var seen: Set<String> = [currentUser.id]
        var result: [KitoFeedPerson] = []
        for person in people + commenters(comments) where seen.insert(person.id).inserted {
            result.append(person)
        }
        return result
    }

    private func commenters(_ list: [KitoFeedComment]) -> [KitoFeedPerson] {
        list.flatMap { [$0.author] + commenters($0.replies) }
    }

    private func startReply(_ comment: KitoFeedComment) {
        replyTarget = comment
        let mention = "@" + comment.author.handle + " "
        if comment.author.id != currentUser.id && !draft.hasPrefix(mention) {
            draft = mention + draft
        }
        composerFocused = true
    }

    private func cancelReply() {
        if let target = replyTarget, draft.hasPrefix("@" + target.author.handle + " ") {
            draft.removeFirst(target.author.handle.count + 2)
        }
        replyTarget = nil
    }

    private func send(_ text: String) {
        let comment = KitoFeedComment(author: currentUser, text: text, date: .now)
        let parentID = replyTarget?.id
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            KitoCommentThreading.insert(comment, under: parentID, in: &comments)
            if let parentID { expanded.insert(parentID) }
        }
        onSend?(comment, parentID)
        draft = ""
        replyTarget = nil
        scrollTarget = comment.id
    }
}

public extension KitoCommentsView where Header == EmptyView {
    init(comments: Binding<[KitoFeedComment]>, currentUser: KitoFeedPerson, people: [KitoFeedPerson] = [],
         previewReplies: Int = 1, tint: Color? = nil, onSend: ((KitoFeedComment, String?) -> Void)? = nil) {
        self.init(comments: comments, currentUser: currentUser, people: people, previewReplies: previewReplies,
                  tint: tint, onSend: onSend) { EmptyView() }
    }
}
