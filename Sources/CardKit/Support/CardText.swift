//
//  CardText.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  Every card as plain text, in reading order: the description a picture
//  needs for VoiceOver, what Messages can search, what to send when an image
//  won't load, and the record of what was sent. Same numbers as the picture,
//  from the same functions. A QR code's contents are left out — they can be a
//  Wi-Fi password.
//

import Foundation

public enum CardText {

    public static func text(_ card: Card, locale: Locale = .current) -> String {
        let words = Words(card.wording)
        var lines = [card.eyebrow]
        if let hero = CardMath.hero(card, locale: locale) {
            var line = ([CardMath.text(hero.value, locale: locale), hero.unit].compactMap { $0 }).joined(separator: " ")
            let tags = (hero.tags ?? []).map(\.name)
            if let label = hero.label { line += " — " + ([label] + tags.map { "(\($0))" }).joined(separator: " ") }
            lines.append(line)
            if let detail = hero.detail { lines.append(detail) }
        }
        if let status = CardMath.status(card, locale: locale) { lines.append(prefix(status.status) + status.text) }
        for block in card.blocks { lines += text(block, locale: locale, words: words) }
        if let footnote = card.footnote, !footnote.isEmpty { lines.append(footnote) }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Words for a status, since there is no icon: "Warning: " for something to act on now.
    static func prefix(_ status: Status) -> String { status == .critical ? "Warning: " : "" }

    static func text(_ block: Block, locale: Locale, words: Words) -> [String] {
        let say = { (amount: Amount, unit: String?) in CardMath.text(amount, unit: unit, whole: true, locale: locale) }
        let label = { (text: String?) in text.map { [$0 + ":"] } ?? [] }
        switch block {
        case .list(let b):
            return label(b.label) + b.rows.map { row in
                let mark = row.done.map { $0 ? "[x] " : "[ ] " } ?? (row.status == .critical ? "Warning: " : "")
                let value = row.value.map { ": " + CardMath.text($0, locale: locale) } ?? ""
                return "- " + [row.lead, mark + row.title].compactMap { $0 }.joined(separator: " ") + (row.detail.map { " (\($0))" } ?? "") + value
            }
        case .tiles(let b):
            return b.tiles.map { "\($0.label): \(CardMath.text($0.value, unit: $0.unit, whole: true, locale: locale))" + ($0.detail.map { " (\($0))" } ?? "") }
        case .breakdown(let b):
            let ordered = CardMath.ordered(b.rows)
            let shares = CardMath.shares(ordered.map { CardMath.double($0.part.value) })
            return label(b.label) + ordered.enumerated().map { index, entry in
                let change: String = switch CardMath.change(entry.part) {
                    case .up(let a): ", up \(say(a, b.unit))"
                    case .down(let a): ", down \(say(a, b.unit))"
                    case .same: ", \(words("change_same"))"
                    case nil: ""
                }
                let share = entry.part.value.value < 0 ? "" : " (\(shares[index]) %)"
                return "- \(entry.part.name): \(say(entry.part.value, b.unit))\(share)\(change)"
            }
        case .limits(let b):
            return label(b.label) + CardMath.ordered(b).map { entry in
                let over = CardMath.isOver(entry.row.value, of: entry.row.of)
                    ? " — " + words("row_over", ["amount": say(CardMath.minus(entry.row.value, entry.row.of), b.unit)]) : ""
                return "- \(entry.row.name): \(say(entry.row.value, b.unit)) " + words("of", ["total": CardMath.text(entry.row.of, whole: true, locale: locale)]) + over
            }
        case .bars(let b):
            let names = (b.legend ?? []).map(\.name)
            var lines = label(b.label) + b.bars.map { bar -> String in
                guard let total = CardMath.total(bar) else { return "- \(bar.label): —" }
                let currency = bar.value?.currency ?? bar.parts?.first?.currency
                let parts = bar.parts.map { parts in " (" + zip(names, parts).map { "\($0): \(say($1, b.unit))" }.joined(separator: ", ") + ")" } ?? ""
                return "- \(bar.label): \(say(Amount(Decimal(total), currency: currency), b.unit))\(parts)"
            }
            if let goal = b.goal { lines.append(words("legend_goal", ["amount": say(goal, b.unit)])) }
            if let band = b.band { lines.append("\(words("legend_band")): \(say(band.low, b.unit))–\(say(band.high, b.unit))") }
            return lines
        case .trend(let b):
            var lines = label(b.label) + b.series.map { series in
                let first = series.points.first!, last = series.points.last!
                return "- \(series.name): \(say(first.value, b.unit)) → \(say(last.value, b.unit))"
            }
            if let projection = CardMath.projectionText(b, locale: locale, words: words) { lines.append(projection) }
            return lines
        case .range(let b):
            return label(b.label) + b.rows.map { "- \($0.label): \(say($0.low, b.unit))–\(say($0.high, b.unit))" + ($0.detail.map { " (\($0))" } ?? "") }
        case .hourly(let b):
            return label(b.label) + [b.items.map { "\($0.label) \(CardMath.text($0.value, locale: locale))" + ($0.detail.map { " (\($0))" } ?? "") }.joined(separator: ", ")]
        case .rings(let b):
            return [b.rings.map { "\($0.label) \(say($0.value, nil)) " + words("of", ["total": say($0.of, $0.unit)]) }.joined(separator: ", ")]
        case .gauges(let b):
            return b.gauges.map { "\($0.label): \(say($0.value, $0.unit))" + ($0.detail.map { " (\($0))" } ?? "") }
        case .segmented(let b):
            let (pieces, rest) = CardMath.segments(b)
            let shares = CardMath.shares(pieces.map(\.fraction) + (rest > 0 ? [rest] : []))
            var lines = label(b.label) + pieces.enumerated().map { "- \($1.part.name): \(say($1.part.value, b.unit)) (\(shares[$0]) %)" }
            if rest > 0, let of = b.of {
                lines.append("- \(b.restLabel ?? words("free")): \(say(CardMath.minus(of, CardMath.sum(b.parts.map(\.value)) ?? Amount(0)), b.unit)) (\(shares.last ?? 0) %)")
            }
            return lines
        case .timeline(let b):
            let names = Dictionary((b.legend ?? []).enumerated().map { (CardMath.slots((b.legend ?? []).map(\.slot))[$0.offset], $0.element.name) },
                                   uniquingKeysWith: { a, _ in a })
            return label(b.label) + b.items.map { item in
                let when = CardMath.timeText(item.from, scale: b.scale) + (item.to.map { "–" + CardMath.timeText($0, scale: b.scale) } ?? "")
                return "- \(when) \(item.title ?? names[item.slot ?? 1] ?? "")".trimmingCharacters(in: .whitespaces)
            }
        case .heatmap(let b):
            let active = b.values.compactMap { $0 }.filter { $0 > 0 }.count
            return label(b.label) + ["\(active) of \(b.values.count) days from \(b.start)"]
        case .sparklines(let b):
            return label(b.label) + b.rows.map { row in
                "- \(row.title): \(CardMath.text(row.value, locale: locale))" + (row.change.map { " (\(CardMath.percentChange($0, locale: locale)))" } ?? "")
            }
        case .chips(let b):
            let certain = b.chips.filter { $0.maybe != true }, maybe = b.chips.filter { $0.maybe == true }
            let name = { (chip: Chip) in chip.status == .critical ? chip.text.uppercased() : chip.text }
            var line = certain.map(name).joined(separator: ", ")
            if !maybe.isEmpty { line += (line.isEmpty ? "" : "; ") + "maybe " + maybe.map(name).joined(separator: ", ") }
            return [(b.label.map { $0 + ": " } ?? "") + line]
        case .comparison(let b):
            return b.options.map { option in
                "- \(option.name): \(CardMath.text(option.value, unit: option.unit, whole: true, locale: locale))" + (option.detail.map { ", \($0)" } ?? "")
                    + (option.best == true ? " (the pick)" : "")
            } + (b.reason.map { [$0] } ?? [])
        case .table(let b):
            return label(b.label) + [b.columns.map(\.title).joined(separator: " · ")]
                + b.rows.map { $0.map { CardMath.text($0, locale: locale) }.joined(separator: " · ") }
        case .score(let b):
            return ["\(b.home.name) \(b.home.score)–\(b.away.score) \(b.away.name) (\(b.state))"] + (b.detail.map { [$0] } ?? [])
        case .text(let b):
            return label(b.label) + (b.text.map { [b.quote == true ? "“\($0)”" : $0] } ?? []) + (b.bullets ?? []).map { "- " + $0 }
        case .images(let b):
            let captions = b.images.compactMap(\.caption)
            return ["\(b.images.count) \(b.images.count == 1 ? "picture" : "pictures")" + (captions.isEmpty ? "" : ": " + captions.joined(separator: ", "))]
        case .award(let b):
            return ["Award: \(b.title)" + (b.record.map { " — \($0)" } ?? "")] + (b.detail.map { [$0] } ?? [])
                + (b.date.map { [words("earned", ["date": $0])] } ?? [])
        case .awards(let b):
            let earned = b.awards.filter(\.earned).map(\.title)
            let next = b.awards.filter { !$0.earned }.map { award in
                award.title + (award.progress.flatMap { p in award.of.map { " (\(say(p, nil)) " + words("of", ["total": say($0, nil)]) + ")" } } ?? "")
            }
            return label(b.label) + (earned.isEmpty ? [] : ["Earned: " + earned.joined(separator: ", ")]) + (next.isEmpty ? [] : ["Still to earn: " + next.joined(separator: ", ")])
        case .tracker(let b):
            let states = CardMath.states(b)
            let mark = ["done": "[done] ", "current": "[now] ", "upcoming": "[next] ", "failed": "[failed] "]
            return label(b.label) + b.steps.enumerated().map { index, step in
                "- " + (mark[states[index]] ?? "") + step.title + (step.time.map { ", \($0)" } ?? "") + (step.detail.map { " (\($0))" } ?? "")
            }
        case .map(let b):
            let titles = b.pins.compactMap(\.title)
            return ["Map" + (titles.isEmpty ? "" : ": " + titles.joined(separator: ", "))]
        case .qr(let b):
            return ["QR code" + (b.title.map { ": \($0)" } ?? "")]
        case .pair(let b):
            return ["\(b.before.caption ?? words("before")) and \(b.after.caption ?? words("after")) pictures"]
        case .month(let b):
            let days = b.days.map(\.day).sorted().map(String.init).joined(separator: ", ")
            return ["\(CardMath.monthTitle(b.month, locale: locale) ?? b.month): marked \(days.isEmpty ? "none" : days)"]
        }
    }
}
