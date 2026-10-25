//
//  CardChecksTests.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  A card that can't be drawn right is refused, naming the field; and JSON
//  mistakes are reported by their path, in the JSON's own spelling.
//

import Foundation
import XCTest

@testable import CardKit

final class CardChecksTests: XCTestCase {

    func card(_ blocks: String, eyebrow: String = "x") throws -> Card {
        try CardDecoder.card(from: Data(#"{"eyebrow": "\#(eyebrow)", "blocks": [\#(blocks)]}"#.utf8))
    }

    func problem(_ blocks: String) throws -> String? { CardChecks.problem(try card(blocks)) }

    func testTheCardItself() throws {
        XCTAssertEqual(CardChecks.problem(try card(#"{"type": "text", "text": "a"}"#, eyebrow: " ")), "eyebrow is empty")
        XCTAssertEqual(CardChecks.problem(Card(eyebrow: "x", blocks: [])), "blocks: give 1 to 8 (got 0)")
        let hero = Card(eyebrow: "x", hero: Hero(value: .text("1"), symbol: "no.such.symbol"), blocks: [.text(TextBlock(text: "a"))])
        XCTAssertEqual(CardChecks.problem(hero), "hero.symbol: no SF Symbol named 'no.such.symbol'")
    }

    func testMoneyMustBeExactAndInOneCurrency() throws {
        let row = { (value: String, of: String) in #"{"type": "limits", "rows": [{"name": "a", "value": \#(value), "of": \#(of)}]}"# }
        XCTAssertNil(try problem(row(#"{"amount": "4.20", "currency": "GBP"}"#, #"{"amount": "5", "currency": "GBP"}"#)))
        XCTAssertEqual(try problem(row(#"{"amount": "4.205", "currency": "GBP"}"#, #"{"amount": "5", "currency": "GBP"}"#)),
                       "blocks[0].rows[0].value: 4.205 has more decimals than GBP has")
        XCTAssertEqual(try problem(row(#"{"amount": "500.5", "currency": "JPY"}"#, #"{"amount": "600", "currency": "JPY"}"#)),
                       "blocks[0].rows[0].value: 500.5 has more decimals than JPY has")
        XCTAssertEqual(try problem(row(#"{"amount": "4", "currency": "GBP"}"#, #"{"amount": "5", "currency": "EUR"}"#)),
                       "amounts mix EUR and GBP: draw one card per currency")
        XCTAssertEqual(try problem(row(#"{"amount": "4", "currency": "POUNDS"}"#, #"{"amount": "5", "currency": "GBP"}"#)),
                       "blocks[0].rows[0].value: 'POUNDS' is not an ISO 4217 currency code")
        XCTAssertEqual(try problem(row(#"{"amount": "4", "currency": "GBP"}"#, "5")), "blocks[0].rows[0].of is a plain number beside GBP amounts")
        XCTAssertEqual(try problem(row("-1", "5")), "blocks[0].rows[0].value is negative")
        XCTAssertNil(try problem(#"{"type": "list", "rows": [{"title": "bill", "value": {"amount": "10.99", "currency": "GBP"}}, {"title": "temp", "value": 14}]}"#),
                     "a list may put a bill beside a plain number")
    }

    func testColourSlots() throws {
        let parts = { (a: String, b: String) in #"{"type": "breakdown", "rows": [{"name": "a", "value": 1\#(a)}, {"name": "b", "value": 2\#(b)}]}"# }
        XCTAssertNil(try problem(parts("", "")))
        XCTAssertEqual(try problem(parts("", #", "slot": 1"#)), "blocks[0].rows[1] has the same colour slot (1) as blocks[0].rows[0]")
        XCTAssertEqual(try problem(parts(#", "slot": 9"#, "")), "blocks[0].rows[0].slot: 9 is not a palette slot (1–8)")
    }

    func testBlockLimits() throws {
        let nine = (1...9).map { #"{"name": "p\#($0)", "value": \#($0)}"# }.joined(separator: ",")
        XCTAssertEqual(try problem(#"{"type": "breakdown", "rows": [\#(nine)]}"#), "blocks[0].rows: give 1 to 8 (got 9); fold the rest into one \"Other\"")
        XCTAssertEqual(try problem(#"{"type": "tiles", "tiles": []}"#), "blocks[0].tiles: give 1 to 4 (got 0)")
        XCTAssertEqual(try problem(#"{"type": "comparison", "options": [{"name": "a", "value": 1}]}"#), "blocks[0].options: give two (got 1)")
        XCTAssertEqual(try problem(#"{"type": "comparison", "options": [{"name": "a", "value": 1, "best": true}, {"name": "b", "value": 2, "best": true}]}"#),
                       "blocks[0].options: at most one is best")
        XCTAssertEqual(try problem(#"{"type": "text"}"#), "blocks[0]: give text or bullets")
    }

    func testCharts() throws {
        XCTAssertEqual(try problem(#"{"type": "bars", "bars": [{"label": "M", "parts": [1, 2]}]}"#), "blocks[0].legend: name the stacked parts")
        XCTAssertEqual(try problem(#"{"type": "bars", "legend": [{"name": "a"}], "bars": [{"label": "M", "parts": [1, 2]}]}"#),
                       "blocks[0].bars[0].parts: 2 parts but the legend names 1")
        XCTAssertEqual(try problem(#"{"type": "bars", "highlight": 3, "bars": [{"label": "M", "value": 1}]}"#), "blocks[0].highlight: 3 is not a bar (0–0)")
        XCTAssertEqual(try problem(#"{"type": "bars", "band": {"low": 5, "high": 4}, "bars": [{"label": "M", "value": 1}]}"#), "blocks[0].band: low is above high")
        XCTAssertEqual(try problem(#"{"type": "trend", "series": [{"name": "a", "points": [{"x": 2, "value": 1}, {"x": 2, "value": 2}]}]}"#),
                       "blocks[0].series[0].points: x must go up (2.0 after 2.0)")
        XCTAssertEqual(try problem(#"{"type": "trend", "end": 1, "series": [{"name": "a", "points": [{"x": 2, "value": 1}]}]}"#),
                       "blocks[0].end: 1.0 is before the last point (2.0)")
        XCTAssertEqual(try problem(#"{"type": "range", "rows": [{"label": "a", "low": 5, "high": 4}]}"#), "blocks[0].rows[0]: low is above high")
        XCTAssertEqual(try problem(#"{"type": "rings", "rings": [{"label": "a", "value": 1, "of": 0}]}"#), "blocks[0].rings[0].of must be above zero")
        XCTAssertEqual(try problem(#"{"type": "gauges", "gauges": [{"label": "a", "value": 1, "of": 0}]}"#), "blocks[0].gauges[0].of must be above zero")
        XCTAssertEqual(try problem(#"{"type": "timeline", "start": 9, "end": 8, "items": [{"from": 9}]}"#), "blocks[0]: end must be after start")
        XCTAssertEqual(try problem(#"{"type": "timeline", "start": 9, "end": 18, "items": [{"from": 8}]}"#), "blocks[0].items[0] is outside 9.0–18.0")
        XCTAssertEqual(try problem(#"{"type": "timeline", "start": 9, "end": 18, "items": [{"from": 12, "to": 10}]}"#), "blocks[0].items[0]: to is before from")
        XCTAssertEqual(try problem(#"{"type": "timeline", "start": 9, "end": 18, "layout": "diagonal", "items": [{"from": 12}]}"#),
                       "blocks[0].layout: 'diagonal' is not horizontal or vertical")
        XCTAssertEqual(try problem(#"{"type": "heatmap", "start": "1 May", "values": [1]}"#), "blocks[0].start: '1 May' is not a YYYY-MM-DD date")
        XCTAssertEqual(try problem(#"{"type": "sparklines", "rows": [{"title": "a", "value": "1", "points": [1]}]}"#), "blocks[0].rows[0].points: give 2 or more")
    }

    func testTablesAndPictures() throws {
        XCTAssertEqual(try problem(#"{"type": "table", "columns": [{"title": "a"}, {"title": "b"}], "rows": [["x"]]}"#), "blocks[0].rows[0]: 1 cells for 2 columns")
        XCTAssertEqual(try problem(#"{"type": "images", "images": [{"path": "/no/such/picture.png"}]}"#),
                       "blocks[0].images[0].path: no readable image at /no/such/picture.png")
    }

    func testJSONMistakesNameTheirPath() {
        func error(_ json: String) -> String? {
            do { _ = try CardDecoder.card(from: Data(json.utf8)); return nil } catch { return (error as? CardError)?.errorDescription }
        }
        XCTAssertEqual(error(#"{"eyebrow": "x", "blocks": [{"type": "limits", "rows": [{"name": "a", "value": 1}]}]}"#), "blocks[0].rows[0] is missing of")
        XCTAssertEqual(error(#"{"eyebrow": "x", "blocks": [{"type": "limits", "days_left": "nine", "rows": []}]}"#), "blocks[0].days_left has the wrong kind of value")
        XCTAssertEqual(error(#"{"eyebrow": "x", "blocks": [{"type": "pie"}]}"#)?.hasPrefix("blocks[0].type: 'pie' is not a block type"), true)
        XCTAssertEqual(error(#"{"blocks": []}"#), "is missing eyebrow")
        XCTAssertEqual(CardDecoder.snake("daysLeft"), "days_left")
    }

    func testStoreMoneyDecodesExactly() throws {
        let money = try JSONDecoder().decode(Amount.self, from: Data(#"{"amount": "0.10", "currency": "gbp"}"#.utf8))
        XCTAssertEqual(money, Amount(Decimal(string: "0.1")!, currency: "GBP"), "a string, never through a Double; the code upper-cased")
        let big = try JSONDecoder().decode(Amount.self, from: Data(#"{"amount": "12345678901234567.89", "currency": "USD"}"#.utf8))
        XCTAssertEqual(big.value, Decimal(string: "12345678901234567.89")!, "17 significant digits survive: a Double would round them")
        let plain = try JSONDecoder().decode(Amount.self, from: Data("2140".utf8))
        XCTAssertNil(plain.currency)
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(String(data: try encoder.encode(money), encoding: .utf8), #"{"amount":"0.1","currency":"GBP"}"#)
    }
}

extension TextBlock {
    init(text: String) { self.init(label: nil, text: text, bullets: nil, quote: nil) }
}
