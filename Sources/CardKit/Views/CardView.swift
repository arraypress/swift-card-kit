//
//  CardView.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  A whole card in the one order every card follows:
//  eyebrow → hero → status → blocks → footnote.
//

import SwiftUI

struct CardView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var card: Card

    var body: some View {
        CardShell {
            Eyebrow(text: card.eyebrow)
            if let hero = CardMath.hero(card, locale: locale) { HeroView(hero: hero) }
            if let status = CardMath.status(card, locale: locale) { StatusLine(status: status).padding(.top, -8) }
            ForEach(Array(card.blocks.enumerated()), id: \.offset) { index, block in BlockView(block: block, index: index) }
            if let footnote = card.footnote, !footnote.isEmpty { Footnote(text: footnote) }
        }
    }
}

struct HeroView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var hero: Hero

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let symbol = hero.symbol {
                Image(systemName: symbol).symbolRenderingMode(.multicolor).font(.system(size: 42)).frame(minWidth: 48)
            }
            VStack(alignment: .leading, spacing: 4) {
                HeroNumber(value: CardMath.text(hero.value, locale: locale), unit: hero.unit)
                if hero.label != nil || !(hero.tags ?? []).isEmpty {
                    HStack(spacing: 8) {
                        if let label = hero.label { Text(label).font(Fonts.title).foregroundStyle(t.ink).lineLimit(1) }
                        let slots = CardMath.slots((hero.tags ?? []).map(\.slot))
                        ForEach(Array((hero.tags ?? []).enumerated()), id: \.offset) { i, tag in TagChip(text: tag.name, color: t.slot(slots[i])) }
                    }
                }
                if let detail = hero.detail { Text(detail).font(Fonts.body).foregroundStyle(t.ink).fixedSize(horizontal: false, vertical: true) }
            }
        }
    }
}
