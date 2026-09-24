//
//  KitoFeedFormat.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// Short labels for times and counts, the way feeds write them.
///
/// ```swift
/// KitoFeedFormat.relativeTime(from: post.date)          // "now", "2m", "3h", "Yesterday", "4d", "12 Mar"
/// KitoFeedFormat.compactCount(1_240)                     // "1.2K"
/// KitoFeedFormat.timeLeft(until: poll.endsAt)            // "2h left", or "Final results"
/// ```
public enum KitoFeedFormat {
    /// "now" under a minute, then "2m", "3h", "Yesterday", "4d" within a week, then "12 Mar",
    /// and "12 Mar 2025" for another year. Dates in the future read "now".
    public static func relativeTime(from date: Date, now: Date = .now, calendar: Calendar = .current,
                                    locale: Locale = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3_600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3_600))h" }
        if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
            return "Yesterday"
        }
        let days = Int(seconds / 86_400)
        if days < 7 { return "\(max(days, 2))d" }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(sameYear ? "dMMM" : "dMMMyyyy")
        return formatter.string(from: date)
    }

    /// The same as `relativeTime`, spelled out for VoiceOver: "2 minutes ago", "Yesterday".
    public static func spokenRelativeTime(from date: Date, now: Date = .now) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// "999", "1K", "1.2K", "12.4K", "123K", "3.4M", "1.1B". Rounds down, so 999,999 is "999K"
    /// rather than "1000K", and a count never looks bigger than it is. Negative counts read "0".
    public static func compactCount(_ count: Int) -> String {
        let value = max(0, count)
        let units: [(size: Int, suffix: String)] = [(1_000_000_000, "B"), (1_000_000, "M"), (1_000, "K")]
        for unit in units where value >= unit.size {
            // Whole-number arithmetic, so 12,400 is exactly "12.4K" with no floating-point drift.
            let tenths = value / (unit.size / 10)
            if tenths >= 1_000 { return "\(value / unit.size)" + unit.suffix }
            let fraction = tenths % 10
            return (fraction == 0 ? "\(tenths / 10)" : "\(tenths / 10).\(fraction)") + unit.suffix
        }
        return "\(value)"
    }

    /// A full count with grouping for VoiceOver and "Liked by … and 1,203 others".
    public static func fullCount(_ count: Int) -> String {
        max(0, count).formatted(.number.grouping(.automatic))
    }

    /// "12m left", "2h left", "3d left", or "Final results" once `date` has passed.
    public static func timeLeft(until date: Date, now: Date = .now) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 { return "Final results" }
        if seconds < 60 { return "Less than a minute left" }
        if seconds < 3_600 { return "\(Int((seconds / 60).rounded(.up)))m left" }
        if seconds < 86_400 { return "\(Int(seconds / 3_600))h left" }
        return "\(Int(seconds / 86_400))d left"
    }

    /// "0:42", "3:05", "1:02:10".
    public static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        let two = { (n: Int) in n < 10 ? "0\(n)" : "\(n)" }
        return hours > 0 ? "\(hours):\(two(minutes)):\(two(secs))" : "\(minutes):\(two(secs))"
    }
}

/// Poll arithmetic.
public enum KitoPollMath {
    /// Whole-number percentages for `votes` that add up to exactly 100 (largest remainder), or
    /// all zeros when nobody has voted. Ties go to the earlier option.
    ///
    /// ```swift
    /// KitoPollMath.percentages([1, 1, 1])   // [34, 33, 33]
    /// ```
    public static func percentages(_ votes: [Int]) -> [Int] {
        let clean = votes.map { max(0, $0) }
        let total = clean.reduce(0, +)
        guard total > 0 else { return clean.map { _ in 0 } }
        let exact = clean.map { Double($0) * 100 / Double(total) }
        var result = exact.map { Int($0.rounded(.down)) }
        let missing = 100 - result.reduce(0, +)
        let order = exact.indices.sorted { lhs, rhs in
            let left = exact[lhs] - Double(result[lhs])
            let right = exact[rhs] - Double(result[rhs])
            return left == right ? lhs < rhs : left > right
        }
        for index in order.prefix(missing) { result[index] += 1 }
        return result
    }

    /// Indexes of the options with the most votes (several on a tie, none when there are no votes).
    public static func leaders(_ votes: [Int]) -> Set<Int> {
        guard let top = votes.max(), top > 0 else { return [] }
        return Set(votes.indices.filter { votes[$0] == top })
    }
}
