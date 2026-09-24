//
//  KitoFollowButton.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// How big a `KitoFollowButton` is.
public enum KitoFollowButtonSize: Sendable {
    /// For list rows.
    case compact
    /// For profile headers.
    case regular
}

/// A Follow button that morphs into an outlined "Following" with a check, and back.
///
/// ```swift
/// KitoFollowButton(isFollowing: $people[i].isFollowing, name: person.name,
///                  followsYou: person.followsYou)
/// ```
///
/// A filled capsule reads "Follow" (or "Follow back" when they follow you). Tapping it springs
/// into an outlined "Following". Tapping "Following" asks before unfollowing unless
/// `confirmsUnfollow` is false.
public struct KitoFollowButton: View {
    @Binding private var isFollowing: Bool
    private let name: String?
    private let followsYou: Bool
    private let size: KitoFollowButtonSize
    private let confirmsUnfollow: Bool
    private let tint: Color?
    private let onChange: ((Bool) -> Void)?

    @State private var confirming = false
    @State private var pulse = 0
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isFollowing: Binding<Bool>, name: String? = nil, followsYou: Bool = false,
                size: KitoFollowButtonSize = .compact, confirmsUnfollow: Bool = true, tint: Color? = nil,
                onChange: ((Bool) -> Void)? = nil) {
        self._isFollowing = isFollowing
        self.name = name
        self.followsYou = followsYou
        self.size = size
        self.confirmsUnfollow = confirmsUnfollow
        self.tint = tint
        self.onChange = onChange
    }

    private var accent: Color { tint ?? theme.colors.onSurface }
    private var height: CGFloat { size == .compact ? 32 : 40 }
    private var title: String { isFollowing ? "Following" : (followsYou ? "Follow back" : "Follow") }

    public var body: some View {
        Button(action: tap) {
            HStack(spacing: 5) {
                Image(systemName: isFollowing ? "checkmark" : "plus")
                    .font(.system(size: size == .compact ? 11 : 13, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                Text(title)
                    .font(size == .compact ? theme.typography.label.weight(.semibold) : theme.typography.button)
                    .contentTransition(.interpolate)
                    .lineLimit(1)
            }
            .foregroundStyle(isFollowing ? accent : theme.colors.surface)
            .padding(.horizontal, size == .compact ? 14 : 20)
            .frame(height: height)
            .background { capsule }
            .scaleEffect(pulse % 2 == 1 && !reduceMotion ? 1.06 : 1)
            .contentShape(Capsule())
        }
        .buttonStyle(KitoFeedPressStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: isFollowing)
        .accessibilityLabel(isFollowing ? "Following\(name.map { " \($0)" } ?? "")" : "Follow\(name.map { " \($0)" } ?? "")")
        .accessibilityHint(isFollowing ? "Double-tap to unfollow" : "")
        .confirmationDialog(unfollowTitle, isPresented: $confirming, titleVisibility: .visible) {
            Button("Unfollow", role: .destructive) { set(false) }
        }
    }

    private var unfollowTitle: String { name.map { "Unfollow \($0)?" } ?? "Unfollow?" }

    private var capsule: some View {
        ZStack {
            Capsule().fill(accent).opacity(isFollowing ? 0 : 1)
            Capsule().strokeBorder(theme.colors.border, lineWidth: 1.2).opacity(isFollowing ? 1 : 0)
        }
    }

    private func tap() {
        if isFollowing && confirmsUnfollow {
            confirming = true
        } else {
            set(!isFollowing)
        }
    }

    private func set(_ value: Bool) {
        let animation: Animation? = reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 0.62)
        withAnimation(animation) {
            isFollowing = value
            pulse += 1
        }
        if !reduceMotion {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.12)) { pulse += 1 }
        }
        onChange?(value)
    }
}

/// Shrinks a little while pressed.
struct KitoFeedPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
