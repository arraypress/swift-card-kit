//
//  Card.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  A card is one shape for every subject: an eyebrow (what · when), an
//  optional hero (the one number that answers the question), an optional
//  status line, any number of blocks, and a footnote (where the numbers came
//  from). Blocks are the visual forms — lists, tiles, bars over time, rings,
//  gauges, timelines… — so a weather brief, a budget and a disk report are
//  the same parts in a different order.
//

import Foundation

public struct Card: Codable, Equatable, Sendable {
    public var eyebrow: String
    public var hero: Hero?
    /// Without one, a limits / breakdown / bars / trend block supplies its own (left, vs last time, vs average).
    public var status: StatusText?
    public var blocks: [Block]
    public var footnote: String?

    public init(eyebrow: String, hero: Hero? = nil, status: StatusText? = nil, blocks: [Block], footnote: String? = nil) {
        self.eyebrow = eyebrow; self.hero = hero; self.status = status; self.blocks = blocks; self.footnote = footnote
    }
}

/// The one number that answers the card's question.
public struct Hero: Codable, Equatable, Sendable {
    public var value: Shown
    /// Beside it, smaller: "kcal", "left of £1,800", "high 16 · low 8".
    public var unit: String?
    /// A title line under it: "Corner Café".
    public var label: String?
    /// A quieter line: "Dry until 3 pm, then showers".
    public var detail: String?
    /// An SF Symbol drawn in its own colours beside the number: "cloud.sun.rain.fill", "moonphase.waxing.gibbous".
    public var symbol: String?
    /// Tags after the label: a category.
    public var tags: [Tag]?

    public init(value: Shown, unit: String? = nil, label: String? = nil, detail: String? = nil, symbol: String? = nil, tags: [Tag]? = nil) {
        self.value = value; self.unit = unit; self.label = label; self.detail = detail; self.symbol = symbol; self.tags = tags
    }
}

/// A value shown as given: words ("14°", "Tue", "FT"), or an amount to format.
public enum Shown: Codable, Equatable, Sendable {
    case text(String)
    case amount(Amount)

    public init(from decoder: any Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) { self = .text(text) } else { self = .amount(try Amount(from: decoder)) }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .text(let text): var single = encoder.singleValueContainer(); try single.encode(text)
        case .amount(let amount): try amount.encode(to: encoder)
        }
    }
}

/// A status in words, drawn with its icon and colour.
public struct StatusText: Codable, Equatable, Sendable {
    public var status: Status
    public var text: String
    public init(status: Status, text: String) { self.status = status; self.text = text }
}

/// A named part with its colour: a category, a series.
public struct Tag: Codable, Equatable, Sendable {
    public var name: String
    /// Palette slot 1–8. The same part takes the same slot on every card; without one, its position.
    public var slot: Int?
    public init(name: String, slot: Int? = nil) { self.name = name; self.slot = slot }
}

// MARK: - Blocks

/// One visual form. In JSON, an object with a `type`: {"type": "list", …}.
public enum Block: Codable, Equatable, Sendable {
    case list(ListBlock), tiles(TilesBlock), breakdown(BreakdownBlock), limits(LimitsBlock), bars(BarsBlock)
    case trend(TrendBlock), range(RangeBlock), hourly(HourlyBlock), rings(RingsBlock), gauges(GaugesBlock)
    case segmented(SegmentedBlock), timeline(TimelineBlock), heatmap(HeatmapBlock), sparklines(SparklinesBlock)
    case chips(ChipsBlock), comparison(ComparisonBlock), table(TableBlock), score(ScoreBlock), text(TextBlock)
    case images(ImagesBlock)

    /// Every type name, as written in JSON.
    public static let types = ["list", "tiles", "breakdown", "limits", "bars", "trend", "range", "hourly", "rings", "gauges",
                               "segmented", "timeline", "heatmap", "sparklines", "chips", "comparison", "table", "score",
                               "text", "images"]

    public var type: String {
        switch self {
        case .list: "list"
        case .tiles: "tiles"
        case .breakdown: "breakdown"
        case .limits: "limits"
        case .bars: "bars"
        case .trend: "trend"
        case .range: "range"
        case .hourly: "hourly"
        case .rings: "rings"
        case .gauges: "gauges"
        case .segmented: "segmented"
        case .timeline: "timeline"
        case .heatmap: "heatmap"
        case .sparklines: "sparklines"
        case .chips: "chips"
        case .comparison: "comparison"
        case .table: "table"
        case .score: "score"
        case .text: "text"
        case .images: "images"
        }
    }

    private enum Keys: String, CodingKey { case type }

    public init(from decoder: any Decoder) throws {
        let type = try decoder.container(keyedBy: Keys.self).decode(String.self, forKey: .type)
        switch type {
        case "list": self = .list(try ListBlock(from: decoder))
        case "tiles": self = .tiles(try TilesBlock(from: decoder))
        case "breakdown": self = .breakdown(try BreakdownBlock(from: decoder))
        case "limits": self = .limits(try LimitsBlock(from: decoder))
        case "bars": self = .bars(try BarsBlock(from: decoder))
        case "trend": self = .trend(try TrendBlock(from: decoder))
        case "range": self = .range(try RangeBlock(from: decoder))
        case "hourly": self = .hourly(try HourlyBlock(from: decoder))
        case "rings": self = .rings(try RingsBlock(from: decoder))
        case "gauges": self = .gauges(try GaugesBlock(from: decoder))
        case "segmented": self = .segmented(try SegmentedBlock(from: decoder))
        case "timeline": self = .timeline(try TimelineBlock(from: decoder))
        case "heatmap": self = .heatmap(try HeatmapBlock(from: decoder))
        case "sparklines": self = .sparklines(try SparklinesBlock(from: decoder))
        case "chips": self = .chips(try ChipsBlock(from: decoder))
        case "comparison": self = .comparison(try ComparisonBlock(from: decoder))
        case "table": self = .table(try TableBlock(from: decoder))
        case "score": self = .score(try ScoreBlock(from: decoder))
        case "text": self = .text(try TextBlock(from: decoder))
        case "images": self = .images(try ImagesBlock(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: try decoder.container(keyedBy: Keys.self),
                                                   debugDescription: "'\(type)' is not a block type (\(Block.types.joined(separator: ", ")))")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var keyed = encoder.container(keyedBy: Keys.self)
        try keyed.encode(type, forKey: .type)
        switch self {
        case .list(let b): try b.encode(to: encoder)
        case .tiles(let b): try b.encode(to: encoder)
        case .breakdown(let b): try b.encode(to: encoder)
        case .limits(let b): try b.encode(to: encoder)
        case .bars(let b): try b.encode(to: encoder)
        case .trend(let b): try b.encode(to: encoder)
        case .range(let b): try b.encode(to: encoder)
        case .hourly(let b): try b.encode(to: encoder)
        case .rings(let b): try b.encode(to: encoder)
        case .gauges(let b): try b.encode(to: encoder)
        case .segmented(let b): try b.encode(to: encoder)
        case .timeline(let b): try b.encode(to: encoder)
        case .heatmap(let b): try b.encode(to: encoder)
        case .sparklines(let b): try b.encode(to: encoder)
        case .chips(let b): try b.encode(to: encoder)
        case .comparison(let b): try b.encode(to: encoder)
        case .table(let b): try b.encode(to: encoder)
        case .score(let b): try b.encode(to: encoder)
        case .text(let b): try b.encode(to: encoder)
        case .images(let b): try b.encode(to: encoder)
        }
    }
}

/// `list`: rows of things — an agenda, bills, a checklist (rows with `done`).
public struct ListBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var rows: [Row]
}

public struct Row: Codable, Equatable, Sendable {
    /// A time or short label in the leading column: "10:00".
    public var lead: String?
    /// An SF Symbol; without one, the status's icon, or a checkbox when `done` is set.
    public var symbol: String?
    public var status: Status?
    public var title: String
    public var detail: String?
    public var value: Shown?
    /// A checklist row: true ticked, false open.
    public var done: Bool?
}

/// `tiles`: two to four small figures side by side.
public struct TilesBlock: Codable, Equatable, Sendable {
    public var tiles: [Tile]
}

public struct Tile: Codable, Equatable, Sendable {
    public var label: String
    public var value: Shown
    /// After a plain number: "kcal", "%".
    public var unit: String?
    public var detail: String?
    public var status: Status?
    public var symbol: String?
}

/// `breakdown`: a total split into parts, largest first, each with its share and change since last time.
public struct BreakdownBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var rows: [Part]
    public var unit: String?
    /// The total to compare with: "September by now".
    public var reference: Reference?
}

public struct Part: Codable, Equatable, Sendable {
    public var name: String
    public var value: Amount
    /// The same part last time: drawn ↑ £40, ↓ £31, = same.
    public var previous: Amount?
    public var slot: Int?
}

public struct Reference: Codable, Equatable, Sendable {
    public var value: Amount
    public var label: String
}

/// `limits`: each part against its limit, nearest first — budgets, daily targets.
public struct LimitsBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var rows: [LimitRow]
    /// The overall limit; without it, the rows' limits added up.
    public var total: Amount?
    /// Days left in the period: "about £68 a day".
    public var daysLeft: Int?
    public var unit: String?
    /// "fullest" (default) or "given".
    public var order: String?
}

public struct LimitRow: Codable, Equatable, Sendable {
    public var name: String
    public var value: Amount
    public var of: Amount
    public var slot: Int?
}

/// `bars`: one bar per period (Health-style), the latest highlighted; optional goal line, target band and average.
/// Stacked when each bar has `parts` (Screen Time-style), named by `legend`.
public struct BarsBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var bars: [Bar]
    public var unit: String?
    public var goal: Amount?
    /// A band to land in: ±10 % of a target.
    public var band: Band?
    /// A dashed line at the bars' average.
    public var average: Bool?
    /// The bar to draw strong (default: the last); others are drawn lighter.
    public var highlight: Int?
    /// The stack's parts, in the order of each bar's `parts`.
    public var legend: [Tag]?
}

public struct Bar: Codable, Equatable, Sendable {
    /// Under the bar: "Mon", "W42", "Oct".
    public var label: String
    /// Missing: not logged — an empty slot, left out of the average.
    public var value: Amount?
    public var parts: [Amount]?
}

public struct Band: Codable, Equatable, Sendable {
    public var low: Amount
    public var high: Amount
}

/// `trend`: lines over a period — the first series highlighted, up to two behind it; optional target pace and
/// a moving average.
public struct TrendBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var series: [Series]
    /// Reach `value` by x = `at`: a dashed pace line from zero (running totals).
    public var target: Target?
    /// Where the x axis ends (31 for a month).
    public var end: Double?
    public var unit: String?
    /// Fill under the first series.
    public var area: Bool?
    /// Draw an n-point moving average of the first series instead of joining its points (weight, sleep).
    public var smooth: Int?
    /// Labels for x values, e.g. {"1": "1 Oct"}; otherwise the numbers.
    public var xLabels: [String: String]?
}

public struct Series: Codable, Equatable, Sendable {
    public var name: String
    public var points: [Point]
}

public struct Point: Codable, Equatable, Sendable {
    public var x: Double
    public var value: Amount
}

public struct Target: Codable, Equatable, Sendable {
    public var value: Amount
    public var at: Double
    public var label: String?
}

/// `range`: a low–high bar per row on one shared scale (Weather's ten days, heart-rate ranges, sunrise–sunset).
public struct RangeBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var rows: [RangeRow]
    public var unit: String?
    /// "temperature" colours each bar from cool to warm along the scale; otherwise the first slot.
    public var style: String?
    /// A dot on the first row's bar: the value right now.
    public var now: Amount?
}

public struct RangeRow: Codable, Equatable, Sendable {
    public var label: String
    public var low: Amount
    public var high: Amount
    public var symbol: String?
    public var detail: String?
}

/// `hourly`: a strip of small columns — an hour, an icon, a value (Weather-style).
public struct HourlyBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var items: [HourlyItem]
}

public struct HourlyItem: Codable, Equatable, Sendable {
    public var label: String
    public var symbol: String?
    public var value: Shown
    public var detail: String?
}

/// `rings`: progress to goals, side by side or concentric (Activity-style).
public struct RingsBlock: Codable, Equatable, Sendable {
    public var rings: [Ring]
    /// "row" (default) or "concentric".
    public var style: String?
}

public struct Ring: Codable, Equatable, Sendable {
    public var label: String
    public var value: Amount
    public var of: Amount
    public var unit: String?
    public var slot: Int?
}

/// `gauges`: one to four dials — battery, disk, signal, air quality.
public struct GaugesBlock: Codable, Equatable, Sendable {
    public var gauges: [Dial]
}

public struct Dial: Codable, Equatable, Sendable {
    public var label: String
    public var value: Amount
    /// The top of the scale (100 for a percent).
    public var of: Amount
    public var unit: String?
    /// Colours the dial; without it, the first slot.
    public var status: Status?
    public var symbol: String?
    public var detail: String?
}

/// `segmented`: one bar split into parts with a legend (iPhone Storage-style); with `of`, the rest is drawn free.
public struct SegmentedBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var parts: [Part]
    public var of: Amount?
    public var unit: String?
    /// What the unused rest is called: "Free".
    public var restLabel: String?
}

/// `timeline`: spans and moments along one axis — a day's calendar, sleep stages, a video's events.
public struct TimelineBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var start: Double
    public var end: Double
    /// "hours" (x is hours since midnight: 9.5 → 09:30), "seconds" (0:42) or "plain".
    public var scale: String?
    public var items: [TimelineItem]
    /// Name the slots' meaning: [{"name": "Deep", "slot": 7}]. With a legend, each item sits in its slot's row.
    public var legend: [Tag]?
    /// "horizontal" (default: sleep, a video's events) or "vertical" (a day's agenda, Calendar-style).
    public var layout: String?
}

public struct TimelineItem: Codable, Equatable, Sendable {
    public var from: Double
    /// Missing: a moment (a dot), not a span.
    public var to: Double?
    public var title: String?
    public var slot: Int?
    public var status: Status?
}

/// `heatmap`: one square per day, weeks as columns (streaks, activity).
public struct HeatmapBlock: Codable, Equatable, Sendable {
    public var label: String?
    /// The first day: "2026-09-01".
    public var start: String
    /// One value per day from `start`; null for no data.
    public var values: [Double?]
    /// Words for the lightest and darkest squares: "Less", "More".
    public var low: String?
    public var high: String?
}

/// `sparklines`: rows with a tiny line each and the change (Stocks-style).
public struct SparklinesBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var rows: [SparkRow]
}

public struct SparkRow: Codable, Equatable, Sendable {
    public var title: String
    public var detail: String?
    public var value: Shown
    /// Change in percent; its sign picks green (up) or red (down) unless `inverted`.
    public var change: Double?
    public var points: [Double]
    /// Down is good (a price you pay, a weight to lose).
    public var inverted: Bool?
}

/// `chips`: tags that wrap — triggers, categories, keywords. Dashed when only maybe.
public struct ChipsBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var chips: [Chip]
}

public struct Chip: Codable, Equatable, Sendable {
    public var text: String
    public var status: Status?
    public var slot: Int?
    public var maybe: Bool?
}

/// `comparison`: two choices side by side, the pick outlined.
public struct ComparisonBlock: Codable, Equatable, Sendable {
    public var options: [Choice]
    /// One sentence on why — the judgement, shown as given.
    public var reason: String?
}

public struct Choice: Codable, Equatable, Sendable {
    public var name: String
    public var value: Shown
    public var unit: String?
    public var detail: String?
    public var best: Bool?
    public var lines: [String]?
}

/// `table`: columns of figures — a league table, a split, a statement.
public struct TableBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var columns: [Column]
    public var rows: [[Shown]]
    /// The row to draw strong (yours).
    public var highlight: Int?
}

public struct Column: Codable, Equatable, Sendable {
    public var title: String
    /// "leading" or "trailing" (default: trailing for numbers, leading for the first column).
    public var align: String?
}

/// `score`: a match — two sides, two numbers, where it stands.
public struct ScoreBlock: Codable, Equatable, Sendable {
    public var home: Side
    public var away: Side
    /// "FT", "72'", "Q3 4:12".
    public var state: String
    public var detail: String?
}

public struct Side: Codable, Equatable, Sendable {
    public var name: String
    public var score: String
    public var detail: String?
}

/// `text`: a paragraph and/or bullets — a summary, a transcript excerpt (as a quote).
public struct TextBlock: Codable, Equatable, Sendable {
    public var label: String?
    public var text: String?
    public var bullets: [String]?
    /// Draw as a quotation (someone else's words).
    public var quote: Bool?
}

/// `images`: local pictures in a grid — search results, artwork, frames.
public struct ImagesBlock: Codable, Equatable, Sendable {
    public var images: [Picture]
    /// Columns: 1 (artwork) to 4; default 3, or 1 for a single image.
    public var columns: Int?
}

public struct Picture: Codable, Equatable, Sendable {
    public var path: String
    public var caption: String?
}
