//
//  GalleryTests.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  Every example decodes, passes its checks and draws at phone width in both
//  themes. CARDKIT_GALLERY=<folder> also writes the PNGs there, to look at.
//

import AppKit
import Foundation
import XCTest

@testable import CardKit

final class GalleryTests: XCTestCase {

    /// The photos example points at files; these stand in for them, drawn here.
    func standInPictures() throws -> [String: String] {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cardkit-pictures")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var paths: [String: String] = [:]
        let skies: [(NSColor, NSColor)] = [(.systemOrange, .systemPurple), (.systemPink, .systemIndigo), (.systemYellow, .systemRed),
                                           (.systemTeal, .systemBlue), (.systemOrange, .systemRed), (.systemPurple, .systemBlue)]
        for (index, sky) in skies.enumerated() {
            let image = NSImage(size: NSSize(width: 300, height: 300), flipped: false) { rect in
                NSGradient(starting: sky.0, ending: sky.1)?.draw(in: rect, angle: 90)
                NSColor(calibratedRed: 0.93, green: 0.84, blue: 0.62, alpha: 1).setFill()
                NSBezierPath(rect: NSRect(x: 0, y: 0, width: 300, height: 90)).fill()
                NSColor.white.withAlphaComponent(0.9).setFill()
                NSBezierPath(ovalIn: NSRect(x: 110 + index * 8, y: 120, width: 70, height: 70)).fill()
                return true
            }
            let url = folder.appendingPathComponent("beach-\(index + 1).png")
            let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
            try bitmap.representation(using: .png, properties: [:])!.write(to: url)
            paths["~/Pictures/beach-\(index + 1).jpg"] = url.path
        }
        return paths
    }

    @MainActor
    func testEveryExampleDrawsInBothThemes() throws {
        let out = ProcessInfo.processInfo.environment["CARDKIT_GALLERY"].map { URL(fileURLWithPath: $0) }
        if let out { try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true) }
        let pictures = try standInPictures()
        let english = Locale(identifier: "en_GB")
        var seen = Set<String>()
        for example in CardExamples.all {
            var json = example.json
            for (placeholder, real) in pictures { json = json.replacingOccurrences(of: placeholder, with: real) }
            let card = try CardDecoder.card(from: Data(json.utf8))
            XCTAssertNil(CardChecks.problem(card), example.name)
            card.blocks.forEach { seen.insert($0.type) }
            for theme in CardTheme.allCases {
                let picture = try CardRenderer.render(card, theme: theme, locale: english)
                XCTAssertEqual(picture.width, 1254, "\(example.name): 390 pt + 2 × 14 pt, at 3×")
                XCTAssertGreaterThan(picture.height, 300, example.name)
                XCTAssertEqual(Array(picture.png.prefix(4)), [0x89, 0x50, 0x4E, 0x47], "PNG")
                if let out { try picture.png.write(to: out.appendingPathComponent("\(example.name)\(theme == .dark ? "-dark" : "").png")) }
            }
        }
        XCTAssertEqual(seen, Set(Block.types), "every block type has an example")
    }
}
