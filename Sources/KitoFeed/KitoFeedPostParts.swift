//
//  KitoFeedPostParts.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// How a `KitoFeedPostView` is drawn.
public enum KitoFeedPostStyle: String, Sendable, CaseIterable, Identifiable {
    /// Avatar in a column beside the post, counts spread across the bottom, like a timeline.
    case social
    /// A raised card with full-width media, a photo-app action row and "Liked by …".
    case card
    /// Just the name, text and small icons, for dense lists and side panels.
    case minimal
    /// Media first, then the source, a headline and a summary, like a news reader.
    case news

    public var id: String { rawValue }
}

/// The name line: name, verified seal, handle and time.
struct KitoFeedNameLine: View {
    let author: KitoFeedPerson
    let date: Date
    var showsHandle = true
    var tint: Color?

    @Environment(\.kitoTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            Text(author.name)
                .font(theme.typography.bodyEmphasized.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface)
                .lineLimit(1)
                .layoutPriority(1)
            if author.isVerified {
                KitoFeedVerifiedBadge(size: 14, tint: tint)
            }
            Group {
                if showsHandle {
                    Text("@\(author.handle)").lineLimit(1)
                }
                Text("·")
                Text(KitoFeedFormat.relativeTime(from: date))
                    .fixedSize()
                    .accessibilityLabel(KitoFeedFormat.spokenRelativeTime(from: date))
            }
            .font(theme.typography.label.weight(.regular))
            .foregroundStyle(theme.colors.onSurface.opacity(0.55))
        }
    }
}

/// The "…" menu on a post.
struct KitoFeedOverflowMenu: View {
    let post: KitoFeedPost
    let onSelect: (KitoFeedMenuAction) -> Void

    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Menu {
            Button("Not interested", systemImage: "eye.slash") { onSelect(.notInterested) }
            Button("Mute @\(post.author.handle)", systemImage: "speaker.slash") { onSelect(.mute) }
            if post.shareURL != nil {
                Button("Copy link", systemImage: "link") { onSelect(.copyLink) }
            }
            Divider()
            Button("Report post", systemImage: "flag", role: .destructive) { onSelect(.report) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.colors.onSurface.opacity(0.55))
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More options")
    }
}

/// What's left of a post after "Not interested", "Mute" or "Report", with Undo.
struct KitoFeedHiddenPost: View {
    let action: KitoFeedMenuAction
    let author: KitoFeedPerson
    let onUndo: () -> Void

    @Environment(\.kitoTheme) private var theme

    private var symbol: String {
        switch action {
        case .mute: "speaker.slash.fill"
        case .report: "flag.fill"
        default: "eye.slash.fill"
        }
    }

    private var title: String {
        switch action {
        case .mute: "You muted @\(author.handle)"
        case .report: "Thanks for letting us know"
        default: "Post hidden"
        }
    }

    private var subtitle: String {
        switch action {
        case .mute: "You won't see their posts in your feed."
        case .report: "We'll review this post. You won't see it again."
        default: "You'll see fewer posts like this."
        }
    }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.colors.onSurface.opacity(0.7))
                .frame(width: 36, height: 36)
                .background(Circle().fill(theme.colors.surfaceMuted))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(theme.typography.bodyEmphasized.weight(.semibold))
                Text(subtitle).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.6))
            }
            .foregroundStyle(theme.colors.onSurface)
            Spacer(minLength: 0)
            if action != .report {
                Button("Undo", action: onUndo)
                    .font(theme.typography.label.weight(.semibold))
                    .foregroundStyle(theme.colors.onSurface)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Capsule().strokeBorder(theme.colors.border, lineWidth: 1))
                    .buttonStyle(KitoFeedPressStyle())
            }
        }
        .padding(theme.spacing.md)
        .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surfaceMuted.opacity(0.6)))
        .accessibilityElement(children: .combine)
    }
}

/// A quoted post, in a bordered box.
public struct KitoFeedQuoteCard: View {
    private let quote: KitoFeedQuote
    @Environment(\.kitoTheme) private var theme

    public init(quote: KitoFeedQuote) {
        self.quote = quote
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack(spacing: 6) {
                KitoFeedAvatar(person: quote.author, size: 20)
                KitoFeedNameLine(author: quote.author, date: quote.date, showsHandle: false)
            }
            HStack(alignment: .top, spacing: theme.spacing.sm) {
                KitoRichText(quote.text, lineLimit: 3, font: theme.typography.label.weight(.regular))
                if let photo = quote.photo {
                    KitoFeedPhotoView(photo: photo)
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radii.sm, style: .continuous))
                }
            }
        }
        .padding(theme.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
            .strokeBorder(theme.colors.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quoted post by \(quote.author.name): \(quote.text)")
    }
}

/// The big heart that pops over a photo on double-tap.
struct KitoFeedHeartPop: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 88, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            .keyframeAnimator(initialValue: KitoFeedPopValue(), trigger: trigger) { view, value in
                view.scaleEffect(value.scale).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    MoveKeyframe(0.2)
                    SpringKeyframe(1.1, duration: 0.25, spring: .bouncy)
                    SpringKeyframe(1, duration: 0.2)
                    CubicKeyframe(1.25, duration: 0.3)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(0)
                    LinearKeyframe(1, duration: 0.1)
                    LinearKeyframe(1, duration: 0.55)
                    LinearKeyframe(0, duration: 0.2)
                }
            }
            .opacity(reduceMotion ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct KitoFeedPopValue {
    var scale: CGFloat = 1
    var opacity: Double = 0
}
