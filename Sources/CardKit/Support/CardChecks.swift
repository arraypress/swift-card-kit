//
//  CardChecks.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  Why a card cannot be drawn, naming the field: "blocks[2].rows[0].of has
//  more decimals than GBP has". A card that passes draws; one that fails
//  draws nothing, so a picture is never wrong in a way nobody was told about.
//

import AppKit
import Foundation

public enum CardChecks {

    /// Limits that keep a card phone-sized.
    public static let maxBlocks = 8, maxRows = 8, maxListRows = 8, maxTiles = 4, maxBars = 31, maxHourly = 8
    public static let maxSeries = 3, maxGauges = 4, maxRings = 4, maxChips = 40, maxTableRows = 20, maxImages = 12

    /// The first problem with a card, or nil when it draws.
    public static func problem(_ card: Card) -> String? {
        if let issue = text(card.eyebrow, "eyebrow") { return issue }
        guard (1...maxBlocks).contains(card.blocks.count) else { return "blocks: give 1 to \(maxBlocks) (got \(card.blocks.count))" }
        if let hero = card.hero {
            if let symbol = hero.symbol, let issue = sfSymbol(symbol, "hero.symbol") { return issue }
            if let tags = hero.tags { for (i, tag) in tags.enumerated() { if let issue = slot(tag.slot, "hero.tags[\(i)].slot") { return issue } } }
            if case .amount(let amount) = hero.value, let issue = money([(amount, "hero.value")]) { return issue }
        }
        for (index, block) in card.blocks.enumerated() {
            if let issue = problem(block, at: "blocks[\(index)]") { return issue }
        }
        return problem(wording: card.wording)
    }

    /// Each replaced phrase must exist and use only the placeholders its English does (a misspelt id would
    /// otherwise be ignored, and a misspelt placeholder printed as "{amout}").
    static func problem(wording: [String: String]?) -> String? {
        for (id, phrase) in (wording ?? [:]).sorted(by: { $0.key < $1.key }) {
            guard let english = Words.english[id] else { return "wording.\(id): no such phrase (card words lists them)" }
            let unknown = Words.placeholders(phrase).subtracting(Words.placeholders(english))
            if let name = unknown.sorted().first { return "wording.\(id): {\(name)} isn't one of its placeholders (\(english))" }
        }
        return nil
    }

    static func problem(_ block: Block, at p: String) -> String? {
        switch block {
        case .list(let b):
            guard (1...maxListRows).contains(b.rows.count) else { return "\(p).rows: give 1 to \(maxListRows) (got \(b.rows.count))" }
            for (i, row) in b.rows.enumerated() {
                if let issue = text(row.title, "\(p).rows[\(i)].title") ?? row.symbol.flatMap({ sfSymbol($0, "\(p).rows[\(i)].symbol") }) { return issue }
            }
            return money(b.rows.enumerated().compactMap { i, row in amount(row.value).map { ($0, "\(p).rows[\(i)].value") } }, mixed: true)

        case .tiles(let b):
            guard (1...maxTiles).contains(b.tiles.count) else { return "\(p).tiles: give 1 to \(maxTiles) (got \(b.tiles.count))" }
            for (i, tile) in b.tiles.enumerated() {
                if let issue = text(tile.label, "\(p).tiles[\(i)].label") ?? tile.symbol.flatMap({ sfSymbol($0, "\(p).tiles[\(i)].symbol") }) { return issue }
            }
            return money(b.tiles.enumerated().compactMap { i, tile in amount(tile.value).map { ($0, "\(p).tiles[\(i)].value") } }, mixed: true)

        case .breakdown(let b):
            if let issue = parts(b.rows, at: "\(p).rows") { return issue }
            var amounts = b.rows.enumerated().flatMap { i, row in [(row.value, "\(p).rows[\(i)].value")] + (row.previous.map { [($0, "\(p).rows[\(i)].previous")] } ?? []) }
            if let reference = b.reference { amounts.append((reference.value, "\(p).reference.value")) }
            return money(amounts)

        case .limits(let b):
            guard (1...maxRows).contains(b.rows.count) else { return "\(p).rows: give 1 to \(maxRows) (got \(b.rows.count)); fold the rest into one row" }
            if let order = b.order, !["fullest", "given"].contains(order) { return "\(p).order: '\(order)' is not fullest or given" }
            if let days = b.daysLeft, days < 0 { return "\(p).days_left is negative" }
            for (i, row) in b.rows.enumerated() { if let issue = text(row.name, "\(p).rows[\(i)].name") { return issue } }
            if let issue = slots(b.rows.map(\.slot), at: "\(p).rows") { return issue }
            var amounts = b.rows.enumerated().flatMap { i, row in [(row.value, "\(p).rows[\(i)].value"), (row.of, "\(p).rows[\(i)].of")] }
            if let total = b.total { amounts.append((total, "\(p).total")) }
            if let spent = b.spent { amounts.append((spent, "\(p).spent")) }
            return negative(amounts.filter { $0.1 != "\(p).spent" }) ?? money(amounts)

        case .bars(let b):
            guard (1...maxBars).contains(b.bars.count) else { return "\(p).bars: give 1 to \(maxBars) (got \(b.bars.count))" }
            if let h = b.highlight, !b.bars.indices.contains(h) { return "\(p).highlight: \(h) is not a bar (0–\(b.bars.count - 1))" }
            let stacked = b.bars.contains { $0.parts != nil }
            if stacked {
                guard let legend = b.legend, !legend.isEmpty else { return "\(p).legend: name the stacked parts" }
                for (i, bar) in b.bars.enumerated() where bar.parts != nil && bar.parts!.count != legend.count {
                    return "\(p).bars[\(i)].parts: \(bar.parts!.count) parts but the legend names \(legend.count)"
                }
                if let issue = slots(legend.map(\.slot), at: "\(p).legend") { return issue }
            }
            var amounts: [(Amount, String)] = []
            for (i, bar) in b.bars.enumerated() {
                if let value = bar.value { amounts.append((value, "\(p).bars[\(i)].value")) }
                for (j, part) in (bar.parts ?? []).enumerated() { amounts.append((part, "\(p).bars[\(i)].parts[\(j)]")) }
            }
            if let goal = b.goal { amounts.append((goal, "\(p).goal")) }
            if let band = b.band {
                if band.low.value > band.high.value { return "\(p).band: low is above high" }
                amounts += [(band.low, "\(p).band.low"), (band.high, "\(p).band.high")]
            }
            return negative(amounts) ?? money(amounts)

        case .trend(let b):
            guard (1...maxSeries).contains(b.series.count) else { return "\(p).series: give 1 to \(maxSeries) (got \(b.series.count))" }
            var amounts: [(Amount, String)] = b.target.map { [($0.value, "\(p).target.value")] } ?? []
            for (s, series) in b.series.enumerated() {
                guard !series.points.isEmpty else { return "\(p).series[\(s)].points is empty" }
                for (i, point) in series.points.enumerated() {
                    guard point.x.isFinite else { return "\(p).series[\(s)].points[\(i)].x is not a number" }
                    if i > 0, point.x <= series.points[i - 1].x { return "\(p).series[\(s)].points: x must go up (\(point.x) after \(series.points[i - 1].x))" }
                    amounts.append((point.value, "\(p).series[\(s)].points[\(i)].value"))
                }
            }
            if let end = b.end, let last = b.series.flatMap(\.points).map(\.x).max(), end < last { return "\(p).end: \(end) is before the last point (\(last))" }
            if let smooth = b.smooth, smooth < 1 { return "\(p).smooth must be 1 or more" }
            return money(amounts)

        case .range(let b):
            guard (1...10).contains(b.rows.count) else { return "\(p).rows: give 1 to 10 (got \(b.rows.count))" }
            if let style = b.style, !["temperature", "slot"].contains(style) { return "\(p).style: '\(style)' is not temperature or slot" }
            for (i, row) in b.rows.enumerated() {
                if row.low.value > row.high.value { return "\(p).rows[\(i)]: low is above high" }
                if let symbol = row.symbol, let issue = sfSymbol(symbol, "\(p).rows[\(i)].symbol") { return issue }
            }
            return money(b.rows.enumerated().flatMap { i, row in [(row.low, "\(p).rows[\(i)].low"), (row.high, "\(p).rows[\(i)].high")] })

        case .hourly(let b):
            guard (1...maxHourly).contains(b.items.count) else { return "\(p).items: give 1 to \(maxHourly) (got \(b.items.count))" }
            for (i, item) in b.items.enumerated() { if let symbol = item.symbol, let issue = sfSymbol(symbol, "\(p).items[\(i)].symbol") { return issue } }
            return nil

        case .rings(let b):
            guard (1...maxRings).contains(b.rings.count) else { return "\(p).rings: give 1 to \(maxRings) (got \(b.rings.count))" }
            if let style = b.style, !["row", "concentric"].contains(style) { return "\(p).style: '\(style)' is not row or concentric" }
            if let issue = slots(b.rings.map(\.slot), at: "\(p).rings") { return issue }
            let amounts = b.rings.enumerated().flatMap { i, ring in [(ring.value, "\(p).rings[\(i)].value"), (ring.of, "\(p).rings[\(i)].of")] }
            for (i, ring) in b.rings.enumerated() where ring.of.value <= 0 { return "\(p).rings[\(i)].of must be above zero" }
            return negative(amounts) ?? money(amounts, mixed: true)

        case .gauges(let b):
            guard (1...maxGauges).contains(b.gauges.count) else { return "\(p).gauges: give 1 to \(maxGauges) (got \(b.gauges.count))" }
            for (i, gauge) in b.gauges.enumerated() {
                if gauge.of.value <= 0 { return "\(p).gauges[\(i)].of must be above zero" }
                if let symbol = gauge.symbol, let issue = sfSymbol(symbol, "\(p).gauges[\(i)].symbol") { return issue }
            }
            return money(b.gauges.enumerated().flatMap { i, g in [(g.value, "\(p).gauges[\(i)].value"), (g.of, "\(p).gauges[\(i)].of")] }, mixed: true)

        case .segmented(let b):
            if let issue = parts(b.parts, at: "\(p).parts") { return issue }
            var amounts = b.parts.enumerated().map { i, part in (part.value, "\(p).parts[\(i)].value") }
            if let of = b.of { amounts.append((of, "\(p).of")) }
            return negative(amounts) ?? money(amounts)

        case .timeline(let b):
            guard b.end > b.start else { return "\(p): end must be after start" }
            guard (1...24).contains(b.items.count) else { return "\(p).items: give 1 to 24 (got \(b.items.count))" }
            if let scale = b.scale, !["hours", "seconds", "plain"].contains(scale) { return "\(p).scale: '\(scale)' is not hours, seconds or plain" }
            if let layout = b.layout, !["horizontal", "vertical"].contains(layout) { return "\(p).layout: '\(layout)' is not horizontal or vertical" }
            for (i, item) in b.items.enumerated() {
                if item.from < b.start || (item.to ?? item.from) > b.end { return "\(p).items[\(i)] is outside \(b.start)–\(b.end)" }
                if let to = item.to, to < item.from { return "\(p).items[\(i)]: to is before from" }
                if let issue = slot(item.slot, "\(p).items[\(i)].slot") { return issue }
            }
            return nil

        case .heatmap(let b):
            guard CardMath.day(b.start) != nil else { return "\(p).start: '\(b.start)' is not a YYYY-MM-DD date" }
            guard (1...371).contains(b.values.count) else { return "\(p).values: give 1 to 371 days (got \(b.values.count))" }
            return b.values.contains { ($0 ?? 0) < 0 } ? "\(p).values: a day is negative" : nil

        case .sparklines(let b):
            guard (1...maxRows).contains(b.rows.count) else { return "\(p).rows: give 1 to \(maxRows) (got \(b.rows.count))" }
            for (i, row) in b.rows.enumerated() where row.points.count < 2 { return "\(p).rows[\(i)].points: give 2 or more" }
            return nil

        case .chips(let b):
            guard (1...maxChips).contains(b.chips.count) else { return "\(p).chips: give 1 to \(maxChips) (got \(b.chips.count))" }
            for (i, chip) in b.chips.enumerated() {
                if let issue = text(chip.text, "\(p).chips[\(i)].text") ?? slot(chip.slot, "\(p).chips[\(i)].slot") { return issue }
            }
            return nil

        case .comparison(let b):
            guard b.options.count == 2 else { return "\(p).options: give two (got \(b.options.count))" }
            guard b.options.filter({ $0.best == true }).count <= 1 else { return "\(p).options: at most one is best" }
            return money(b.options.enumerated().compactMap { i, o in amount(o.value).map { ($0, "\(p).options[\(i)].value") } })

        case .table(let b):
            guard (1...6).contains(b.columns.count) else { return "\(p).columns: give 1 to 6 (got \(b.columns.count))" }
            guard (1...maxTableRows).contains(b.rows.count) else { return "\(p).rows: give 1 to \(maxTableRows) (got \(b.rows.count))" }
            for (i, row) in b.rows.enumerated() where row.count != b.columns.count {
                return "\(p).rows[\(i)]: \(row.count) cells for \(b.columns.count) columns"
            }
            for (i, column) in b.columns.enumerated() {
                if let align = column.align, !["leading", "trailing"].contains(align) { return "\(p).columns[\(i)].align: '\(align)' is not leading or trailing" }
            }
            if let h = b.highlight, !b.rows.indices.contains(h) { return "\(p).highlight: \(h) is not a row" }
            return money(b.rows.enumerated().flatMap { i, row in row.enumerated().compactMap { j, cell in amount(cell).map { ($0, "\(p).rows[\(i)][\(j)]") } } }, mixed: true)

        case .score(let b):
            return text(b.home.name, "\(p).home.name") ?? text(b.away.name, "\(p).away.name") ?? text(b.state, "\(p).state")

        case .text(let b):
            if (b.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty && (b.bullets ?? []).isEmpty { return "\(p): give text or bullets" }
            return nil

        case .award(let b):
            return text(b.title, "\(p).title") ?? sfSymbol(b.symbol, "\(p).symbol") ?? tier(b.tier, "\(p).tier") ?? slot(b.slot, "\(p).slot")

        case .awards(let b):
            guard (1...12).contains(b.awards.count) else { return "\(p).awards: give 1 to 12 (got \(b.awards.count))" }
            for (i, award) in b.awards.enumerated() {
                let at = "\(p).awards[\(i)]"
                if let issue = text(award.title, "\(at).title") ?? sfSymbol(award.symbol, "\(at).symbol") ?? tier(award.tier, "\(at).tier")
                    ?? slot(award.slot, "\(at).slot") { return issue }
                if award.progress != nil, (award.of?.value ?? 0) <= 0 { return "\(at): progress needs an of above zero" }
                if let progress = award.progress, progress.value < 0 { return "\(at).progress is negative" }
            }
            return nil

        case .tracker(let b):
            guard (2...8).contains(b.steps.count) else { return "\(p).steps: give 2 to 8 (got \(b.steps.count))" }
            for (i, step) in b.steps.enumerated() {
                if let issue = text(step.title, "\(p).steps[\(i)].title") { return issue }
                if let state = step.state, !["done", "current", "upcoming", "failed"].contains(state) {
                    return "\(p).steps[\(i)].state: '\(state)' is not done, current, upcoming or failed"
                }
            }
            return b.steps.filter { $0.state == "current" }.count > 1 ? "\(p).steps: at most one is current" : nil

        case .map(let b):
            guard b.pins.count <= 8 else { return "\(p).pins: at most 8 (got \(b.pins.count))" }
            guard !b.pins.isEmpty || (b.route?.count ?? 0) >= 2 else { return "\(p): give pins, or a route of two points or more" }
            for (i, pin) in b.pins.enumerated() {
                if let issue = coordinate(pin.lat, pin.lon, "\(p).pins[\(i)]") ?? slot(pin.slot, "\(p).pins[\(i)].slot") { return issue }
            }
            for (i, point) in (b.route ?? []).enumerated() { if let issue = coordinate(point.lat, point.lon, "\(p).route[\(i)]") { return issue } }
            if let height = b.height, !(120...320).contains(height) { return "\(p).height: give 120 to 320 points" }
            return nil

        case .qr(let b):
            guard !b.payload.isEmpty else { return "\(p).payload is empty" }
            return b.payload.utf8.count > 1000 ? "\(p).payload: at most 1,000 bytes, so the code stays scannable on a phone" : nil

        case .pair(let b):
            for (name, picture) in [("before", b.before), ("after", b.after)]
                where NSImage(contentsOfFile: (picture.path as NSString).expandingTildeInPath) == nil {
                return "\(p).\(name).path: no readable image at \(picture.path)"
            }
            return nil

        case .month(let b):
            guard let length = CardMath.monthLength(b.month) else { return "\(p).month: '\(b.month)' is not a YYYY-MM month" }
            var seen = Set<Int>()
            for (i, day) in b.days.enumerated() {
                guard (1...length).contains(day.day) else { return "\(p).days[\(i)].day: \(day.day) is not in \(b.month)" }
                guard seen.insert(day.day).inserted else { return "\(p).days[\(i)]: day \(day.day) is marked twice" }
                if let issue = slot(day.slot, "\(p).days[\(i)].slot") { return issue }
            }
            if let today = b.today, !(1...length).contains(today) { return "\(p).today: \(today) is not in \(b.month)" }
            return b.legend.flatMap { slots($0.map(\.slot), at: "\(p).legend") }

        case .images(let b):
            guard (1...maxImages).contains(b.images.count) else { return "\(p).images: give 1 to \(maxImages) (got \(b.images.count))" }
            if let columns = b.columns, !(1...4).contains(columns) { return "\(p).columns: give 1 to 4" }
            for (i, picture) in b.images.enumerated() where NSImage(contentsOfFile: (picture.path as NSString).expandingTildeInPath) == nil {
                return "\(p).images[\(i)].path: no readable image at \(picture.path)"
            }
            return nil
        }
    }

    // MARK: - Pieces

    private static func amount(_ shown: Shown?) -> Amount? {
        if case .amount(let a)? = shown { return a }
        return nil
    }

    private static func text(_ value: String, _ path: String) -> String? {
        value.trimmingCharacters(in: .whitespaces).isEmpty ? "\(path) is empty" : nil
    }

    private static func tier(_ value: String?, _ path: String) -> String? {
        guard let value else { return nil }
        return ["gold", "silver", "bronze"].contains(value) ? nil : "\(path): '\(value)' is not gold, silver or bronze"
    }

    private static func coordinate(_ lat: Double, _ lon: Double, _ path: String) -> String? {
        guard (-90...90).contains(lat), (-180...180).contains(lon) else { return "\(path): \(lat), \(lon) is not a place on Earth" }
        return nil
    }

    private static func slot(_ value: Int?, _ path: String) -> String? {
        guard let value else { return nil }
        return (1...8).contains(value) ? nil : "\(path): \(value) is not a palette slot (1–8)"
    }

    /// An SF Symbol that exists on this Mac.
    static func sfSymbol(_ name: String, _ path: String) -> String? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil ? "\(path): no SF Symbol named '\(name)'" : nil
    }

    private static func parts(_ parts: [Part], at path: String) -> String? {
        guard (1...maxRows).contains(parts.count) else { return "\(path): give 1 to \(maxRows) (got \(parts.count)); fold the rest into one \"Other\"" }
        for (i, part) in parts.enumerated() { if let issue = text(part.name, "\(path)[\(i)].name") { return issue } }
        return slots(parts.map(\.slot), at: path)
    }

    /// Slots in range, and no two parts sharing one — they would look like the same thing.
    static func slots(_ given: [Int?], at path: String) -> String? {
        for (i, value) in given.enumerated() { if let issue = slot(value, "\(path)[\(i)].slot") { return issue } }
        var seen: [Int: Int] = [:]
        for (i, value) in CardMath.slots(given).enumerated() {
            if let first = seen[value] { return "\(path)[\(i)] has the same colour slot (\(value)) as \(path)[\(first)]" }
            seen[value] = i
        }
        return nil
    }

    private static func negative(_ amounts: [(Amount, String)]) -> String? {
        amounts.first { $0.0.value < 0 }.map { "\($0.1) is negative" }
    }

    /// Money exact to its currency's smallest unit, a real ISO code, one currency per block, and (unless a block
    /// may mix, like a list of a bill beside a temperature) never money beside plain numbers.
    static func money(_ amounts: [(Amount, String)], mixed: Bool = false) -> String? {
        for (amount, path) in amounts {
            guard let currency = amount.currency else { continue }
            if !Currencies.isCode(currency) { return "\(path): '\(currency)' is not an ISO 4217 currency code" }
            var scaled = amount.value * pow(10, Currencies.exponent(currency)), rounded = Decimal()
            NSDecimalRound(&rounded, &scaled, 0, .plain)
            if rounded != scaled { return "\(path): \(CardMath.plain(amount.value)) has more decimals than \(currency) has" }
        }
        let currencies = Set(amounts.compactMap(\.0.currency))
        if currencies.count > 1 { return "amounts mix \(currencies.sorted().joined(separator: " and ")): draw one card per currency" }
        if !mixed, let code = currencies.first, let plain = amounts.first(where: { $0.0.currency == nil }) {
            return "\(plain.1) is a plain number beside \(code) amounts"
        }
        return nil
    }
}
