//
//  KitoFeedLikeButton.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A heart that bursts when liked, with a count that rolls to its new value.
///
/// ```swift
/// KitoFeedLikeButton(isLiked: $post.isLiked, count: $post.likes)
/// ```
public struct KitoFeedLikeButton: View {
    @Binding private var isLiked: Bool
    @Binding private var count: Int
    private let showsCount: Bool
    private let size: CGFloat
    private let tint: Color?
    private let onChange: ((Bool) -> Void)?

    @State private var burstTrigger = 0
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - count: Moves up or down with the like. Pass `.constant(0)` with `showsCount: false` for none.
    ///   - tint: The liked colour. Defaults to the theme's `danger` (red).
    public init(isLiked: Binding<Bool>, count: Binding<Int>, showsCount: Bool = true, size: CGFloat = 19,
                tint: Color? = nil, onChange: ((Bool) -> Void)? = nil) {
        self._isLiked = isLiked
        self._count = count
        self.showsCount = showsCount
        self.size = size
        self.tint = tint
        self.onChange = onChange
    }

    private var liked: Color { tint ?? theme.colors.danger }
    private var idle: Color { theme.colors.onSurface.opacity(0.62) }

    public var body: some View {
        Button(action: toggle) {
            HStack(spacing: 5) {
                heart
                if showsCount {
                    KitoFeedRollingCount(count: count)
                        .foregroundStyle(isLiked ? liked : idle)
                }
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isLiked) { _, new in new }
        .accessibilityLabel(isLiked ? "Unlike" : "Like")
        .accessibilityValue("\(KitoFeedFormat.fullCount(count)) likes")
    }

    private var heart: some View {
        let color = liked
        return ZStack {
            Color.clear
                .keyframeAnimator(initialValue: CGFloat(1), trigger: burstTrigger) { _, progress in
                    KitoFeedBurst(progress: progress, color: color)
                } keyframes: { _ in
                    MoveKeyframe(0)
                    CubicKeyframe(1, duration: 0.6)
                }
                .frame(width: size * 2.6, height: size * 2.6)
                .allowsHitTesting(false)
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(isLiked ? liked : idle)
                .contentTransition(.symbolEffect(.replace))
                .keyframeAnimator(initialValue: CGFloat(1), trigger: burstTrigger) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    MoveKeyframe(1)
                    SpringKeyframe(1.32, duration: 0.14, spring: .snappy)
                    SpringKeyframe(1, duration: 0.36, spring: .bouncy)
                }
        }
        .frame(width: size + 6, height: size + 6)
    }

    private func toggle() {
        let now = !isLiked
        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked = now
            count = max(0, count + (now ? 1 : -1))
        }
        onChange?(now)
        if now && !reduceMotion { burstTrigger += 1 }
    }
}

/// A count that rolls digit by digit and shortens to "1.2K".
struct KitoFeedRollingCount: View {
    let count: Int
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Text(count > 0 ? KitoFeedFormat.compactCount(count) : " ")
            .font(theme.typography.label.monospacedDigit())
            .contentTransition(.numericText(value: Double(count)))
            .frame(minWidth: 14, alignment: .leading)
    }
}

/// A ring and eight dots flying outward. `progress` runs 0 → 1; at 1 everything has faded.
struct KitoFeedBurst: View {
    var progress: CGFloat
    var color: Color

    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2
            ZStack {
                ring(radius: radius)
                ForEach(0..<8, id: \.self) { index in
                    dot(index: index, radius: radius)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .opacity(progress >= 1 ? 0 : 1)
    }

    private func ring(radius: CGFloat) -> some View {
        Circle()
            .strokeBorder(color.opacity(0.6), lineWidth: max(0.5, 5 * (1 - progress)))
            .frame(width: radius * 1.5 * progress, height: radius * 1.5 * progress)
    }

    private func dot(index: Int, radius: CGFloat) -> some View {
        let angle = Double(index) / 8 * 2 * .pi
        let distance = radius * (0.35 + 0.65 * progress)
        let size = max(0, 5 * (1 - progress))
        return Circle()
            .fill(index.isMultiple(of: 2) ? color : color.opacity(0.65))
            .frame(width: size, height: size)
            .offset(x: CGFloat(cos(angle)) * distance, y: CGFloat(sin(angle)) * distance)
    }
}
