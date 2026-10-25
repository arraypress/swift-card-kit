//
//  CardMath.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  Everything a card shows that can be wrong, as pure functions: amounts as
//  text, sums that never cross currencies, what is left, shares, changes, a
//  pace and a projection, averages, scales and their ticks, the order rows
//  are drawn in, the colour slot each part keeps, the words of each status,
//  the hero and status a block supplies when the card gives none. The views
//  only lay these out. Checks live in CardChecks.
//

import Foundation

public enum CardMath {

    // MARK: - Amounts as text

    /// A decimal written plainly for JSON: "4.2", "1188.4".
    static func plain(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).description(withLocale: Locale(identifier: "en_US_POSIX"))
    }

    /// Money whole (`£1,188`) or exact (`£1,188.40`, `¥500`); a plain number with up to one decimal, or none.
    public static func text(_ amount: Amount, whole: Bool = false, locale: Locale = .current) -> String {
        if let currency = amount.currency {
            let places = whole ? 0 : Currencies.exponent(currency)
            return amount.value.formatted(.currency(code: currency).locale(locale).precision(.fractionLength(places)))
        }
        return amount.value.formatted(.number.locale(locale).precision(.fractionLength(0...(whole ? 0 : 1))))
    }

    /// An amount with its unit after a plain number: "2,140 kcal"; money carries its own symbol.
    public static func text(_ amount: Amount, unit: String?, whole: Bool = false, locale: Locale = .current) -> String {
        let number = text(amount, whole: whole, locale: locale)
        guard amount.currency == nil, let unit, !unit.isEmpty else { return number }
        return unit == "%" || unit == "°" ? number + unit : "\(number) \(unit)"
    }

    /// A value as drawn: words as given, an amount formatted.
    public static func text(_ shown: Shown, unit: String? = nil, whole: Bool = false, locale: Locale = .current) -> String {
        switch shown {
        case .text(let words): return words
        case .amount(let amount): return text(amount, unit: unit, whole: whole, locale: locale)
        }
    }

    // MARK: - Sums

    /// Amounts added up; nil for none. Checks have made sure they share a currency.
    static func sum(_ amounts: [Amount]) -> Amount? {
        guard let first = amounts.first else { return nil }
        return Amount(amounts.reduce(Decimal(0)) { $0 + $1.value }, currency: first.currency)
    }

    static func minus(_ a: Amount, _ b: Amount) -> Amount { Amount(a.value - b.value, currency: a.currency) }

    static func abs(_ a: Amount) -> Amount { Amount(a.value < 0 ? -a.value : a.value, currency: a.currency) }

    static func double(_ amount: Amount) -> Double { NSDecimalNumber(decimal: amount.value).doubleValue }

    /// Within half of the smallest unit shown on a card (whole units): the same.
    static func isLevel(_ delta: Decimal) -> Bool { Swift.abs(NSDecimalNumber(decimal: delta).doubleValue) < 0.5 }

    /// How full a bar or ring is: 0…1.
    public static func fill(_ value: Amount, of limit: Amount) -> Double {
        let whole = double(limit), part = double(value)
        guard whole > 0, part > 0 else { return 0 }
        return min(1, part / whole)
    }

    /// The share of a full bar past its limit, drawn striped: the excess over the value, at most half.
    public static func overShare(_ value: Amount, of limit: Amount) -> Double {
        let part = double(value), whole = double(limit)
        guard part > whole, part > 0 else { return 0 }
        return min(0.5, (part - whole) / part)
    }

    public static func isOver(_ value: Amount, of limit: Amount) -> Bool { value.value > limit.value }

    /// "+12 %", "−3 %": a change in percent, signed, one decimal under 10.
    public static func percentChange(_ value: Double, locale: Locale = .current) -> String {
        let digits = Swift.abs(value) < 10 ? 1 : 0
        let number = Swift.abs(value).formatted(.number.locale(locale).precision(.fractionLength(0...digits)))
        return (value > 0 ? "+" : value < 0 ? "−" : "") + number + " %"
    }

    // MARK: - Colour slots

    /// Each part's palette slot (1–8): its own, else its position in the input — so a part keeps its colour
    /// however the card sorts it, and the same order on every card gives the same colours.
    public static func slots(_ given: [Int?]) -> [Int] {
        given.enumerated().map { index, slot in slot ?? (index + 1) }
    }

    // MARK: - limits

    /// The overall limit and how much of it is used.
    public static func totals(_ block: LimitsBlock) -> (used: Amount, limit: Amount) {
        (sum(block.rows.map(\.value)) ?? Amount(0), block.total ?? sum(block.rows.map(\.of)) ?? Amount(0))
    }

    /// Rows with their slots, nearest their limit first (ties keep their order), or as given.
    public static func ordered(_ block: LimitsBlock) -> [(row: LimitRow, slot: Int)] {
        let pairs = Array(zip(block.rows, slots(block.rows.map(\.slot))))
        guard block.order != "given" else { return pairs.map { ($0.0, $0.1) } }
        return pairs.enumerated().sorted { a, b in
            let fa = ratio(a.element.0), fb = ratio(b.element.0)
            return fa != fb ? fa > fb : a.offset < b.offset
        }.map { ($0.element.0, $0.element.1) }
    }

    private static func ratio(_ row: LimitRow) -> Double {
        let limit = double(row.of)
        return limit > 0 ? double(row.value) / limit : .infinity
    }

    static func hero(_ block: LimitsBlock, locale: Locale) -> Hero {
        let (used, limit) = totals(block)
        let left = minus(limit, used)
        let suffix = block.unit.map { " \($0)" } ?? ""
        let of = text(limit, whole: true, locale: locale) + suffix
        return left.value >= 0 ? Hero(value: .text(text(left, whole: true, locale: locale) + suffix), unit: "left of \(of)")
                               : Hero(value: .text(text(abs(left), whole: true, locale: locale) + suffix), unit: "over \(of)")
    }

    static func status(_ block: LimitsBlock, locale: Locale) -> StatusText {
        let (used, limit) = totals(block)
        let left = minus(limit, used)
        let suffix = block.unit.map { " \($0)" } ?? ""
        let overRows = block.rows.filter { isOver($0.value, of: $0.of) }.count
        if left.value < 0 { return StatusText(status: .over, text: "\(text(abs(left), whole: true, locale: locale))\(suffix) over the limit") }
        if let days = block.daysLeft, days > 0 {
            let perDay = Amount(left.value / Decimal(days), currency: left.currency)
            return StatusText(status: overRows == 0 ? .good : .neutral,
                              text: "About \(text(perDay, whole: true, locale: locale))\(suffix) a day for the \(days) \(days == 1 ? "day" : "days") left")
        }
        return overRows == 0 ? StatusText(status: .good, text: "Every part within its limit")
                             : StatusText(status: .neutral, text: "\(overRows) of \(block.rows.count) over their limit")
    }

    // MARK: - breakdown and segmented

    /// Parts with their slots, largest first (ties keep their order).
    public static func ordered(_ parts: [Part]) -> [(part: Part, slot: Int)] {
        Array(zip(parts, slots(parts.map(\.slot)))).enumerated().sorted { a, b in
            a.element.0.value.value != b.element.0.value.value ? a.element.0.value.value > b.element.0.value.value : a.offset < b.offset
        }.map { ($0.element.0, $0.element.1) }
    }

    /// Each part's share as a whole percent, rounded so they add to 100 (largest remainder).
    public static func shares(_ values: [Double]) -> [Int] {
        let values = values.map { max(0, $0) }
        let total = values.reduce(0, +)
        guard total > 0 else { return values.map { _ in 0 } }
        let exact = values.map { $0 / total * 100 }
        var floors = exact.map { Int($0.rounded(.down)) }
        let short = 100 - floors.reduce(0, +)
        for index in exact.indices.sorted(by: { exact[$0] - Double(floors[$0]) > exact[$1] - Double(floors[$1]) }).prefix(short) {
            floors[index] += 1
        }
        return floors
    }

    public enum Change: Equatable { case up(Amount), down(Amount), same }

    public static func change(_ part: Part) -> Change? {
        guard let previous = part.previous else { return nil }
        let delta = part.value.value - previous.value
        if isLevel(delta) { return .same }
        return delta > 0 ? .up(Amount(delta, currency: part.value.currency)) : .down(Amount(-delta, currency: part.value.currency))
    }

    static func hero(_ block: BreakdownBlock, locale: Locale) -> Hero? {
        guard let total = sum(block.rows.map(\.value)) else { return nil }
        return Hero(value: .text(text(total, unit: block.unit, whole: true, locale: locale)), unit: "in all")
    }

    static func status(_ block: BreakdownBlock, locale: Locale) -> StatusText? {
        guard let reference = block.reference, let total = sum(block.rows.map(\.value)) else { return nil }
        let delta = reference.value.value - total.value
        let amount = text(Amount(delta < 0 ? -delta : delta, currency: total.currency), unit: block.unit, whole: true, locale: locale)
        if isLevel(delta) { return StatusText(status: .neutral, text: "Same as \(reference.label)") }
        return delta > 0 ? StatusText(status: .good, text: "\(amount) less than \(reference.label)")
                         : StatusText(status: .over, text: "\(amount) more than \(reference.label)")
    }

    /// A segmented bar's pieces as fractions of the whole (the capacity, or the parts' sum), largest first, and
    /// the free rest.
    public static func segments(_ block: SegmentedBlock) -> (pieces: [(part: Part, slot: Int, fraction: Double)], rest: Double) {
        let used = block.parts.reduce(0) { $0 + max(0, double($1.value)) }
        let whole = max(block.of.map(double) ?? used, used)
        guard whole > 0 else { return ([], 0) }
        let pieces = ordered(block.parts).map { ($0.part, $0.slot, max(0, double($0.part.value)) / whole) }
        return (pieces, max(0, 1 - used / whole))
    }

    // MARK: - bars

    /// The average of the logged bars (stacks by their totals); nil with none.
    public static func average(_ block: BarsBlock) -> Double? {
        let values = block.bars.compactMap(total)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// A bar's height: its value, or its parts added up; nil if not logged.
    public static func total(_ bar: Bar) -> Double? {
        if let parts = bar.parts { return parts.reduce(0) { $0 + double($1) } }
        return bar.value.map(double)
    }

    /// Which bar is strong: the one given, else the last logged.
    public static func highlighted(_ block: BarsBlock) -> Int? {
        if let index = block.highlight { return index }
        return block.bars.lastIndex { total($0) != nil }
    }

    /// One mark per bar, or per part of a stacked bar, with where it starts and ends and whether it is the top of
    /// its stack (the top gets the rounded corners).
    public struct StackMark: Equatable { public var id: String; public var bar: Int; public var slot: Int; public var from: Double; public var to: Double; public var top: Bool }

    public static func stacks(_ block: BarsBlock) -> [StackMark] {
        let slots = slots((block.legend ?? []).map(\.slot))
        return block.bars.enumerated().flatMap { index, bar -> [StackMark] in
            if let parts = bar.parts {
                var base = 0.0
                let last = parts.lastIndex { double($0) > 0 }
                return parts.enumerated().compactMap { p, part in
                    let height = double(part)
                    guard height > 0 else { return nil }
                    defer { base += height }
                    return StackMark(id: "\(index)-\(p)", bar: index, slot: slots.indices.contains(p) ? slots[p] : p + 1,
                                     from: base, to: base + height, top: p == last)
                }
            }
            guard let value = bar.value.map(double), value > 0 else { return [] }
            return [StackMark(id: "\(index)", bar: index, slot: 1, from: 0, to: value, top: true)]
        }
    }

    /// The top of the scale: the tallest bar, goal or band, rounded up to a "nice" number.
    public static func scaleTop(_ block: BarsBlock) -> Double {
        let candidates = block.bars.compactMap(total) + [block.goal, block.band?.high].compactMap { $0.map(double) }
        return niceCeiling(candidates.max() ?? 1)
    }

    static func hero(_ block: BarsBlock, locale: Locale) -> Hero? {
        guard let index = highlighted(block), let value = total(block.bars[index]) else { return nil }
        let currency = block.bars.compactMap { $0.value?.currency ?? $0.parts?.first?.currency }.first
        let number = text(Amount(Decimal(value), currency: currency), whole: true, locale: locale)
        return Hero(value: .text(number), unit: currency == nil ? block.unit : nil)
    }

    static func status(_ block: BarsBlock, locale: Locale) -> StatusText? {
        guard let index = highlighted(block), let value = total(block.bars[index]) else { return nil }
        let currency = block.bars.compactMap { $0.value?.currency ?? $0.parts?.first?.currency }.first
        let words = { (v: Double) in text(Amount(Decimal(v.rounded()), currency: currency), unit: block.unit, whole: true, locale: locale) }
        if let band = block.band {
            let low = double(band.low), high = double(band.high)
            if value < low { return StatusText(status: .neutral, text: "\(words(low - value)) under the target") }
            if value > high { return StatusText(status: .over, text: "\(words(value - high)) over the target") }
            return StatusText(status: .good, text: "On target")
        }
        if let goal = block.goal.map(double) {
            return value >= goal ? StatusText(status: .good, text: "Goal reached")
                                 : StatusText(status: .neutral, text: "\(words(goal - value)) to the goal")
        }
        guard let average = average(block), average > 0 else { return nil }
        let percent = (value - average) / average * 100
        if Swift.abs(percent) < 2 { return StatusText(status: .neutral, text: "About your average") }
        return StatusText(status: .neutral, text: "\(percentChange(percent, locale: locale)) against the average of \(words(average))")
    }

    /// A round number at or above `value`: 1, 1.5, 2, 2.5, 3, 4, 5, 6 or 8 times a power of ten.
    public static func niceCeiling(_ value: Double) -> Double {
        guard value > 0, value.isFinite else { return 1 }
        let power = pow(10, (log10(value)).rounded(.down))
        for step in [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10] where step * power >= value * 0.999_999 { return step * power }
        return 10 * power
    }

    /// Up to four evenly spaced ticks from zero to `top`.
    public static func ticks(top: Double) -> [Double] {
        let step = niceCeiling(top / 3)
        return stride(from: 0, through: top + step * 0.001, by: step).map { $0 }
    }

    // MARK: - trend

    /// A series' value at x: its last point at or before x; nil before its first.
    public static func value(_ series: Series, at x: Double) -> Amount? {
        series.points.last { $0.x <= x }?.value
    }

    static func latest(_ block: TrendBlock) -> Point? { block.series.first?.points.last }

    /// An n-point trailing moving average, the first n−1 points over what exists so far.
    public static func movingAverage(_ values: [Double], window: Int) -> [Double] {
        guard window > 1 else { return values }
        return values.indices.map { index in
            let slice = values[max(0, index - window + 1)...index]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    static func hero(_ block: TrendBlock, locale: Locale) -> Hero? {
        guard let now = latest(block) else { return nil }
        return Hero(value: .text(text(now.value, unit: block.unit, whole: true, locale: locale)), unit: block.target != nil ? "so far" : nil)
    }

    /// The first series against the second at the same x.
    static func status(_ block: TrendBlock, locale: Locale) -> StatusText? {
        guard let now = latest(block), block.series.count > 1, let then = value(block.series[1], at: now.x) else {
            return block.series.first.flatMap { first in
                guard first.points.count > 1 else { return nil }
                let delta = first.points.last!.value.value - first.points.first!.value.value
                if isLevel(delta) { return StatusText(status: .neutral, text: "Level over the period") }
                let amount = text(Amount(delta < 0 ? -delta : delta, currency: first.points[0].value.currency), unit: block.unit, whole: true, locale: locale)
                return StatusText(status: .neutral, text: delta > 0 ? "Up \(amount) over the period" : "Down \(amount) over the period")
            }
        }
        let delta = then.value - now.value.value
        let amount = text(Amount(delta < 0 ? -delta : delta, currency: now.value.currency), unit: block.unit, whole: true, locale: locale)
        let name = block.series[1].name
        if isLevel(delta) { return StatusText(status: .neutral, text: "Level with \(name) by now") }
        return delta > 0 ? StatusText(status: .good, text: "\(amount) under \(name) by now")
                         : StatusText(status: .over, text: "\(amount) over \(name) by now")
    }

    /// Where the current pace ends: the latest running total scaled from its x to the end.
    public static func projection(_ block: TrendBlock) -> Amount? {
        guard let now = latest(block), let end = block.end ?? block.target?.at, now.x > 0, end >= now.x else { return nil }
        let scaled = double(now.value) / now.x * end
        return Amount(Decimal(scaled.rounded()), currency: now.value.currency)
    }

    /// "At this pace about £1,670 by the end — £130 under the target."
    public static func projectionText(_ block: TrendBlock, locale: Locale = .current) -> String? {
        guard block.target != nil, let projected = projection(block) else { return nil }
        var line = "At this pace about \(text(projected, unit: block.unit, whole: true, locale: locale)) by the end"
        if let target = block.target {
            let delta = target.value.value - projected.value
            let gap = text(Amount(delta < 0 ? -delta : delta, currency: projected.currency), unit: block.unit, whole: true, locale: locale)
            let name = target.label ?? "the target"
            line += isLevel(delta) ? ", right on \(name)" : delta > 0 ? " — \(gap) under \(name)" : " — \(gap) over \(name)"
        }
        return line + "."
    }

    // MARK: - range

    /// The shared scale of a range block: lowest low to highest high, padded a little.
    public static func scale(_ block: RangeBlock) -> ClosedRange<Double> {
        let lows = block.rows.map { double($0.low) }, highs = block.rows.map { double($0.high) }
        let low = (lows.min() ?? 0), high = (highs.max() ?? 1)
        let pad = max((high - low) * 0.04, 0.5)
        return (low - pad)...(high + pad)
    }

    /// Where a value sits on a scale: 0…1.
    public static func position(_ value: Double, in scale: ClosedRange<Double>) -> Double {
        let width = scale.upperBound - scale.lowerBound
        return width > 0 ? min(1, max(0, (value - scale.lowerBound) / width)) : 0.5
    }

    // MARK: - timeline

    /// Each item's lane: with a legend, the row of its slot in the legend (a sleep chart's stages); otherwise the
    /// first lane free at its start, so overlapping spans don't cover each other (a calendar).
    public static func lanes(_ block: TimelineBlock) -> [Int] {
        if let legend = block.legend, !legend.isEmpty {
            let order = slots(legend.map(\.slot))
            return block.items.map { item in order.firstIndex(of: item.slot ?? 1) ?? order.count }
        }
        return lanes(block.items)
    }

    /// Lanes so overlapping spans don't cover each other: each item takes the first lane free at its start.
    public static func lanes(_ items: [TimelineItem]) -> [Int] {
        var ends: [Double] = []
        var lanes = Array(repeating: 0, count: items.count)
        for index in items.indices.sorted(by: { items[$0].from < items[$1].from }) {
            let item = items[index], stop = item.to ?? item.from
            if let free = ends.firstIndex(where: { $0 <= item.from }) {
                lanes[index] = free; ends[free] = stop
            } else {
                lanes[index] = ends.count; ends.append(stop)
            }
        }
        return lanes
    }

    /// A time on a timeline's axis: 9.5 hours → "09:30", 102 seconds → "1:42", or the number.
    public static func timeText(_ x: Double, scale: String?) -> String {
        switch scale {
        case "hours":
            let minutes = Int((x * 60).rounded())
            return String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
        case "seconds":
            let seconds = Int(x.rounded())
            return seconds >= 3600 ? String(format: "%d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
                                   : String(format: "%d:%02d", seconds / 60, seconds % 60)
        default:
            return x.formatted(.number.precision(.fractionLength(0...1)))
        }
    }

    /// Up to five round ticks across a span.
    public static func timeTicks(start: Double, end: Double, scale: String?) -> [Double] {
        let span = end - start
        guard span > 0 else { return [start] }
        let steps: [Double] = scale == "hours" ? [0.25, 0.5, 1, 2, 3, 4, 6, 12] : scale == "seconds" ? [5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600] : []
        let step = steps.first { span / $0 <= 4 } ?? niceCeiling(span / 4)
        let first = (start / step).rounded(.up) * step
        return stride(from: first, through: end + step * 0.001, by: step).map { $0 }
    }

    // MARK: - heatmap

    /// Calendar position of each day: (week column, weekday row Monday = 0), counting from `start`'s week.
    public static func grid(start: String, count: Int) -> [(column: Int, row: Int)]? {
        guard let first = day(start) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let offset = (calendar.component(.weekday, from: first) + 5) % 7
        return (0..<count).map { index in ((offset + index) / 7, (offset + index) % 7) }
    }

    /// The level (0 none … 4 most) of each value: quartiles of the non-zero days, so a few big days don't wash out the rest.
    public static func levels(_ values: [Double?]) -> [Int] {
        let positive = values.compactMap { $0 }.filter { $0 > 0 }.sorted()
        guard !positive.isEmpty else { return values.map { _ in 0 } }
        // The k-th quartile's value: with four days of 10, 20, 30, 40 the cuts are 10, 20, 30, so 40 is level 4.
        let cut = (1...3).map { positive[max(0, Int((Double(positive.count) * Double($0) / 4).rounded(.up)) - 1)] }
        return values.map { value in
            guard let value, value > 0 else { return 0 }
            return 1 + cut.filter { value > $0 }.count
        }
    }

    /// A "2026-09-01" date at midnight UTC.
    static func day(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: text), formatter.string(from: date) == text else { return nil }
        return date
    }

    // MARK: - The card's own hero and status

    /// The hero drawn: the card's, else one the first limits / breakdown / bars / trend block supplies.
    public static func hero(_ card: Card, locale: Locale = .current) -> Hero? {
        if let hero = card.hero { return hero }
        for block in card.blocks {
            switch block {
            case .limits(let b): return hero(b, locale: locale)
            case .breakdown(let b): return hero(b, locale: locale)
            case .bars(let b): return hero(b, locale: locale)
            case .trend(let b): return hero(b, locale: locale)
            default: continue
            }
        }
        return nil
    }

    /// The status drawn: the card's, else one the first block that has one supplies.
    public static func status(_ card: Card, locale: Locale = .current) -> StatusText? {
        if let status = card.status { return status }
        for block in card.blocks {
            let found: StatusText? = switch block {
                case .limits(let b): status(b, locale: locale)
                case .breakdown(let b): status(b, locale: locale)
                case .bars(let b): status(b, locale: locale)
                case .trend(let b): status(b, locale: locale)
                default: nil
            }
            if let found { return found }
        }
        return nil
    }
}
