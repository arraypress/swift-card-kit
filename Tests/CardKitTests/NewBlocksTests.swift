//
//  NewBlocksTests.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  0.2.0's rules: wording, the text version, private card files, the new
//  blocks' arithmetic and checks, and refunds.
//

import AppKit
import Foundation
import XCTest

@testable import CardKit

final class NewBlocksTests: XCTestCase {

    let en = Locale(identifier: "en_GB")
    func gbp(_ text: String) -> Amount { Amount(Decimal(string: text)!, currency: "GBP") }
    func card(_ json: String) throws -> Card { try CardDecoder.card(from: Data(json.utf8)) }

    // MARK: - Wording

    func testPhrasesFillAndCanBeReplaced() {
        XCTAssertEqual(Words()("over_the_limit", ["amount": "£50"]), "£50 over the limit")
        XCTAssertEqual(Words(["over_the_limit": "{amount} drüber"])("over_the_limit", ["amount": "€50"]), "€50 drüber")
        XCTAssertEqual(Words()("no_such_phrase"), "no_such_phrase", "an unknown id shows itself rather than vanishing")
        XCTAssertEqual(Words.placeholders("{amount} over {total}"), ["amount", "total"])
        for (id, phrase) in Words.english { XCTAssertFalse(phrase.isEmpty, id) }
    }

    func testCardWordingReachesTheComputedWords() throws {
        let budget = try card(#"""
            {"eyebrow": "x", "wording": {"left_of": "übrig von {total}", "a_day": "Etwa {amount} pro Tag, {days} Tage"},
             "blocks": [{"type": "limits", "days_left": 9, "rows": [{"name": "a", "value": {"amount": "100", "currency": "EUR"}, "of": {"amount": "1000", "currency": "EUR"}}]}]}
            """#)
        XCTAssertEqual(CardMath.hero(budget, locale: en)?.unit, "übrig von €1,000")
        XCTAssertEqual(CardMath.status(budget, locale: en)?.text, "Etwa €100 pro Tag, 9 Tage")
    }

    func testWordingIsChecked() {
        XCTAssertEqual(CardChecks.problem(wording: ["lft_of": "x"]), "wording.lft_of: no such phrase (card words lists them)")
        XCTAssertEqual(CardChecks.problem(wording: ["left_of": "übrig von {totl}"]), "wording.left_of: {totl} isn't one of its placeholders (left of {total})")
        XCTAssertNil(CardChecks.problem(wording: ["left_of": "übrig"]), "leaving a placeholder out is allowed")
    }

    // MARK: - Text version

    func testTheTextVersionReadsLikeTheCard() throws {
        let spend = try card(#"""
        {"eyebrow": "Spent · 12:42", "hero": {"value": {"amount": "4.20", "currency": "GBP"}, "label": "Corner Café", "tags": [{"name": "Coffee"}]},
         "status": {"status": "critical", "text": "Card declined twice"},
         "blocks": [{"type": "limits", "rows": [{"name": "Coffee", "value": {"amount": "63.40", "currency": "GBP"}, "of": {"amount": "50", "currency": "GBP"}}]},
                    {"type": "list", "rows": [{"title": "Water the plants", "done": false}, {"title": "Book", "done": true}]},
                    {"type": "qr", "payload": "WIFI:S:x;P:secret-password;;", "title": "Join Wi-Fi"}],
         "footnote": "From your message."}
        """#)
        let text = CardText.text(spend, locale: en)
        XCTAssertEqual(text, """
            Spent · 12:42
            £4.20 — Corner Café (Coffee)
            Warning: Card declined twice
            - Coffee: £63 of £50 — £13 over
            - [ ] Water the plants
            - [x] Book
            QR code: Join Wi-Fi
            From your message.
            """)
        XCTAssertFalse(text.contains("secret-password"), "a QR code's contents never go into the text")
    }

    func testTextForTheNewBlocks() throws {
        let tracker = Block.tracker(TrackerBlock(steps: [TrackerStep(title: "Ordered", time: "Fri"), TrackerStep(title: "On the way", state: "current"),
                                                        TrackerStep(title: "Delivered")]))
        XCTAssertEqual(CardText.text(tracker, locale: en, words: Words()), ["- [done] Ordered, Fri", "- [now] On the way", "- [next] Delivered"])
        let awards = Block.awards(AwardsBlock(awards: [AwardItem(title: "Streak", symbol: "flame", earned: true),
                                                       AwardItem(title: "30 days", symbol: "flame", earned: false, progress: Amount(7), of: Amount(30))]))
        XCTAssertEqual(CardText.text(awards, locale: en, words: Words()), ["Earned: Streak", "Still to earn: 30 days (7 of 30)"])
        let month = Block.month(MonthBlock(month: "2026-10", days: [MonthDay(day: 12), MonthDay(day: 3)]))
        XCTAssertEqual(CardText.text(month, locale: en, words: Words()), ["October 2026: marked 3, 12"])
    }

    // MARK: - Private files

    func testCardsGoToAPrivateFolderAndDontPileUp() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("cardkit-home-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: home) }
        let first = try CardFiles.newCard(home: home)
        XCTAssertEqual(first.deletingLastPathComponent().path, home.appendingPathComponent("Library/Caches/arraypress/cards").path)
        let mode = try FileManager.default.attributesOfItem(atPath: first.deletingLastPathComponent().path)[.posixPermissions] as? Int
        XCTAssertEqual(mode, 0o700, "only this user can read the folder")
        try Data([1]).write(to: first)
        let old = first.deletingLastPathComponent().appendingPathComponent("card-old.png")
        try Data([1]).write(to: old)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-CardFiles.keep - 60)], ofItemAtPath: old.path)
        let other = first.deletingLastPathComponent().appendingPathComponent("notes.txt")
        try Data([1]).write(to: other)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-CardFiles.keep - 60)], ofItemAtPath: other.path)
        let second = try CardFiles.newCard(home: home)
        XCTAssertNotEqual(first, second, "each card a new name")
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path), "a card older than a day is removed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path), "a fresh card stays")
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.path), "only cards are touched")
    }

    // MARK: - New blocks: arithmetic

    func testTrackerStates() {
        let given = TrackerBlock(steps: [TrackerStep(title: "a"), TrackerStep(title: "b", state: "current"), TrackerStep(title: "c"), TrackerStep(title: "d", state: "failed")])
        XCTAssertEqual(CardMath.states(given), ["done", "current", "upcoming", "failed"], "before the current step is done; given states win")
        XCTAssertEqual(CardMath.states(TrackerBlock(steps: [TrackerStep(title: "a"), TrackerStep(title: "b")])), ["upcoming", "upcoming"])
    }

    func testAwardProgress() {
        XCTAssertEqual(CardMath.progress(AwardItem(title: "a", symbol: "s", earned: false, progress: Amount(7), of: Amount(28))), 0.25)
        XCTAssertEqual(CardMath.progress(AwardItem(title: "a", symbol: "s", earned: false, progress: Amount(40), of: Amount(28))), 1)
        XCTAssertEqual(CardMath.progress(AwardItem(title: "a", symbol: "s", earned: true)), 1)
        XCTAssertEqual(CardMath.progress(AwardItem(title: "a", symbol: "s", earned: false)), 0)
    }

    func testMonthGrid() throws {
        XCTAssertEqual(CardMath.monthLength("2026-02"), 28)
        XCTAssertEqual(CardMath.monthLength("2028-02"), 29, "a leap year")
        XCTAssertNil(CardMath.monthLength("2026-13"))
        let october = try XCTUnwrap(CardMath.monthGrid("2026-10"))    // 1 October 2026 is a Thursday
        XCTAssertEqual(october[0], [nil, nil, nil, 1, 2, 3, 4], "Monday first")
        XCTAssertEqual(october.last, [26, 27, 28, 29, 30, 31, nil])
        XCTAssertEqual(CardMath.monthTitle("2026-10", locale: en), "October 2026")
    }

    func testMapRegionFitsEveryPoint() {
        let block = MapBlock(pins: [MapPin(lat: 51.50, lon: -0.13)], route: [MapPoint(lat: 51.50, lon: -0.13), MapPoint(lat: 51.52, lon: -0.10)])
        let region = CardMath.mapRegion(block)
        XCTAssertEqual(region.lat, 51.51, accuracy: 1e-9)
        XCTAssertEqual(region.lon, -0.115, accuracy: 1e-9)
        XCTAssertEqual(region.latSpan, 0.028, accuracy: 1e-9, "padded by 40 %")
        XCTAssertEqual(region.lonSpan, 0.042, accuracy: 1e-9)
        let one = CardMath.mapRegion(MapBlock(pins: [MapPin(lat: 51.5, lon: -0.1)]))
        XCTAssertEqual(one.latSpan, 0.006, "a single pin still shows its streets")
    }

    func testRefundsCountTowardTheTotalButHaveNoShare() {
        let parts = [Part(name: "Food", value: gbp("90")), Part(name: "Refund", value: gbp("-60")), Part(name: "Fuel", value: gbp("10"))]
        XCTAssertEqual(CardMath.ordered(parts).map(\.part.name), ["Food", "Fuel", "Refund"], "a refund goes last")
        XCTAssertEqual(CardMath.shares([90, 10, -60]), [90, 10, 0], "shares are of what was spent")
        XCTAssertEqual(CardMath.hero(BreakdownBlock(rows: parts), locale: en)?.value, .text("£40"), "the total is net")
    }

    // MARK: - New blocks: checks

    func testNewBlockChecks() throws {
        func problem(_ block: String) throws -> String? { CardChecks.problem(try card(#"{"eyebrow": "x", "blocks": [\#(block)]}"#)) }
        XCTAssertEqual(try problem(#"{"type": "award", "title": "a", "symbol": "flame.fill", "tier": "platinum"}"#), "blocks[0].tier: 'platinum' is not gold, silver or bronze")
        XCTAssertEqual(try problem(#"{"type": "award", "title": "a", "symbol": "no.such.symbol"}"#), "blocks[0].symbol: no SF Symbol named 'no.such.symbol'")
        XCTAssertEqual(try problem(#"{"type": "awards", "awards": [{"title": "a", "symbol": "flame", "earned": false, "progress": 3}]}"#),
                       "blocks[0].awards[0]: progress needs an of above zero")
        XCTAssertEqual(try problem(#"{"type": "tracker", "steps": [{"title": "a", "state": "current"}, {"title": "b", "state": "current"}]}"#),
                       "blocks[0].steps: at most one is current")
        XCTAssertEqual(try problem(#"{"type": "tracker", "steps": [{"title": "a", "state": "lost"}, {"title": "b"}]}"#),
                       "blocks[0].steps[0].state: 'lost' is not done, current, upcoming or failed")
        XCTAssertEqual(try problem(#"{"type": "map", "pins": [{"lat": 95, "lon": 0}]}"#), "blocks[0].pins[0]: 95.0, 0.0 is not a place on Earth")
        XCTAssertEqual(try problem(#"{"type": "map", "pins": []}"#), "blocks[0]: give pins, or a route of two points or more")
        XCTAssertEqual(try problem(#"{"type": "map", "height": 50, "pins": [{"lat": 1, "lon": 1}]}"#), "blocks[0].height: give 120 to 320 points")
        XCTAssertEqual(try problem(#"{"type": "qr", "payload": ""}"#), "blocks[0].payload is empty")
        XCTAssertEqual(try problem(#"{"type": "month", "month": "2026-02", "days": [{"day": 30}]}"#), "blocks[0].days[0].day: 30 is not in 2026-02")
        XCTAssertEqual(try problem(#"{"type": "month", "month": "2026-10", "days": [{"day": 3}, {"day": 3}]}"#), "blocks[0].days[1]: day 3 is marked twice")
        XCTAssertEqual(try problem(#"{"type": "month", "month": "Oct", "days": []}"#), "blocks[0].month: 'Oct' is not a YYYY-MM month")
        XCTAssertEqual(try problem(#"{"type": "pair", "before": {"path": "/no/a.png"}, "after": {"path": "/no/b.png"}}"#),
                       "blocks[0].before.path: no readable image at /no/a.png")
    }

    @MainActor
    func testTheMarginIsTransparentUnlessOpaqueIsAskedFor() throws {
        let card = Card(eyebrow: "x", blocks: [.text(TextBlock(text: "hello"))])
        func alphas(_ picture: RenderedCard) throws -> (corner: CGFloat, middle: CGFloat) {
            let image = try XCTUnwrap(NSBitmapImageRep(data: picture.png))
            return (image.colorAt(x: 2, y: 2)?.alphaComponent ?? -1, image.colorAt(x: image.pixelsWide / 2, y: image.pixelsHigh / 2)?.alphaComponent ?? -1)
        }
        for theme in CardTheme.allCases {
            let clear = try alphas(CardRenderer.render(card, theme: theme))
            XCTAssertEqual(clear.corner, 0, "\(theme): the margin lets the chat's background show")
            XCTAssertEqual(clear.middle, 1, "\(theme): the card itself is solid")
            XCTAssertEqual(try alphas(CardRenderer.render(card, theme: theme, opaque: true)).corner, 1, "\(theme): an opaque page fills the margin")
        }
        // …with the page's own colour: #F2F2F7 light (grouped background), black dark.
        let light = try XCTUnwrap(NSBitmapImageRep(data: CardRenderer.render(card, theme: .light, opaque: true).png)?.colorAt(x: 2, y: 2)?.usingColorSpace(.sRGB))
        // Colour management moves a channel by a unit or two; what matters is light grey, not white or black.
        for channel in [light.redComponent, light.greenComponent, light.blueComponent] { XCTAssertTrue((230...252).contains(channel * 255), "\(channel * 255)") }
        let dark = try XCTUnwrap(NSBitmapImageRep(data: CardRenderer.render(card, theme: .dark, opaque: true).png)?.colorAt(x: 2, y: 2)?.usingColorSpace(.sRGB))
        XCTAssertLessThan(dark.redComponent * 255, 10)
    }

    func testAQRCodeIsDrawn() throws {
        let code = try XCTUnwrap(QRCode.image("https://example.com"))
        XCTAssertEqual(code.width, code.height, "square")
        XCTAssertGreaterThanOrEqual(code.width, 21, "at least a version-1 code")
    }
}
