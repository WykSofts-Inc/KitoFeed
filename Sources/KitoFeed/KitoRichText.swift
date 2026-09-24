//
//  KitoRichText.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Post text with tappable @mentions, #hashtags and links, and "Read more" when it runs long.
///
/// ```swift
/// KitoRichText("Sunset at @karura_trails 🌅 #nairobi kito.dev/trails", lineLimit: 3,
///              onMention: { openProfile($0) }, onHashtag: { openTag($0) })
/// ```
///
/// Handlers you leave out fall back to `.kitoFeedActions(_:)`; links with no handler open with the
/// system. Long text is cut to `lineLimit` lines with a "Read more" button that expands it in place.
public struct KitoRichText: View {
    private let text: String
    private let lineLimit: Int?
    private let font: Font?
    private let color: Color?
    private let tint: Color?
    private let onMention: ((String) -> Void)?
    private let onHashtag: ((String) -> Void)?
    private let onLink: ((URL) -> Void)?

    @State private var isExpanded = false
    @State private var isTruncated = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.kitoFeedActions) private var actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - text: Plain text; mentions, hashtags and links are found automatically.
    ///   - lineLimit: Lines shown before "Read more". `nil` shows everything.
    ///   - font: Defaults to the theme's body font.
    ///   - color: Colour of plain text. Defaults to the theme's `onSurface`.
    ///   - tint: Colour of mentions, hashtags, links and "Read more". Defaults to the theme's primary.
    public init(_ text: String, lineLimit: Int? = nil, font: Font? = nil, color: Color? = nil, tint: Color? = nil,
                onMention: ((String) -> Void)? = nil, onHashtag: ((String) -> Void)? = nil, onLink: ((URL) -> Void)? = nil) {
        self.text = text
        self.lineLimit = lineLimit
        self.font = font
        self.color = color
        self.tint = tint
        self.onMention = onMention
        self.onHashtag = onHashtag
        self.onLink = onLink
    }

    private var accent: Color { tint ?? theme.colors.primary }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            styledText
                .lineLimit(isExpanded ? nil : lineLimit)
                .background { measurer }
                .onPreferenceChange(KitoRichTextOverflowKey.self) { overflow in
                    isTruncated = overflow > 1
                }
            if lineLimit != nil && (isTruncated || isExpanded) {
                Button(isExpanded ? "Show less" : "Read more", action: toggle)
                    .font(theme.typography.label.weight(.semibold))
                    .foregroundStyle(accent)
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .transition(.opacity)
            }
        }
        .environment(\.openURL, OpenURLAction(handler: open))
    }

    private var styledText: some View {
        Text(KitoRichTextStyler.attributed(text, accent: accent))
            .font(font ?? theme.typography.body)
            .foregroundStyle(color ?? theme.colors.onSurface)
            .tint(accent)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Lays the full text out, invisibly, at the same width to see if the limited one is cut off.
    @ViewBuilder private var measurer: some View {
        if lineLimit != nil && !isExpanded {
            GeometryReader { limited in
                styledText
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .background {
                        GeometryReader { full in
                            Color.clear.preference(key: KitoRichTextOverflowKey.self,
                                                   value: full.size.height - limited.size.height)
                        }
                    }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func toggle() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
            isExpanded.toggle()
        }
    }

    private func open(_ url: URL) -> OpenURLAction.Result {
        switch KitoRichTextStyler.target(of: url) {
        case .mention(let handle):
            (onMention ?? actions.onMention)?(handle)
            return .handled
        case .hashtag(let tag):
            (onHashtag ?? actions.onHashtag)?(tag)
            return .handled
        case .link(let link):
            if let handler = onLink ?? actions.onLink {
                handler(link)
                return .handled
            }
            return .systemAction
        }
    }
}

private struct KitoRichTextOverflowKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Builds the attributed string used by `KitoRichText` and the composer.
enum KitoRichTextStyler {
    enum Target: Equatable {
        case mention(String)
        case hashtag(String)
        case link(URL)
    }

    static let scheme = "kitofeed"

    static func attributed(_ text: String, accent: Color, linksTappable: Bool = true) -> AttributedString {
        var result = AttributedString()
        for token in KitoRichTextParser.tokens(in: text) {
            var piece = AttributedString(token.kind == .link && linksTappable ? displayLink(token.text) : token.text)
            switch token.kind {
            case .text:
                break
            case .mention, .hashtag:
                piece.foregroundColor = accent
                if linksTappable { piece.link = internalURL(token) }
            case .link:
                piece.foregroundColor = accent
                if linksTappable { piece.link = token.url }
            }
            result.append(piece)
        }
        return result
    }

    /// "https://www.kito.dev/feed/a-very-long-path" reads as "kito.dev/feed/a-very-long-pa…".
    static func displayLink(_ raw: String) -> String {
        var shown = raw
        for prefix in ["https://", "http://"] where shown.lowercased().hasPrefix(prefix) {
            shown = String(shown.dropFirst(prefix.count))
        }
        if shown.lowercased().hasPrefix("www.") { shown = String(shown.dropFirst(4)) }
        if shown.hasSuffix("/") { shown.removeLast() }
        return shown.count > 32 ? String(shown.prefix(31)) + "…" : shown
    }

    static func internalURL(_ token: KitoRichTextToken) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = token.kind == .mention ? "mention" : "hashtag"
        components.queryItems = [URLQueryItem(name: "value", value: token.value)]
        return components.url
    }

    static func target(of url: URL) -> Target {
        guard url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "value" })?.value else {
            return .link(url)
        }
        return components.host == "mention" ? .mention(value) : .hashtag(value)
    }
}
