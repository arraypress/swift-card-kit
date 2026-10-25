//
//  CardMathTests.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  Every number and word a card works out, against values worked by hand.
//

import Foundation
import XCTest

@testable import CardKit

final class CardMathTests: XCTestCase {

    let en = Locale(identifier: "en_GB")
    func gbp(_ text: String) -> Amount { Amount(Decimal(string: text)!, currency: "GBP") }
    func n(_ value: Double) -> Amount { Amount(Decimal(value)) }

    // MARK: - Text

    func testMoneyKeepsItsCurrencysDecimals() {
        XCTAssertEqual(CardMath.text(gbp("4.2"), locale: en), "£4.20", "pence always shown on an exact amount")
        XCTAssertEqual(CardMath.text(gbp("1188.4"), whole: true, locale: en), "£1,188")
        XCTAssertEqual(CardMath.text(Amount(500, currency: "JPY"), locale: en), "JP¥500", "the yen has no minor unit")
        XCTAssertEqual(CardMath.text(Amount(Decimal(string: "1.25")!, currency: "BHD"), locale: en).replacingOccurrences(of: "\u{00A0}", with: " "),
                       "BHD 1.250", "the dinar has three")
    }

    func testPlainNumbersAndUnits() {
        XCTAssertEqual(CardMath.text(n(2140), unit: "kcal", locale: en), "2,140 kcal")
        XCTAssertEqual(CardMath.text(n(81.44), unit: "kg", locale: en), "81.4 kg", "one decimal at most")
        XCTAssertEqual(CardMath.text(n(81.44), unit: "kg", whole: true, locale: en), "81 kg")
        XCTAssertEqual(CardMath.text(n(82), unit: "%", locale: en), "82%", "% and ° sit against the number")
        XCTAssertEqual(CardMath.text(n(14), unit: "°", locale: en), "14°")
        XCTAssertEqual(CardMath.text(gbp("4.20"), unit: "kcal", locale: en), "£4.20", "money carries its own symbol")
        XCTAssertEqual(CardMath.text(.text("Tue"), unit: "kcal"), "Tue", "words as given")
    }

    func testPercentChangeIsSigned() {
        XCTAssertEqual(CardMath.percentChange(12.3, locale: en), "+12 %")
        XCTAssertEqual(CardMath.percentChange(-3.26, locale: en), "−3.3 %", "a true minus, one decimal under ten")
        XCTAssertEqual(CardMath.percentChange(0, locale: en), "0 %")
    }

    // MARK: - Bars against limits

    func testFillAndOver() {
        XCTAssertEqual(CardMath.fill(gbp("50"), of: gbp("200")), 0.25)
        XCTAssertEqual(CardMath.fill(gbp("300"), of: gbp("200")), 1, "never past full")
        XCTAssertEqual(CardMath.fill(gbp("10"), of: gbp("0")), 0)
        XCTAssertEqual(CardMath.overShare(gbp("63.40"), of: gbp("50")), 13.4 / 63.4, accuracy: 1e-9)
        XCTAssertEqual(CardMath.overShare(gbp("500"), of: gbp("50")), 0.5, "at most half the bar is striped")
        XCTAssertEqual(CardMath.overShare(gbp("40"), of: gbp("50")), 0)
        XCTAssertFalse(CardMath.isOver(gbp("50"), of: gbp("50")), "exactly at the limit is not over")
    }

    // MARK: - limits

    func limits(_ rows: [(String, String, String)], total: String? = nil, days: Int? = nil, order: String? = nil) -> LimitsBlock {
        LimitsBlock(label: nil, rows: rows.map { LimitRow(name: $0.0, value: gbp($0.1), of: gbp($0.2), slot: nil) },
                    total: total.map(gbp), daysLeft: days, unit: nil, order: order)
    }

    func testLimitsTotalsAndOrder() {
        let block = limits([("Groceries", "212.35", "300"), ("Coffee", "63.40", "50"), ("Transport", "64", "120"), ("Gift", "60", "120")])
        XCTAssertEqual(CardMath.totals(block).used, gbp("399.75"))
        XCTAssertEqual(CardMath.totals(block).limit, gbp("590"), "without a total, the rows' limits")
        XCTAssertEqual(CardMath.totals(limits([("A", "1", "2")], total: "1800")).limit, gbp("1800"))
        XCTAssertEqual(CardMath.ordered(block).map(\.row.name), ["Coffee", "Groceries", "Transport", "Gift"], "fullest first; a tie keeps its order")
        XCTAssertEqual(CardMath.ordered(block).map(\.slot), [2, 1, 3, 4], "a row keeps its colour when sorted")
        XCTAssertEqual(CardMath.ordered(limits([("A", "9", "10"), ("B", "1", "10")], order: "given")).map(\.row.name), ["A", "B"])
    }

    func testLimitsHeroAndStatus() {
        let budget = limits([("Groceries", "212.35", "300"), ("Coffee", "63.40", "50")], total: "1800", days: 9)
        XCTAssertEqual(CardMath.hero(budget, locale: en), Hero(value: .text("£1,524"), unit: "left of £1,800"))
        XCTAssertEqual(CardMath.status(budget, locale: en), StatusText(status: .neutral, text: "About £169 a day for the 9 days left"),
                       "one part over: neutral, not good")
        let fine = limits([("Groceries", "212.35", "300")], days: 1)
        XCTAssertEqual(CardMath.status(fine, locale: en), StatusText(status: .good, text: "About £88 a day for the 1 day left"))
        let over = limits([("Groceries", "350", "300")])
        XCTAssertEqual(CardMath.hero(over, locale: en), Hero(value: .text("£50"), unit: "over £300"))
        XCTAssertEqual(CardMath.status(over, locale: en), StatusText(status: .over, text: "£50 over the limit"))
        XCTAssertEqual(CardMath.status(limits([("A", "1", "2"), ("B", "3", "2")], total: "10"), locale: en),
                       StatusText(status: .neutral, text: "1 of 2 over their limit"))
        XCTAssertEqual(CardMath.status(limits([("A", "1", "2")]), locale: en), StatusText(status: .good, text: "Every part within its limit"))
    }

    // MARK: - breakdown and segmented

    func part(_ name: String, _ value: String, _ previous: String? = nil, slot: Int? = nil) -> Part {
        Part(name: name, value: gbp(value), previous: previous.map(gbp), slot: slot)
    }

    func testBreakdownOrderSharesAndChange() {
        let parts = [part("Coffee", "63.40"), part("Bills", "406"), part("Gift", "63.40")]
        XCTAssertEqual(CardMath.ordered(parts).map(\.part.name), ["Bills", "Coffee", "Gift"])
        XCTAssertEqual(CardMath.ordered(parts).map(\.slot), [2, 1, 3])
        XCTAssertEqual(CardMath.shares([1, 1, 1]), [34, 33, 33], "largest remainder: they add to 100")
        XCTAssertEqual(CardMath.shares([1, 2]), [33, 67], "the extra point goes to the largest remainder, not the first part")
        XCTAssertEqual(CardMath.shares([406, 254.45, 212.35, 188.2, 64, 63.4]).reduce(0, +), 100)
        XCTAssertEqual(CardMath.shares([0, 0]), [0, 0])
        XCTAssertEqual(CardMath.change(part("A", "254.45", "214.90")), .up(gbp("39.55")))
        XCTAssertEqual(CardMath.change(part("A", "212.35", "243.10")), .down(gbp("30.75")))
        XCTAssertEqual(CardMath.change(part("A", "406", "406.40")), .same, "under half a unit: the same")
        XCTAssertNil(CardMath.change(part("A", "1")))
    }

    func testBreakdownStatusAgainstTheReference() {
        func block(_ reference: String?) -> BreakdownBlock {
            BreakdownBlock(label: nil, rows: [part("A", "1188.40")], unit: nil, reference: reference.map { Reference(value: gbp($0), label: "September by now") })
        }
        XCTAssertEqual(CardMath.status(block("1282.40"), locale: en), StatusText(status: .good, text: "£94 less than September by now"))
        XCTAssertEqual(CardMath.status(block("1000"), locale: en), StatusText(status: .over, text: "£188 more than September by now"))
        XCTAssertEqual(CardMath.status(block("1188.20"), locale: en), StatusText(status: .neutral, text: "Same as September by now"))
        XCTAssertNil(CardMath.status(block(nil), locale: en))
        XCTAssertEqual(CardMath.hero(block(nil), locale: en), Hero(value: .text("£1,188"), unit: "in all"))
    }

    func testSegmentsFillTheCapacity() {
        let disk = SegmentedBlock(label: nil, parts: [Part(name: "Apps", value: n(100), slot: nil), Part(name: "Docs", value: n(300), slot: nil)],
                                  of: n(1000), unit: "GB", restLabel: nil)
        let (pieces, rest) = CardMath.segments(disk)
        XCTAssertEqual(pieces.map(\.part.name), ["Docs", "Apps"])
        XCTAssertEqual(pieces.map(\.fraction), [0.3, 0.1])
        XCTAssertEqual(pieces.map(\.slot), [2, 1])
        XCTAssertEqual(rest, 0.6, accuracy: 1e-9)
        var full = disk; full.of = n(200)
        XCTAssertEqual(CardMath.segments(full).rest, 0, "parts over the capacity: no free rest, the bar is the parts")
        XCTAssertEqual(CardMath.segments(full).pieces.map(\.fraction), [0.75, 0.25])
    }

    // MARK: - bars

    func bars(_ values: [Double?], goal: Double? = nil, band: (Double, Double)? = nil, highlight: Int? = nil) -> BarsBlock {
        BarsBlock(label: nil, bars: values.enumerated().map { Bar(label: "\($0.offset)", value: $0.element.map(n), parts: nil) },
                  unit: "steps", goal: goal.map(n), band: band.map { Band(low: n($0.0), high: n($0.1)) }, average: nil, highlight: highlight, legend: nil)
    }

    func testBarsAverageHighlightAndScale() {
        let week = bars([6000, nil, 9000, 12000])
        XCTAssertEqual(CardMath.average(week), 9000, "a day not logged is left out")
        XCTAssertEqual(CardMath.highlighted(week), 3)
        XCTAssertEqual(CardMath.highlighted(bars([6000, 7000, nil])), 1, "the last day logged")
        XCTAssertEqual(CardMath.highlighted(bars([6000, 7000], highlight: 0)), 0)
        XCTAssertEqual(CardMath.scaleTop(week), 15000)
        XCTAssertEqual(CardMath.scaleTop(bars([3000], goal: 8000)), 8000, "the goal stays on the chart")
        XCTAssertEqual(CardMath.total(Bar(label: "M", value: nil, parts: [n(1.4), n(1.9), n(0.8)]))!, 4.1, accuracy: 1e-9)
    }

    func testBarsStatus() {
        XCTAssertEqual(CardMath.status(bars([1700], band: (1988, 2430)), locale: en), StatusText(status: .neutral, text: "288 steps under the target"))
        XCTAssertEqual(CardMath.status(bars([2810], band: (1988, 2430)), locale: en), StatusText(status: .over, text: "380 steps over the target"))
        XCTAssertEqual(CardMath.status(bars([2105], band: (1988, 2430)), locale: en), StatusText(status: .good, text: "On target"))
        XCTAssertEqual(CardMath.status(bars([8466], goal: 8000), locale: en), StatusText(status: .good, text: "Goal reached"))
        XCTAssertEqual(CardMath.status(bars([7000], goal: 8000), locale: en), StatusText(status: .neutral, text: "1,000 steps to the goal"))
        XCTAssertEqual(CardMath.status(bars([10000, 12000]), locale: en), StatusText(status: .neutral, text: "+9.1 % against the average of 11,000 steps"))
        XCTAssertEqual(CardMath.status(bars([10000, 10100]), locale: en), StatusText(status: .neutral, text: "About your average"))
        XCTAssertEqual(CardMath.hero(bars([8466]), locale: en), Hero(value: .text("8,466"), unit: "steps"))
    }

    func testStacksMarkEachPartOnce() {
        let block = BarsBlock(label: nil, bars: [Bar(label: "M", value: nil, parts: [n(1), n(0), n(2)]), Bar(label: "T", value: n(3), parts: nil), Bar(label: "W", value: nil, parts: nil)],
                              unit: nil, goal: nil, band: nil, average: nil, highlight: nil, legend: [Tag(name: "a"), Tag(name: "b", slot: 5), Tag(name: "c")])
        let marks = CardMath.stacks(block)
        XCTAssertEqual(marks.map(\.id), ["0-0", "0-2", "1"], "a zero part and an unlogged bar draw nothing; ids never repeat")
        XCTAssertEqual(marks.map(\.from), [0, 1, 0])
        XCTAssertEqual(marks.map(\.to), [1, 3, 3])
        XCTAssertEqual(marks.map(\.top), [false, true, true], "only the top of a stack is rounded")
        XCTAssertEqual(marks.map(\.slot), [1, 3, 1], "a part takes its legend entry's slot")
    }

    func testNiceNumbersAndTicks() {
        XCTAssertEqual(CardMath.niceCeiling(12877), 15000)
        XCTAssertEqual(CardMath.niceCeiling(1800), 2000)
        XCTAssertEqual(CardMath.niceCeiling(4.9), 5)
        XCTAssertEqual(CardMath.niceCeiling(0.07), 0.08, accuracy: 1e-12)
        XCTAssertEqual(CardMath.niceCeiling(0), 1)
        XCTAssertEqual(CardMath.ticks(top: 15000), [0, 5000, 10000, 15000])
    }

    // MARK: - trend

    func series(_ name: String, _ points: [(Double, String)]) -> Series {
        Series(name: name, points: points.map { Point(x: $0.0, value: gbp($0.1)) })
    }

    func testTrendStatusAndProjection() {
        let october = series("October", [(1, "12"), (22, "1188.40")])
        let september = series("September", [(1, "0"), (21, "1205"), (22, "1282.40"), (30, "1636")])
        var block = TrendBlock(label: nil, series: [october, september], target: Target(value: gbp("1800"), at: 31, label: "budget"),
                               end: 31, unit: nil, area: nil, smooth: nil, xLabels: nil)
        XCTAssertEqual(CardMath.value(september, at: 21.5), gbp("1205"), "the last point at or before x")
        XCTAssertNil(CardMath.value(september, at: 0.5))
        XCTAssertEqual(CardMath.status(block, locale: en), StatusText(status: .good, text: "£94 under September by now"))
        XCTAssertEqual(CardMath.projection(block), gbp("1675"))
        XCTAssertEqual(CardMath.projectionText(block, locale: en), "At this pace about £1,675 by the end — £125 under budget.")
        XCTAssertEqual(CardMath.hero(block, locale: en), Hero(value: .text("£1,188"), unit: "so far"))
        block.series = [series("Weight", [(1, "83"), (30, "81.4")])]
        XCTAssertEqual(CardMath.status(block, locale: en), StatusText(status: .neutral, text: "Down £2 over the period"))
        block.target = nil
        XCTAssertNil(CardMath.projectionText(block), "no target: no projection line")
    }

    func testMovingAverage() {
        XCTAssertEqual(CardMath.movingAverage([1, 2, 3, 4], window: 2), [1, 1.5, 2.5, 3.5])
        XCTAssertEqual(CardMath.movingAverage([1, 2, 3], window: 1), [1, 2, 3])
    }

    // MARK: - range, timeline, heatmap

    func testRangeScaleAndPosition() {
        let block = RangeBlock(label: nil, rows: [RangeRow(label: "a", low: n(4), high: n(16), symbol: nil, detail: nil)], unit: nil, style: nil, now: nil)
        let scale = CardMath.scale(block)
        XCTAssertEqual(scale.lowerBound, 3.5, accuracy: 1e-9, "padded 4 % of the span, at least half a unit")
        XCTAssertEqual(scale.upperBound, 16.5, accuracy: 1e-9)
        let wide = RangeBlock(label: nil, rows: [RangeRow(label: "a", low: n(0), high: n(100), symbol: nil, detail: nil)], unit: nil, style: nil, now: nil)
        XCTAssertEqual(CardMath.scale(wide).upperBound, 104, accuracy: 1e-9)
        XCTAssertEqual(CardMath.position(10, in: 0...20), 0.5)
        XCTAssertEqual(CardMath.position(30, in: 0...20), 1, "clamped")
        XCTAssertEqual(CardMath.position(3, in: 5...5), 0.5)
    }

    func testTimelineLanes() {
        let items = [TimelineItem(from: 9, to: 10), TimelineItem(from: 9.5, to: 11), TimelineItem(from: 10, to: 10.5), TimelineItem(from: 17)]
        XCTAssertEqual(CardMath.lanes(items), [0, 1, 0, 0], "an overlap takes the next lane; a span that starts at another's end reuses it")
        let sleep = TimelineBlock(label: nil, start: 0, end: 8, scale: nil, items: [TimelineItem(from: 0, to: 1, slot: 7), TimelineItem(from: 1, to: 2, slot: 2)],
                                  legend: [Tag(name: "Awake", slot: 2), Tag(name: "Deep", slot: 7)], layout: nil)
        XCTAssertEqual(CardMath.lanes(sleep), [1, 0], "with a legend, a stage's row")
    }

    func testTimeText() {
        XCTAssertEqual(CardMath.timeText(9.5, scale: "hours"), "09:30")
        XCTAssertEqual(CardMath.timeText(24, scale: "hours"), "00:00", "past midnight wraps")
        XCTAssertEqual(CardMath.timeText(102, scale: "seconds"), "1:42")
        XCTAssertEqual(CardMath.timeText(3725, scale: "seconds"), "1:02:05")
        XCTAssertEqual(CardMath.timeTicks(start: 23, end: 31, scale: "hours"), [24, 26, 28, 30])
        XCTAssertEqual(CardMath.timeTicks(start: 0, end: 60, scale: "seconds"), [0, 15, 30, 45, 60])
    }

    func testHeatmapGridAndLevels() {
        let grid = CardMath.grid(start: "2026-10-01", count: 6)!   // a Thursday
        XCTAssertEqual(grid.first!.column, 0)
        XCTAssertEqual(grid.first!.row, 3, "Monday is row 0")
        XCTAssertEqual(grid[4].column, 1, "the Monday after starts the next column")
        XCTAssertEqual(grid[4].row, 0)
        XCTAssertNil(CardMath.grid(start: "1 Oct", count: 1))
        XCTAssertEqual(CardMath.levels([nil, 0, 10, 20, 30, 40]), [0, 0, 1, 2, 3, 4], "quartiles of the days with something")
        XCTAssertEqual(CardMath.levels([0, nil]), [0, 0])
    }

    // MARK: - The card's hero and status

    func testCardHeroAndStatusPrecedence() {
        let block = Block.breakdown(BreakdownBlock(label: nil, rows: [part("A", "10")], unit: nil, reference: Reference(value: gbp("20"), label: "last month")))
        var card = Card(eyebrow: "x", blocks: [.text(TextBlock(label: nil, text: "hi", bullets: nil, quote: nil)), block])
        XCTAssertEqual(CardMath.hero(card, locale: en), Hero(value: .text("£10"), unit: "in all"), "from the first block that has one")
        XCTAssertEqual(CardMath.status(card, locale: en)?.text, "£10 less than last month")
        card.hero = Hero(value: .text("Mine")); card.status = StatusText(status: .critical, text: "Given")
        XCTAssertEqual(CardMath.hero(card, locale: en)?.value, .text("Mine"), "the card's own wins")
        XCTAssertEqual(CardMath.status(card, locale: en)?.text, "Given")
        XCTAssertNil(CardMath.hero(Card(eyebrow: "x", blocks: [.text(TextBlock(label: nil, text: "hi", bullets: nil, quote: nil))])))
    }

    func testSlotsDefaultToPosition() {
        XCTAssertEqual(CardMath.slots([nil, 5, nil]), [1, 5, 3])
    }
}

extension TimelineItem {
    init(from: Double, to: Double? = nil, slot: Int? = nil) { self.init(from: from, to: to, title: nil, slot: slot, status: nil) }
}
