//
//  KitoRichTextParser.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// What a piece of post text is.
public enum KitoRichTextKind: Hashable, Sendable {
    case text
    /// "@amani" — `value` is the handle without "@".
    case mention
    /// "#nairobi" — `value` is the tag without "#".
    case hashtag
    /// A web address — `value` is the full URL with a scheme.
    case link
}

/// One run of post text.
public struct KitoRichTextToken: Hashable, Sendable {
    public var kind: KitoRichTextKind
    /// Exactly as written, e.g. "@amani" or "kito.dev/feed".
    public var text: String
    /// The handle, the tag, or the URL string. Same as `text` for plain text.
    public var value: String

    public init(kind: KitoRichTextKind, text: String, value: String) {
        self.kind = kind
        self.text = text
        self.value = value
    }

    /// For `.link`, the URL to open.
    public var url: URL? { kind == .link ? URL(string: value) : nil }
}

/// Splits post text into plain runs, @mentions, #hashtags and links.
///
/// ```swift
/// KitoRichTextParser.tokens(in: "Lunch with @amani at kito.dev #nairobi")
/// // text "Lunch with ", mention "amani", text " at ", link "https://kito.dev", text " ", hashtag "nairobi"
/// ```
///
/// Rules:
/// - A mention is "@" at the start or after a non-word character, then letters, digits, "_" or
///   inner dots. So an email address such as "hi@kito.dev" is not a mention.
/// - A hashtag is "#" at the start or after a non-word character, then letters, digits or "_"
///   with at least one letter, so "#1" is not a hashtag.
/// - A link starts with "http://", "https://" or "www.", or is a bare domain ending in a common
///   top-level domain. Trailing punctuation such as "." or ")" is left out.
public enum KitoRichTextParser {
    private static let tlds = "com|org|net|io|dev|app|co|ke|tz|ug|rw|africa|me|info|news|tv|ly|gg|xyz"

    private static let pattern: String = {
        let scheme = #"(?:https?://|www\.)[^\s<>]+"#
        let bare = #"(?<![\w@./-])(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+(?:"# + tlds + #")\b(?:/[^\s<>]*)?"#
        let mention = #"(?<![\w@])@([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*)"#
        let hashtag = #"(?<![\w#&])#([\p{L}\p{N}_]*\p{L}[\p{L}\p{N}_]*)"#
        return "(" + scheme + "|" + bare + ")|" + mention + "|" + hashtag
    }()

    private static let regex: NSRegularExpression? = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])

    /// Every run of `text`, in order. Joining the tokens' `text` gives back the input.
    public static func tokens(in text: String) -> [KitoRichTextToken] {
        guard let regex, !text.isEmpty else {
            return text.isEmpty ? [] : [KitoRichTextToken(kind: .text, text: text, value: text)]
        }
        let ns = text as NSString
        var result: [KitoRichTextToken] = []
        var cursor = 0

        func appendText(upTo end: Int) {
            guard end > cursor else { return }
            let piece = ns.substring(with: NSRange(location: cursor, length: end - cursor))
            if let last = result.last, last.kind == .text {
                result[result.count - 1] = KitoRichTextToken(kind: .text, text: last.text + piece, value: last.text + piece)
            } else {
                result.append(KitoRichTextToken(kind: .text, text: piece, value: piece))
            }
            cursor = end
        }

        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard let token = token(for: match, in: ns) else { continue }
            appendText(upTo: match.range.location)
            result.append(token.token)
            cursor = match.range.location + token.length
        }
        appendText(upTo: ns.length)
        return result
    }

    private static func token(for match: NSTextCheckingResult, in ns: NSString) -> (token: KitoRichTextToken, length: Int)? {
        if match.range(at: 1).location != NSNotFound {
            let raw = ns.substring(with: match.range(at: 1))
            let trimmed = trimLinkPunctuation(raw)
            guard !trimmed.isEmpty, trimmed.contains(".") else { return nil }
            let value = trimmed.lowercased().hasPrefix("http") ? trimmed : "https://" + trimmed
            guard URL(string: value) != nil else { return nil }
            return (KitoRichTextToken(kind: .link, text: trimmed, value: value), (trimmed as NSString).length)
        }
        if match.range(at: 2).location != NSNotFound {
            let handle = ns.substring(with: match.range(at: 2))
            return (KitoRichTextToken(kind: .mention, text: "@" + handle, value: handle), match.range.length)
        }
        if match.range(at: 3).location != NSNotFound {
            let tag = ns.substring(with: match.range(at: 3))
            return (KitoRichTextToken(kind: .hashtag, text: "#" + tag, value: tag), match.range.length)
        }
        return nil
    }

    /// Drops ".", ",", "!", "?", ":", ";", quotes and an unmatched ")" or "]" from the end.
    static func trimLinkPunctuation(_ raw: String) -> String {
        var link = raw
        while let last = link.last {
            if ".,!?:;'\"".contains(last) {
                link.removeLast()
            } else if last == ")", link.filter({ $0 == "(" }).count < link.filter({ $0 == ")" }).count {
                link.removeLast()
            } else if last == "]", link.filter({ $0 == "[" }).count < link.filter({ $0 == "]" }).count {
                link.removeLast()
            } else {
                break
            }
        }
        return link
    }

    /// Handles mentioned in `text`, in order, without repeats.
    public static func mentions(in text: String) -> [String] { unique(values(.mention, in: text)) }

    /// Hashtags in `text`, in order, without repeats (compared ignoring case).
    public static func hashtags(in text: String) -> [String] { unique(values(.hashtag, in: text)) }

    /// Links in `text`, in order.
    public static func links(in text: String) -> [URL] {
        tokens(in: text).compactMap(\.url)
    }

    private static func values(_ kind: KitoRichTextKind, in text: String) -> [String] {
        tokens(in: text).filter { $0.kind == kind }.map(\.value)
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.lowercased()).inserted }
    }
}
