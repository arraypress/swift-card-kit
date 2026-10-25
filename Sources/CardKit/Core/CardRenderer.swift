//
//  CardRenderer.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  A card to PNG bytes, headless. ImageRenderer belongs to the main actor;
//  from a task thread it does not draw.
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
    @MainActor
    public static func render(_ card: Card, theme: CardTheme = .light, locale: Locale = .current, scale: CGFloat = 3) throws -> RenderedCard {
        if let problem = CardChecks.problem(card) { throw CardError.invalid(problem) }
        let palette = Theme.of(theme)
        let view = CardView(card: card)
            .environment(\.cardTheme, palette)
            .environment(\.cardLocale, locale)
            .environment(\.colorScheme, theme == .dark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CardError.drawing
        }
        return RenderedCard(png: data, width: image.width, height: image.height)
    }
}
