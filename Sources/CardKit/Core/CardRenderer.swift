//
//  CardRenderer.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  A card to PNG bytes, headless. ImageRenderer belongs to the main actor;
//  from a task thread it does not draw. Maps are the one part that needs the
//  network: `maps(for:)` fetches them first, and `render` draws what it's given
//  (a map it wasn't given says so on the card).
//

import AppKit
import SwiftUI

/// A drawn card.
public struct RenderedCard: Sendable {
    public var png: Data
    public var width: Int
    public var height: Int
}

public enum CardRenderer {

    /// Checks the card, then draws it at `scale` (3 → 1,254 px wide, phone width). Throws
    /// ``CardError/invalid(_:)`` naming the field when the card cannot be drawn.
    ///
    /// The margin around the card is transparent, so in a chat the card sits on the conversation's background;
    /// `opaque` fills it with the theme's page colour instead (for documents and galleries).
    @MainActor
    public static func render(_ card: Card, theme: CardTheme = .light, locale: Locale = .current, scale: CGFloat = 3,
                              maps: [Int: CGImage] = [:], opaque: Bool = false) throws -> RenderedCard {
        if let problem = CardChecks.problem(card) { throw CardError.invalid(problem) }
        let view = CardView(card: card)
            .environment(\.cardTheme, Theme.of(theme))
            .environment(\.cardLocale, locale)
            .environment(\.cardWords, Words(card.wording))
            .environment(\.cardMaps, maps)
            .environment(\.cardOpaque, opaque)
            .environment(\.colorScheme, theme == .dark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = opaque
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CardError.drawing
        }
        return RenderedCard(png: data, width: image.width, height: image.height)
    }

    /// The card's maps, fetched from Apple Maps and drawn with their pins and route, by block index. A map that
    /// can't be fetched (no network) is left out, and the card says so where it would be.
    public static func maps(for card: Card, theme: CardTheme = .light, scale: CGFloat = 3) async -> [Int: CGImage] {
        var found: [Int: CGImage] = [:]
        for (index, block) in card.blocks.enumerated() {
            guard case .map(let map) = block else { continue }
            if let image = await MapSnapshot.image(map, theme: theme, scale: scale) { found[index] = image }
        }
        return found
    }
}
