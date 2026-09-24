//
//  KitoPollView.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A poll: tap a choice to vote, then bars grow to each choice's share with the percentages
/// counting up. Shows "1,204 votes · 2h left", and results once the poll has closed.
///
/// ```swift
/// KitoPollView(poll: $post.poll) { option in api.vote(option.id) }
/// ```
public struct KitoPollView: View {
    @Binding private var poll: KitoFeedPoll
    private let tint: Color?
    private let onVote: ((KitoFeedPollOption) -> Void)?

    @State private var revealed = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(poll: Binding<KitoFeedPoll>, tint: Color? = nil, onVote: ((KitoFeedPollOption) -> Void)? = nil) {
        self._poll = poll
        self.tint = tint
        self.onVote = onVote
    }

    private var accent: Color { tint ?? theme.colors.primary }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
    }

    private func content(now: Date) -> some View {
        let showsResults = poll.showsResults(at: now)
        let percentages = poll.percentages
        let leaders = KitoPollMath.leaders(poll.options.map(\.votes))
        return VStack(alignment: .leading, spacing: theme.spacing.sm) {
            ForEach(Array(poll.options.enumerated()), id: \.element.id) { index, option in
                if showsResults {
                    resultRow(option, percent: percentages[index], isLeader: leaders.contains(index), index: index)
                } else {
                    voteButton(option, now: now)
                }
            }
            footer(now: now)
        }
        .onAppear { if showsResults { reveal(animated: false) } }
        .onChange(of: showsResults) { _, shows in if shows { reveal(animated: true) } }
    }

    private func voteButton(_ option: KitoFeedPollOption, now: Date) -> some View {
        Button {
            vote(option, now: now)
        } label: {
            Text(option.text)
                .font(theme.typography.bodyEmphasized)
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 40)
                .background(Capsule().fill(accent.opacity(0.06)))
                .overlay(Capsule().strokeBorder(accent.opacity(0.55), lineWidth: 1.2))
                .contentShape(Capsule())
        }
        .buttonStyle(KitoFeedPressStyle())
        .accessibilityHint("Votes for this choice")
    }

    private func resultRow(_ option: KitoFeedPollOption, percent: Int, isLeader: Bool, index: Int) -> some View {
        let isMine = poll.votedOptionID == option.id
        let shown = revealed ? percent : 0
        return HStack(spacing: theme.spacing.sm) {
            Text(option.text)
                .font(isLeader ? theme.typography.bodyEmphasized.weight(.semibold) : theme.typography.body)
                .foregroundStyle(theme.colors.onSurface)
                .lineLimit(1)
            if isMine {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer(minLength: theme.spacing.sm)
            Text("\(shown)%")
                .font(theme.typography.label.weight(isLeader ? .bold : .medium).monospacedDigit())
                .foregroundStyle(theme.colors.onSurface)
                .contentTransition(.numericText(value: Double(shown)))
        }
        .padding(.horizontal, theme.spacing.md)
        .frame(minHeight: 40)
        .background(alignment: .leading) { bar(percent: shown, isLeader: isLeader, index: index) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(option.text), \(percent) percent\(isMine ? ", your vote" : "")")
    }

    private func bar(percent: Int, isLeader: Bool, index: Int) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: theme.radii.md, style: .continuous)
                    .fill(theme.colors.surfaceMuted)
                RoundedRectangle(cornerRadius: theme.radii.md, style: .continuous)
                    .fill(barFill(isLeader: isLeader))
                    .frame(width: barWidth(percent: percent, in: proxy.size.width))
            }
        }
    }

    private func barFill(isLeader: Bool) -> LinearGradient {
        let strength = isLeader ? 0.32 : 0.14
        return LinearGradient(colors: [accent.opacity(strength), accent.opacity(strength * 0.7)],
                              startPoint: .leading, endPoint: .trailing)
    }

    private func barWidth(percent: Int, in width: CGFloat) -> CGFloat {
        guard percent > 0 else { return 0 }
        return max(8, width * CGFloat(percent) / 100)
    }

    private func footer(now: Date) -> some View {
        let votes = poll.totalVotes
        let label = votes == 1 ? "1 vote" : "\(KitoFeedFormat.fullCount(votes)) votes"
        return HStack(spacing: 6) {
            Text(label).contentTransition(.numericText(value: Double(votes)))
            Text("·")
            Text(KitoFeedFormat.timeLeft(until: poll.endsAt, now: now))
        }
        .font(theme.typography.caption)
        .foregroundStyle(theme.colors.onSurface.opacity(0.6))
        .padding(.top, 2)
    }

    private func vote(_ option: KitoFeedPollOption, now: Date) {
        var updated = poll
        guard updated.vote(for: option.id, at: now) else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
            poll = updated
        }
        onVote?(option)
    }

    private func reveal(animated: Bool) {
        guard !revealed else { return }
        if animated && !reduceMotion {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.05)) { revealed = true }
        } else {
            revealed = true
        }
    }
}
