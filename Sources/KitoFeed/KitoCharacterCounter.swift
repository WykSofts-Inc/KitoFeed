//
//  KitoCharacterCounter.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A ring that fills as you type, turns amber with a countdown in the last 20 characters, and red
/// with a negative number once you're over.
///
/// ```swift
/// KitoCharacterCounterRing(count: text.count, limit: 280)
/// ```
public struct KitoCharacterCounterRing: View {
    private let count: Int
    private let limit: Int
    private let tint: Color?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(count: Int, limit: Int, tint: Color? = nil) {
        self.count = count
        self.limit = limit
        self.tint = tint
    }

    private var remaining: Int { limit - count }
    private var progress: Double { limit > 0 ? min(1, Double(count) / Double(limit)) : 0 }
    private var showsNumber: Bool { remaining <= 20 }

    private var color: Color {
        if remaining < 0 { return theme.colors.danger }
        if remaining <= 20 { return theme.colors.warning }
        return tint ?? theme.colors.primary
    }

    private var diameter: CGFloat { showsNumber ? 30 : 22 }

    public var body: some View {
        ZStack {
            Circle().stroke(theme.colors.onSurface.opacity(0.12), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsNumber {
                Text("\(remaining)")
                    .font(.system(size: remaining <= -100 ? 9 : 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(remaining < 0 ? theme.colors.danger : theme.colors.onSurface.opacity(0.7))
                    .contentTransition(.numericText(value: Double(remaining)))
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: diameter, height: diameter)
        .opacity(count == 0 ? 0.5 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: count)
        .accessibilityElement()
        .accessibilityLabel("Characters")
        .accessibilityValue(remaining < 0 ? "\(-remaining) over the limit" : "\(remaining) left")
    }
}
