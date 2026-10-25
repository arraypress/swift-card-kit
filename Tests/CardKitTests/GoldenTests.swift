//
//  GoldenTests.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  Every example against a reference picture (light, 1×) kept in Golden/, so
//  a change to the look shows up by name. A macOS update can move a font by a
//  pixel, so a difference is a warning unless CARDKIT_GOLDEN_STRICT=1;
//  CARDKIT_GOLDEN_UPDATE=1 redraws the references after a deliberate change.
//  Maps are left out (they come from the network).
//

import AppKit
import Foundation
import XCTest

@testable import CardKit

final class GoldenTests: XCTestCase {

    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Golden")

    /// The share of pixels that differ by more than 24 in any channel; 1 if the sizes differ.
    static func difference(_ a: CGImage, _ b: CGImage) -> Double {
        guard a.width == b.width, a.height == b.height else { return 1 }
        func pixels(_ image: CGImage) -> [UInt8] {
            var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = CGContext(data: &data, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return data
        }
        let x = pixels(a), y = pixels(b)
        var differing = 0
        for i in stride(from: 0, to: x.count, by: 4) where (0..<3).contains(where: { abs(Int(x[i + $0]) - Int(y[i + $0])) > 24 }) {
            differing += 1
        }
        return Double(differing) / Double(a.width * a.height)
    }

    @MainActor
    func testExamplesMatchTheirReferences() throws {
        let environment = ProcessInfo.processInfo.environment
        let update = environment["CARDKIT_GOLDEN_UPDATE"] == "1", strict = environment["CARDKIT_GOLDEN_STRICT"] == "1"
        if update { try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true) }
        let pictures = try GalleryTests().standInPictures()
        var changed: [String] = []
        for example in CardExamples.all {
            var json = example.json
            for (placeholder, real) in pictures { json = json.replacingOccurrences(of: placeholder, with: real) }
            let card = try CardDecoder.card(from: Data(json.utf8))
            if card.blocks.contains(where: { $0.type == "map" }) { continue }
            let picture = try CardRenderer.render(card, theme: .light, locale: Locale(identifier: "en_GB"), scale: 1)
            let reference = Self.folder.appendingPathComponent("\(example.name).png")
            if update { try picture.png.write(to: reference); continue }
            guard let stored = NSImage(contentsOf: reference)?.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let drawn = NSImage(data: picture.png)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                changed.append("\(example.name) (no reference: CARDKIT_GOLDEN_UPDATE=1)"); continue
            }
            let share = Self.difference(stored, drawn)
            if share > 0.005 { changed.append("\(example.name) (\(String(format: "%.1f", share * 100)) % of pixels)") }
        }
        if !changed.isEmpty {
            let message = "looks changed: " + changed.joined(separator: ", ") + " — check them, then CARDKIT_GOLDEN_UPDATE=1 if meant"
            if strict { XCTFail(message) } else { print("warning: \(message)") }
        }
    }

    func testTheDifferenceMeasure() throws {
        func image(_ fill: NSColor, width: Int = 10, height: Int = 10) -> CGImage {
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.setFillColor(fill.cgColor); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.setFillColor(NSColor.black.cgColor); context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            return context.makeImage()!
        }
        XCTAssertEqual(Self.difference(image(.white), image(.white)), 0)
        XCTAssertEqual(Self.difference(image(.white), image(NSColor(white: 0.95, alpha: 1))), 0, "a faint shade is noise, not change")
        XCTAssertEqual(Self.difference(image(.white), image(.red)), 0.99, accuracy: 1e-9, "every pixel but the shared black one")
        XCTAssertEqual(Self.difference(image(.white), image(.white, width: 11)), 1, "a different size is all change")
        XCTAssertEqual(Self.difference(image(.white), image(.white, height: 12)), 1, "a card grown taller is change too")
    }
}
