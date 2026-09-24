//
//  KitoComposerParts.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A growing text editor that colours @mentions, #hashtags and links as you type.
///
/// The styled text is drawn underneath a transparent `TextEditor`, laid out with the editor's own
/// insets so the caret sits on the coloured letters.
struct KitoHighlightingEditor: View {
    @Binding var text: String
    let placeholder: String
    let accent: Color
    var minHeight: CGFloat = 120
    var focused: FocusState<Bool>.Binding

    @Environment(\.kitoTheme) private var theme

    /// UITextView's default insets.
    private let insetX: CGFloat = 5
    private let insetY: CGFloat = 8

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(highlighted)
                .font(theme.typography.titleMedium.weight(.regular))
                .foregroundStyle(theme.colors.onSurface)
                .padding(.horizontal, insetX)
                .padding(.vertical, insetY)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
                .accessibilityHidden(true)
            if text.isEmpty {
                Text(placeholder)
                    .font(theme.typography.titleMedium.weight(.regular))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.4))
                    .padding(.horizontal, insetX)
                    .padding(.vertical, insetY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            TextEditor(text: $text)
                .font(theme.typography.titleMedium.weight(.regular))
                .foregroundStyle(.clear)
                .tint(accent)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .focused(focused)
                .accessibilityLabel(placeholder)
        }
    }

    /// The text with a trailing space so a final empty line still takes up room.
    private var highlighted: AttributedString {
        KitoRichTextStyler.attributed(text + " ", accent: accent, linksTappable: false)
    }
}

/// Builds a poll: two to four choices, a length, and remove.
struct KitoPollBuilder: View {
    @Binding var poll: KitoPollDraft
    let accent: Color
    let onRemove: () -> Void

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            ForEach(poll.options.indices, id: \.self) { index in
                optionField(index)
            }
            if poll.canAddOption {
                Button(action: addOption) {
                    Label("Add a choice", systemImage: "plus.circle.fill")
                        .font(theme.typography.label.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
            }
            Divider()
            HStack {
                durationMenu
                Spacer()
                Button("Remove poll", role: .destructive, action: onRemove)
                    .font(theme.typography.label.weight(.semibold))
                    .foregroundStyle(theme.colors.danger)
                    .buttonStyle(.plain)
            }
        }
        .padding(theme.spacing.md)
        .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surface))
        .overlay(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
            .strokeBorder(theme.colors.border, lineWidth: 1))
    }

    private func optionField(_ index: Int) -> some View {
        let binding = Binding(get: { poll.options.indices.contains(index) ? poll.options[index] : "" },
                              set: { if poll.options.indices.contains(index) { poll.options[index] = $0 } })
        let over = binding.wrappedValue.count > KitoPollDraft.maxOptionLength
        return HStack(spacing: theme.spacing.sm) {
            TextField("Choice \(index + 1)\(index >= KitoPollDraft.minOptions ? " (optional)" : "")", text: binding)
                .font(theme.typography.body)
                .tint(accent)
                .padding(.horizontal, theme.spacing.md)
                .frame(height: 42)
                .background(RoundedRectangle(cornerRadius: theme.radii.md, style: .continuous)
                    .strokeBorder(over ? theme.colors.danger : theme.colors.border, lineWidth: 1))
            Text("\(KitoPollDraft.maxOptionLength - binding.wrappedValue.count)")
                .font(theme.typography.caption.monospacedDigit())
                .foregroundStyle(over ? theme.colors.danger : theme.colors.onSurface.opacity(0.45))
                .frame(width: 24)
            if poll.options.count > KitoPollDraft.minOptions {
                Button { removeOption(index) } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 18))
                        .foregroundStyle(theme.colors.onSurface.opacity(0.4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove choice \(index + 1)")
            }
        }
    }

    private var durationMenu: some View {
        Menu {
            ForEach(KitoPollDraft.durations) { option in
                Button(option.title) { poll.duration = option.seconds }
            }
        } label: {
            Label(durationTitle, systemImage: "clock")
                .font(theme.typography.label.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface)
        }
        .accessibilityLabel("Poll length, \(durationTitle)")
    }

    private var durationTitle: String {
        KitoPollDraft.durations.first { $0.seconds == poll.duration }?.title ?? "1 day"
    }

    private func addOption() {
        withAnimation(reduceMotion ? nil : .snappy) { poll.options.append("") }
    }

    private func removeOption(_ index: Int) {
        guard poll.options.indices.contains(index) else { return }
        withAnimation(reduceMotion ? nil : .snappy) { _ = poll.options.remove(at: index) }
    }
}

/// A photo attached in the composer.
struct KitoComposerPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Thumbnails of attached photos with remove buttons.
struct KitoComposerPhotoStrip: View {
    let photos: [KitoComposerPhoto]
    let onRemove: (UUID) -> Void
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.sm) {
                ForEach(photos) { photo in
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: photos.count == 1 ? 220 : 130, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous))
                        .overlay(alignment: .topTrailing) { removeButton(photo.id) }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .accessibilityLabel("Attached photo")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func removeButton(_ id: UUID) -> some View {
        Button { onRemove(id) } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.black.opacity(0.6), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(6)
        .accessibilityLabel("Remove photo")
    }
}
