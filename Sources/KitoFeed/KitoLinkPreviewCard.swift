//
//  KitoLinkPreviewCard.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// How a link preview is laid out.
public enum KitoLinkPreviewStyle: Sendable, CaseIterable {
    /// A wide image above the site, title and summary.
    case large
    /// A square thumbnail beside the text, for tighter layouts.
    case compact
}

/// The card shown for a shared link: image, site, title and summary. Tapping opens the link.
///
/// ```swift
/// KitoLinkPreviewCard(link: KitoFeedLink(url: url, title: "Ten hikes near Nairobi",
///                                        summary: "From Karura to the Ngong Hills."))
/// ```
public struct KitoLinkPreviewCard: View {
    private let link: KitoFeedLink
    private let style: KitoLinkPreviewStyle
    private let tint: Color?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.kitoFeedActions) private var actions
    @Environment(\.openURL) private var openURL

    public init(link: KitoFeedLink, style: KitoLinkPreviewStyle = .large, tint: Color? = nil) {
        self.link = link
        self.style = style
        self.tint = tint
    }

    public var body: some View {
        Button(action: open) {
            Group {
                if style == .large { large } else { compact }
            }
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
                .strokeBorder(theme.colors.border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous))
        }
        .buttonStyle(KitoFeedPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Link: \(link.title), \(link.displaySite)")
        .accessibilityAddTraits(.isLink)
    }

    private var photo: KitoFeedPhoto {
        link.image ?? KitoFeedPhoto(id: link.url.absoluteString, symbol: "globe")
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            KitoFeedPhotoView(photo: photo)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            texts(summaryLines: 2)
                .padding(theme.spacing.md)
        }
    }

    private var compact: some View {
        HStack(spacing: theme.spacing.md) {
            KitoFeedPhotoView(photo: photo)
                .frame(width: 84, height: 84)
            texts(summaryLines: 1)
                .padding(.vertical, theme.spacing.sm)
                .padding(.trailing, theme.spacing.md)
        }
    }

    private func texts(summaryLines: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(link.displaySite, systemImage: "link")
                .font(theme.typography.caption)
                .foregroundStyle(tint ?? theme.colors.onSurface.opacity(0.6))
                .lineLimit(1)
            Text(link.title)
                .font(theme.typography.bodyEmphasized.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let summary = link.summary {
                Text(summary)
                    .font(theme.typography.label.weight(.regular))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.65))
                    .lineLimit(summaryLines)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func open() {
        if let onLink = actions.onLink {
            onLink(link.url)
        } else {
            openURL(link.url)
        }
    }
}
