//
//  Theme.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  The design language as tokens, in Apple's terms: grouped-background
//  surfaces, label colours, system fills and separators, SF Pro with SF
//  Rounded numbers, continuous corners. Light and dark are the same layout
//  with these values swapped.
//
//  Status uses Apple's system green, orange and red for marks and Apple's
//  high-contrast steps of the same for words (≥ 4.5:1 on the card). Parts use
//  the reference data-viz palette in slot order: Apple's own hues were
//  measured and cannot pass colour-blind separation once green, orange and
//  red are kept for status (2026-10-26, every 4-, 5- and 6-slot order tried).
//

import SwiftUI

struct Theme: Sendable {
    /// systemGroupedBackground, secondarySystemGroupedBackground, tertiarySystemGroupedBackground.
    var page: Color, card: Color, panel: Color
    /// label, secondaryLabel (stepped for contrast), systemFill-like track, separator.
    var ink: Color, quiet: Color, track: Color, divider: Color
    /// Status: a mark colour (Apple system colour) and its high-contrast step for words.
    var good: Color, goodInk: Color, over: Color, overInk: Color, critical: Color, criticalInk: Color
    /// Parts, in slot order: blue, orange, aqua, yellow, magenta, green, violet, red.
    var slots: [Color]
    /// The sequential ramp (heatmaps), lightest to darkest, starting from the track.
    var ramp: [Color]
    var dark: Bool

    static let light = Theme(
        page: hex(0xF2F2F7), card: .white, panel: hex(0xF2F2F7),
        ink: hex(0x1D1D1F), quiet: hex(0x6E6E73), track: hex(0xE5E5EA), divider: hex(0xE5E5EA),
        good: hex(0x34C759), goodInk: hex(0x248A3D), over: hex(0xFF9500), overInk: hex(0xC93400),
        critical: hex(0xFF3B30), criticalInk: hex(0xD70015),
        slots: [0x2A78D6, 0xEB6834, 0x1BAF7A, 0xEDA100, 0xE87BA4, 0x008300, 0x6250D6, 0xE34948].map(hex),
        ramp: [0xEBEDF0, 0xB7D3F6, 0x6DA7EC, 0x2A78D6, 0x184F95].map(hex),
        dark: false)

    /// Apple's elevated dark colours (what sheets, popovers and widgets use above a background): a card that stands
    /// out on Messages' #252525 on a Mac (MEASURED from a screenshot, 2026-10-26 — #1C1C1E vanished into it) and on
    /// an iPhone's black alike.
    static let dark = Theme(
        page: .black, card: hex(0x2C2C2E), panel: hex(0x3A3A3C),
        ink: hex(0xF5F5F7), quiet: hex(0xA1A1A8), track: hex(0x48484A), divider: hex(0x48484A),
        good: hex(0x30D158), goodInk: hex(0x30D158), over: hex(0xFF9F0A), overInk: hex(0xFF9F0A),
        critical: hex(0xFF453A), criticalInk: hex(0xFF6961),
        slots: [0x3987E5, 0xD95926, 0x199E70, 0xC98500, 0xD55181, 0x008300, 0x9085E9, 0xE66767].map(hex),
        ramp: [0x3A3A3C, 0x184F95, 0x256ABF, 0x3987E5, 0x86B6EF].map(hex),
        dark: true)

    static func of(_ theme: CardTheme) -> Theme { theme == .dark ? dark : light }

    /// A part's colour by its 1-based slot.
    func slot(_ number: Int) -> Color { slots[(max(1, number) - 1) % slots.count] }
}

func hex(_ value: Int) -> Color {
    Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
}

/// The type scale. SF Pro for words, SF Rounded for the numbers that matter, tabular digits where they line up.
enum Fonts {
    static let eyebrow = Font.system(size: 14, weight: .medium)
    static let hero = Font.system(size: 44, weight: .bold, design: .rounded)
    static let heroUnit = Font.system(size: 17, weight: .medium, design: .rounded)
    static let heroWords = Font.system(size: 28, weight: .bold)
    static let figure = Font.system(size: 20, weight: .bold, design: .rounded)
    static let title = Font.system(size: 17, weight: .semibold)
    static let row = Font.system(size: 15, weight: .medium)
    static let body = Font.system(size: 14)
    static let meta = Font.system(size: 12)
    static let section = Font.system(size: 11, weight: .semibold)
    static let footnote = Font.system(size: 11)
}

/// Spacing and shape: 390 pt card (1,254 px at 3× with the page margin), continuous corners.
enum Metric {
    static let width: CGFloat = 390, pad: CGFloat = 20, gap: CGFloat = 16, margin: CGFloat = 14
    static let cardRadius: CGFloat = 26, panelRadius: CGFloat = 16, bar: CGFloat = 8
    /// The width blocks have inside the card.
    static let inner: CGFloat = width - 2 * pad
}
