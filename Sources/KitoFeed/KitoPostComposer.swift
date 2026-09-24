//
//  KitoPostComposer.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import PhotosUI
import KitoCore

/// What `KitoPostComposer` hands back when Post is tapped.
public struct KitoComposedPost {
    public var text: String
    public var audience: KitoPostAudience
    public var images: [UIImage]
    public var poll: KitoFeedPoll?
    public var quote: KitoFeedQuote?

    /// A post ready to insert at the top of a feed. Photos are written to temporary files so they
    /// show straight away; upload `images` to your server for the real thing.
    public func makePost(id: String = UUID().uuidString, author: KitoFeedPerson, date: Date = .now) -> KitoFeedPost {
        var media: KitoFeedMedia?
        if let poll {
            media = .poll(poll)
        } else if !images.isEmpty {
            media = .photos(images.enumerated().map { index, image in Self.photo(image, name: "\(id)-\(index)") })
        }
        return KitoFeedPost(id: id, author: author, date: date, text: text, media: media, quote: quote)
    }

    private static func photo(_ image: UIImage, name: String) -> KitoFeedPhoto {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".jpg")
        let saved = (try? image.jpegData(compressionQuality: 0.85)?.write(to: url)) != nil
        let ratio = image.size.height > 0 ? image.size.width / image.size.height : 1
        return KitoFeedPhoto(id: name, url: saved ? url : nil, aspectRatio: ratio, altText: "Photo")
    }
}

/// A full-screen composer: a live character ring, mentions and hashtags coloured as you type with
/// @mention suggestions, up to four photos from the library, a poll builder, an audience picker,
/// and a Post button that only enables when the post can go out.
///
/// ```swift
/// .sheet(isPresented: $composing) {
///     KitoPostComposer(author: me, people: following, onCancel: { composing = false }) { composed in
///         posts.insert(composed.makePost(author: me), at: 0)
///         composing = false
///     }
/// }
/// ```
public struct KitoPostComposer: View {
    private let author: KitoFeedPerson
    private let people: [KitoFeedPerson]
    private let quoting: KitoFeedQuote?
    private let placeholder: String
    private let tint: Color?
    private let onCancel: () -> Void
    private let onPost: (KitoComposedPost) -> Void

    @State private var draft: KitoPostDraft
    @State private var photos: [KitoComposerPhoto] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var confirmDiscard = false
    @FocusState private var editorFocused: Bool
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - author: The current user.
    ///   - people: Who can be @mentioned.
    ///   - quoting: A post being quoted, shown under the text.
    ///   - text: Text to start with, e.g. "#nairobi ".
    ///   - characterLimit: Post turns off past this many characters.
    public init(author: KitoFeedPerson, people: [KitoFeedPerson] = [], quoting: KitoFeedQuote? = nil,
                text: String = "", placeholder: String = "What's happening?", characterLimit: Int = 280,
                audience: KitoPostAudience = .everyone, tint: Color? = nil,
                onCancel: @escaping () -> Void, onPost: @escaping (KitoComposedPost) -> Void) {
        self.author = author
        self.people = people
        self.quoting = quoting
        self.placeholder = placeholder
        self.tint = tint
        self.onCancel = onCancel
        self.onPost = onPost
        self._draft = State(initialValue: KitoPostDraft(text: text, audience: audience, characterLimit: characterLimit))
    }

    private var accent: Color { tint ?? theme.colors.primary }
    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.82) }
    private var mentionQuery: String? { people.isEmpty ? nil : KitoMentionSearch.activeQuery(in: draft.text) }

    public var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.top, theme.spacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(theme.colors.surface)
            .safeAreaInset(edge: .bottom, spacing: 0) { toolbar }
            .toolbar { topBar }
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Discard this post?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive, action: onCancel)
            }
        }
        .onAppear { editorFocused = true }
        .onChange(of: pickerItems) { _, items in load(items) }
        .onChange(of: photos.count) { _, count in draft.photoCount = count }
        .animation(spring, value: mentionQuery)
    }

    // MARK: Content

    private var content: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            KitoFeedAvatar(person: author, size: 42)
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                audienceMenu
                KitoHighlightingEditor(text: $draft.text, placeholder: draft.poll == nil ? placeholder : "Ask a question…",
                                       accent: accent, focused: $editorFocused)
                    .padding(.horizontal, -5)
                if !photos.isEmpty {
                    KitoComposerPhotoStrip(photos: photos, onRemove: removePhoto)
                }
                if draft.poll != nil {
                    KitoPollBuilder(poll: pollBinding, accent: accent, onRemove: removePoll)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let quoting { KitoFeedQuoteCard(quote: quoting) }
            }
        }
    }

    private var audienceMenu: some View {
        Menu {
            Picker("Audience", selection: $draft.audience) {
                ForEach(KitoPostAudience.allCases) { audience in
                    Label {
                        Text(audience.title)
                        Text(audience.subtitle)
                    } icon: {
                        Image(systemName: audience.systemImage)
                    }
                    .tag(audience)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: draft.audience.systemImage).font(.system(size: 11, weight: .bold))
                Text(draft.audience.title).font(theme.typography.label.weight(.semibold))
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .overlay(Capsule().strokeBorder(accent.opacity(0.5), lineWidth: 1))
            .contentTransition(.interpolate)
        }
        .accessibilityLabel("Audience, \(draft.audience.title)")
    }

    // MARK: Bars

    @ToolbarContentBuilder private var topBar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", action: cancel).tint(theme.colors.onSurface)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: post) {
                Text("Post")
                    .font(theme.typography.label.weight(.bold))
                    .foregroundStyle(theme.colors.surface)
                    .padding(.horizontal, 18)
                    .frame(height: 34)
                    .background(Capsule().fill(theme.colors.onSurface))
                    .opacity(draft.canPost ? 1 : 0.3)
            }
            .buttonStyle(KitoFeedPressStyle())
            .disabled(!draft.canPost)
            .animation(spring, value: draft.canPost)
            .accessibilityHint(draft.blocker ?? "")
        }
    }

    private var toolbar: some View {
        VStack(spacing: 0) {
            if let query = mentionQuery {
                KitoMentionSuggestionList(people: KitoMentionSearch.filter(people, query: query, limit: 4), query: query,
                                          tint: tint) { person in
                    draft.text = KitoMentionSearch.complete(draft.text, with: person)
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.bottom, theme.spacing.sm)
                .transition(.scale(scale: 0.96, anchor: .bottom).combined(with: .opacity))
            }
            Divider()
            HStack(spacing: theme.spacing.xs) {
                photoPicker
                toolButton("chart.bar.xaxis", label: "Add poll", enabled: draft.canAddPoll, action: addPoll)
                toolButton("at", label: "Mention someone", enabled: true) { insert("@") }
                toolButton("number", label: "Add hashtag", enabled: true) { insert("#") }
                Spacer()
                hint
                KitoCharacterCounterRing(count: draft.characterCount, limit: draft.characterLimit, tint: tint)
            }
            .padding(.horizontal, theme.spacing.md)
            .padding(.vertical, theme.spacing.sm)
            .background(.bar)
        }
    }

    @ViewBuilder private var hint: some View {
        if let blocker = draft.blocker, draft.hasContent {
            Text(blocker)
                .font(theme.typography.caption)
                .foregroundStyle(draft.isOverLimit ? theme.colors.danger : theme.colors.onSurface.opacity(0.5))
                .lineLimit(1)
                .transition(.opacity)
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $pickerItems, maxSelectionCount: KitoPostDraft.maxPhotos, selectionBehavior: .ordered,
                     matching: .images) {
            toolIcon("photo.on.rectangle.angled", enabled: draft.canAttachPhotos)
        }
        .disabled(!draft.canAttachPhotos && photos.isEmpty)
        .accessibilityLabel("Add photos")
    }

    private func toolButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { toolIcon(symbol, enabled: enabled) }
            .buttonStyle(KitoFeedPressStyle())
            .disabled(!enabled)
            .accessibilityLabel(label)
    }

    private func toolIcon(_ symbol: String, enabled: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(enabled ? accent : theme.colors.onSurface.opacity(0.25))
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
    }

    // MARK: Actions

    private var pollBinding: Binding<KitoPollDraft> {
        Binding { draft.poll ?? KitoPollDraft() } set: { draft.poll = $0 }
    }

    private func insert(_ symbol: String) {
        let needsSpace = !(draft.text.isEmpty || draft.text.last?.isWhitespace == true)
        draft.text += (needsSpace ? " " : "") + symbol
        editorFocused = true
    }

    private func addPoll() {
        withAnimation(spring) { draft.poll = KitoPollDraft() }
    }

    private func removePoll() {
        withAnimation(spring) { draft.poll = nil }
    }

    private func removePhoto(_ id: UUID) {
        withAnimation(spring) { photos.removeAll { $0.id == id } }
    }

    private func load(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var loaded: [KitoComposerPhoto] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    loaded.append(KitoComposerPhoto(image: image))
                }
            }
            withAnimation(spring) {
                photos = Array((photos + loaded).prefix(KitoPostDraft.maxPhotos))
            }
            pickerItems = []
        }
    }

    private func cancel() {
        if draft.hasContent { confirmDiscard = true } else { onCancel() }
    }

    private func post() {
        guard draft.canPost else { return }
        let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        onPost(KitoComposedPost(text: text, audience: draft.audience, images: photos.map(\.image),
                                poll: draft.poll?.makePoll(), quote: quoting))
    }
}
