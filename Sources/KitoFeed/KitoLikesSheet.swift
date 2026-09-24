//
//  KitoLikesSheet.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Who liked a post: a searchable list with avatars, "Follows you" and Follow buttons.
///
/// ```swift
/// .sheet(isPresented: $showLikes) {
///     KitoLikesSheet(people: $likers, total: post.likes) { person, following in
///         api.setFollowing(person.id, following)
///     }
/// }
/// ```
///
/// Sits at medium height with a grabber and can be pulled up to full height.
public struct KitoLikesSheet: View {
    @Binding private var people: [KitoFeedPerson]
    private let title: String
    private let total: Int?
    private let currentUserID: String?
    private let tint: Color?
    private let onFollowChange: ((KitoFeedPerson, Bool) -> Void)?

    @State private var query = ""
    @Environment(\.kitoTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.kitoFeedActions) private var actions

    /// - Parameters:
    ///   - total: The full like count, when the list holds only the first page.
    ///   - currentUserID: Hides the Follow button on your own row.
    public init(people: Binding<[KitoFeedPerson]>, title: String = "Likes", total: Int? = nil, currentUserID: String? = nil,
                tint: Color? = nil, onFollowChange: ((KitoFeedPerson, Bool) -> Void)? = nil) {
        self._people = people
        self.title = title
        self.total = total
        self.currentUserID = currentUserID
        self.tint = tint
        self.onFollowChange = onFollowChange
    }

    private var visible: [Binding<KitoFeedPerson>] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return $people.filter { person in
            q.isEmpty || person.wrappedValue.name.localizedStandardContains(q) || person.wrappedValue.handle.localizedStandardContains(q)
        }
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(visible) { person in
                    row(person)
                        .listRowBackground(theme.colors.surface)
                        .listRowSeparatorTint(theme.colors.border)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.colors.surface)
            .overlay { if visible.isEmpty && !query.isEmpty { empty } }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { heading }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold).tint(theme.colors.onSurface)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var heading: some View {
        VStack(spacing: 0) {
            Text(title).font(theme.typography.bodyEmphasized.weight(.semibold))
            Text("\(KitoFeedFormat.fullCount(total ?? people.count)) people")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.onSurface.opacity(0.55))
        }
        .foregroundStyle(theme.colors.onSurface)
    }

    private func row(_ person: Binding<KitoFeedPerson>) -> some View {
        let value = person.wrappedValue
        return HStack(spacing: theme.spacing.md) {
            Button { actions.onAuthor?(value) } label: {
                HStack(spacing: theme.spacing.md) {
                    KitoFeedAvatar(person: value, size: 44)
                        .overlay(alignment: .bottomTrailing) { likedHeart }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(value.name).font(theme.typography.bodyEmphasized.weight(.semibold)).lineLimit(1)
                            if value.isVerified { KitoFeedVerifiedBadge(size: 13, tint: tint) }
                        }
                        subtitle(value)
                    }
                    .foregroundStyle(theme.colors.onSurface)
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: theme.spacing.sm)
            if value.id != currentUserID {
                KitoFollowButton(isFollowing: person.isFollowing, name: value.name, followsYou: value.followsYou,
                                 tint: tint) { following in
                    onFollowChange?(person.wrappedValue, following)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func subtitle(_ person: KitoFeedPerson) -> some View {
        HStack(spacing: 6) {
            Text("@\(person.handle)").lineLimit(1)
            if person.followsYou {
                Text("Follows you")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(theme.colors.surfaceMuted))
            }
        }
        .font(theme.typography.caption)
        .foregroundStyle(theme.colors.onSurface.opacity(0.6))
    }

    private var likedHeart: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(Circle().fill(theme.colors.danger))
            .overlay(Circle().strokeBorder(theme.colors.surface, lineWidth: 2))
            .offset(x: 2, y: 2)
            .accessibilityHidden(true)
    }

    private var empty: some View {
        ContentUnavailableView.search(text: query)
    }
}
