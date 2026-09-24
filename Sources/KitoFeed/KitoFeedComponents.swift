//
//  KitoFeedComponents.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

// MARK: - Avatar

/// A round avatar: the person's photo, or their initials on a soft gradient.
///
/// ```swift
/// KitoFeedAvatar(person: amani, size: 44)
/// ```
public struct KitoFeedAvatar: View {
    private let person: KitoFeedPerson
    private let size: CGFloat
    private let showsVerified: Bool

    @Environment(\.kitoTheme) private var theme

    public init(person: KitoFeedPerson, size: CGFloat = 40, showsVerified: Bool = false) {
        self.person = person
        self.size = size
        self.showsVerified = showsVerified
    }

    public var body: some View {
        initialsOrImage
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(theme.colors.onSurface.opacity(0.08), lineWidth: 0.5))
            .overlay(alignment: .bottomTrailing) {
                if showsVerified && person.isVerified {
                    KitoFeedVerifiedBadge(size: max(12, size * 0.34))
                        .background(Circle().fill(theme.colors.surface).padding(-1.5))
                        .offset(x: 2, y: 2)
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder private var initialsOrImage: some View {
        if let url = person.avatarURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    initials
                }
            }
        } else {
            initials
        }
    }

    private var initials: some View {
        let base = person.avatarColor ?? KitoFeedPalette.color(for: person.id)
        return ZStack {
            LinearGradient(colors: [base.opacity(0.75), base], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(person.initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
        }
    }
}

/// A small filled check seal shown after verified names.
public struct KitoFeedVerifiedBadge: View {
    private let size: CGFloat
    private let tint: Color?
    @Environment(\.kitoTheme) private var theme

    public init(size: CGFloat = 14, tint: Color? = nil) {
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(.white, tint ?? theme.colors.primary)
            .accessibilityLabel("Verified")
    }
}

enum KitoFeedPalette {
    static let colors: [Color] = [
        Color(red: 0.93, green: 0.42, blue: 0.29), Color(red: 0.20, green: 0.55, blue: 0.89),
        Color(red: 0.36, green: 0.67, blue: 0.42), Color(red: 0.62, green: 0.40, blue: 0.86),
        Color(red: 0.95, green: 0.62, blue: 0.20), Color(red: 0.12, green: 0.62, blue: 0.64),
        Color(red: 0.86, green: 0.33, blue: 0.55), Color(red: 0.42, green: 0.45, blue: 0.85),
    ]

    /// A stable colour for an id (unlike `hashValue`, the same on every launch).
    static func color(for id: String) -> Color {
        let sum = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return colors[sum % colors.count]
    }

    static func gradient(for id: String) -> [Color] {
        let first = color(for: id)
        let second = color(for: id + "·")
        return [first, second]
    }
}

// MARK: - Photo

/// A post photo: loads `url`, or draws the photo's gradient and symbol when there is none.
public struct KitoFeedPhotoView: View {
    private let photo: KitoFeedPhoto
    @Environment(\.kitoTheme) private var theme

    public init(photo: KitoFeedPhoto) {
        self.photo = photo
    }

    public var body: some View {
        Color.clear
            .overlay { artwork }
            .overlay {
                if let url = photo.url {
                    AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill().transition(.opacity)
                        } else {
                            Color.clear
                        }
                    }
                }
            }
            .clipped()
            .accessibilityElement()
            .accessibilityLabel(photo.altText ?? "Photo")
            .accessibilityAddTraits(.isImage)
    }

    private var stops: [Color] {
        photo.colors.count >= 2 ? photo.colors : (photo.colors.first.map { [$0.opacity(0.7), $0] } ?? KitoFeedPalette.gradient(for: photo.id))
    }

    private var artwork: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
                glow(in: proxy.size)
                hills(in: proxy.size)
                if let symbol = photo.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: symbolSize(proxy.size), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                }
            }
        }
    }

    private func symbolSize(_ size: CGSize) -> CGFloat {
        max(18, min(size.width, size.height) * 0.28)
    }

    private func glow(in size: CGSize) -> some View {
        let radius = max(size.width, size.height) * 0.7
        return RadialGradient(colors: [.white.opacity(0.45), .clear], center: .topTrailing, startRadius: 0, endRadius: radius)
    }

    private func hills(in size: CGSize) -> some View {
        KitoFeedHills()
            .fill(.black.opacity(0.14))
            .frame(height: size.height * 0.42)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

/// Two soft rolling hills along the bottom of a generated photo.
struct KitoFeedHills: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.35),
                          control: CGPoint(x: rect.width * 0.25, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25),
                          control: CGPoint(x: rect.width * 0.78, y: rect.minY + rect.height * 0.7))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Shimmer and skeletons

struct KitoFeedShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(colors: [.clear, .white.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: proxy.size.width * 0.6)
                            .offset(x: phase * proxy.size.width * 1.6)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

extension View {
    func kitoFeedShimmer() -> some View { modifier(KitoFeedShimmer()) }
}

/// A shimmering placeholder shaped like a post, for first loads and "loading more".
public struct KitoFeedSkeletonPost: View {
    private let style: KitoFeedPostStyle
    private let showsMedia: Bool
    @Environment(\.kitoTheme) private var theme

    public init(style: KitoFeedPostStyle = .social, showsMedia: Bool = true) {
        self.style = style
        self.showsMedia = showsMedia
    }

    public var body: some View {
        content
            .kitoFeedShimmer()
            .padding(style == .card ? theme.spacing.lg : 0)
            .background {
                if style == .card {
                    RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).fill(theme.colors.surface)
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.md)
            .accessibilityElement()
            .accessibilityLabel("Loading post")
    }

    private var bone: Color { theme.colors.onSurface.opacity(0.09) }

    private var content: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            if style != .minimal {
                Circle().fill(bone).frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                HStack(spacing: theme.spacing.sm) {
                    Capsule().fill(bone).frame(width: 110, height: 11)
                    Capsule().fill(bone).frame(width: 54, height: 11)
                }
                Capsule().fill(bone).frame(height: 10)
                Capsule().fill(bone).frame(width: 190, height: 10)
                if showsMedia {
                    RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(bone)
                        .frame(height: 170)
                        .padding(.top, theme.spacing.xs)
                }
                HStack {
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule().fill(bone).frame(width: 34, height: 10)
                        Spacer()
                    }
                }
                .padding(.top, theme.spacing.xs)
            }
        }
    }
}
