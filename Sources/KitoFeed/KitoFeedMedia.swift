//
//  KitoFeedMedia.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Photos laid out the way feeds do: one on its own, two side by side, one large with two
/// stacked, a 2×2 grid, and "+N" on the fourth tile when there are more.
///
/// ```swift
/// KitoFeedPhotoGrid(photos: photos) { index in openViewer(at: index) }
/// ```
public struct KitoFeedPhotoGrid: View {
    private let photos: [KitoFeedPhoto]
    private let cornerRadius: CGFloat?
    private let onTap: ((Int) -> Void)?

    @Environment(\.kitoTheme) private var theme

    public init(photos: [KitoFeedPhoto], cornerRadius: CGFloat? = nil, onTap: ((Int) -> Void)? = nil) {
        self.photos = photos
        self.cornerRadius = cornerRadius
        self.onTap = onTap
    }

    private var gap: CGFloat { 3 }
    private var radius: CGFloat { cornerRadius ?? theme.radii.lg }

    /// Width over height for the whole grid.
    static func aspectRatio(for photos: [KitoFeedPhoto]) -> CGFloat {
        switch photos.count {
        case 0: 1
        case 1: min(1.9, max(0.8, photos[0].aspectRatio ?? 1.33))
        case 2: 1.6
        case 3: 1.4
        default: 1.25
        }
    }

    /// The "+N" shown on the fourth tile, or `nil`.
    static func overflow(for count: Int) -> Int? { count > 4 ? count - 3 : nil }

    public var body: some View {
        if !photos.isEmpty {
            Color.clear
                .aspectRatio(Self.aspectRatio(for: photos), contentMode: .fit)
                .overlay { layout }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(theme.colors.onSurface.opacity(0.06), lineWidth: 0.5))
                .accessibilityElement(children: .contain)
                .accessibilityLabel(photos.count == 1 ? "Photo" : "\(photos.count) photos")
        }
    }

    @ViewBuilder private var layout: some View {
        switch photos.count {
        case 1:
            tile(0)
        case 2:
            HStack(spacing: gap) { tile(0); tile(1) }
        case 3:
            HStack(spacing: gap) {
                tile(0)
                VStack(spacing: gap) { tile(1); tile(2) }
            }
        default:
            VStack(spacing: gap) {
                HStack(spacing: gap) { tile(0); tile(1) }
                HStack(spacing: gap) { tile(2); tile(3) }
            }
        }
    }

    @ViewBuilder private func tile(_ index: Int) -> some View {
        if let onTap {
            Button { onTap(index) } label: { tileContent(index) }
                .buttonStyle(.plain)
                .accessibilityLabel(tileLabel(index))
        } else {
            tileContent(index)
                .accessibilityLabel(tileLabel(index))
        }
    }

    private func tileContent(_ index: Int) -> some View {
        KitoFeedPhotoView(photo: photos[index])
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { if index == 3, let more = Self.overflow(for: photos.count) { moreOverlay(more) } }
            .contentShape(Rectangle())
    }

    private func tileLabel(_ index: Int) -> String {
        let alt = photos[index].altText ?? "Photo \(index + 1) of \(photos.count)"
        if index == 3, let more = Self.overflow(for: photos.count) { return alt + ", and \(more) more" }
        return alt
    }

    private func moreOverlay(_ more: Int) -> some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.45))
            Text("+\(more)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

/// A video's poster with a play button, the running time and optional view count.
public struct KitoFeedVideoPoster: View {
    private let video: KitoFeedVideo
    private let cornerRadius: CGFloat?
    private let onPlay: (() -> Void)?

    @Environment(\.kitoTheme) private var theme

    public init(video: KitoFeedVideo, cornerRadius: CGFloat? = nil, onPlay: (() -> Void)? = nil) {
        self.video = video
        self.cornerRadius = cornerRadius
        self.onPlay = onPlay
    }

    private var radius: CGFloat { cornerRadius ?? theme.radii.lg }
    private var ratio: CGFloat { min(1.9, max(0.8, video.poster.aspectRatio ?? 16.0 / 9.0)) }

    public var body: some View {
        Button { onPlay?() } label: {
            Color.clear
                .aspectRatio(ratio, contentMode: .fit)
                .overlay { KitoFeedPhotoView(photo: video.poster) }
                .overlay { LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom) }
                .overlay { playButton }
                .overlay(alignment: .bottomLeading) { badges }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(KitoFeedPressStyle())
        .accessibilityLabel("Video, \(KitoFeedFormat.duration(video.duration))")
        .accessibilityHint("Plays the video")
    }

    private var playButton: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .offset(x: 2)
            .frame(width: 58, height: 58)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    private var badges: some View {
        HStack(spacing: 6) {
            Text(KitoFeedFormat.duration(video.duration))
            if let views = video.viewCount {
                Text("·")
                Text("\(KitoFeedFormat.compactCount(views)) views")
            }
        }
        .font(theme.typography.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.45), in: Capsule())
        .padding(theme.spacing.sm)
    }
}
