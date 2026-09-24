//
//  KitoMentionSuggestions.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// The floating list of people shown while typing "@…", with the matched letters in bold.
///
/// ```swift
/// if let query = KitoMentionSearch.activeQuery(in: text) {
///     KitoMentionSuggestionList(people: KitoMentionSearch.filter(people, query: query), query: query) {
///         text = KitoMentionSearch.complete(text, with: $0)
///     }
/// }
/// ```
public struct KitoMentionSuggestionList: View {
    private let people: [KitoFeedPerson]
    private let query: String
    private let tint: Color?
    private let onSelect: (KitoFeedPerson) -> Void

    @Environment(\.kitoTheme) private var theme

    public init(people: [KitoFeedPerson], query: String, tint: Color? = nil, onSelect: @escaping (KitoFeedPerson) -> Void) {
        self.people = people
        self.query = query
        self.tint = tint
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if people.isEmpty {
                Label(query.isEmpty ? "Type a name" : "No one called “\(query)”", systemImage: "person.fill.questionmark")
                    .font(theme.typography.label.weight(.regular))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.6))
                    .padding(theme.spacing.md)
            }
            ForEach(people) { person in
                Button { onSelect(person) } label: { row(person) }
                    .buttonStyle(KitoMentionRowStyle())
                    .accessibilityLabel("\(person.name), @\(person.handle)")
                    .accessibilityHint("Mentions them")
                if person.id != people.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .padding(.vertical, theme.spacing.xs)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
            .strokeBorder(theme.colors.border.opacity(0.7), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggested people")
    }

    private func row(_ person: KitoFeedPerson) -> some View {
        HStack(spacing: 10) {
            KitoFeedAvatar(person: person, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    highlighted(person.name, font: theme.typography.label.weight(.regular), bold: theme.typography.label.weight(.bold))
                    if person.isVerified { KitoFeedVerifiedBadge(size: 12, tint: tint) }
                }
                highlighted("@" + person.handle, font: theme.typography.caption, bold: theme.typography.caption.weight(.bold))
                    .opacity(0.65)
            }
            .foregroundStyle(theme.colors.onSurface)
            Spacer(minLength: 0)
            if person.isFollowing {
                Text("Following")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.55))
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private func highlighted(_ text: String, font: Font, bold: Font) -> Text {
        var string = AttributedString(text)
        string.font = font
        if let range = KitoMentionSearch.matchRange(of: query, in: text) {
            let start = string.index(string.startIndex, offsetByCharacters: range.lowerBound)
            let end = string.index(start, offsetByCharacters: range.count)
            string[start..<end].font = bold
        }
        return Text(string)
    }
}

private struct KitoMentionRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.primary.opacity(configuration.isPressed ? 0.06 : 0))
    }
}
