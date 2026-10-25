//
//  MoreViews.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  The blocks added in 0.2.0: award and awards (achievements), tracker,
//  map, qr, pair (before and after) and month.
//

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: - Medals

/// A medal: the symbol in white on a metallic or coloured disc with a lighter rim, Fitness Awards-style.
struct Medal: View {
    @Environment(\.cardTheme) var t
    var symbol: String; var tier: String?; var slot: Int?; var size: CGFloat; var earned = true; var progress: Double = 1

    var colors: [Color] {
        switch tier {
        case "gold": [hex(0xF9DD7A), hex(0xE2AE2A), hex(0xB7841B)]
        case "silver": [hex(0xF1F3F5), hex(0xC2C8CF), hex(0x8D959E)]
        case "bronze": [hex(0xF0C29A), hex(0xC98250), hex(0x96562A)]
        default: [t.slot(slot ?? 1).opacity(0.75), t.slot(slot ?? 1), t.slot(slot ?? 1)]
        }
    }

    var body: some View {
        ZStack {
            if earned {
                Circle().fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().stroke(Color.white.opacity(0.55), lineWidth: size * 0.04).padding(size * 0.07)
                Image(systemName: symbol).font(.system(size: size * 0.4, weight: .semibold)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            } else {
                Circle().fill(t.track)
                Circle().trim(from: 0, to: progress).stroke(t.slot(slot ?? 1), style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(size * 0.035)
                Image(systemName: symbol).font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(t.quiet)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(earned && !t.dark ? 0.12 : 0), radius: 4, y: 2)
    }
}

struct AwardBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardWords) var words
    var block: AwardBlock
    var body: some View {
        VStack(spacing: 10) {
            Medal(symbol: block.symbol, tier: block.tier, slot: block.slot, size: 112)
            Text(block.title).font(.system(size: 22, weight: .bold)).foregroundStyle(t.ink).multilineTextAlignment(.center)
            if let record = block.record {
                Text(record).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(t.ink).monospacedDigit()
                    .padding(.horizontal, 12).padding(.vertical, 5).background(Capsule().fill(t.panel))
            }
            if let detail = block.detail {
                Text(detail).font(Fonts.body).foregroundStyle(t.quiet).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            if let date = block.date { Text(words("earned", ["date": date])).font(Fonts.meta).foregroundStyle(t.quiet) }
        }.frame(maxWidth: .infinity).padding(.vertical, 6)
    }
}

struct AwardsBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardWords) var words
    var block: AwardsBlock
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockLabel(text: block.label)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: 3), spacing: 14) {
                ForEach(Array(block.awards.enumerated()), id: \.offset) { _, award in
                    VStack(spacing: 6) {
                        Medal(symbol: award.symbol, tier: award.tier, slot: award.slot, size: 64, earned: award.earned, progress: CardMath.progress(award))
                        Text(award.title).font(Fonts.meta.weight(.semibold)).foregroundStyle(award.earned ? t.ink : t.quiet)
                            .multilineTextAlignment(.center).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        if award.earned, let date = award.date {
                            Text(date).font(.system(size: 10)).foregroundStyle(t.quiet)
                        } else if !award.earned, let progress = award.progress, let of = award.of {
                            Text("\(CardMath.text(progress, whole: true)) " + words("of", ["total": CardMath.text(of, whole: true)])).font(.system(size: 10)).foregroundStyle(t.quiet)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tracker

struct TrackerBlockView: View {
    @Environment(\.cardTheme) var t
    var block: TrackerBlock
    var body: some View {
        let states = CardMath.states(block)
        Panel {
            BlockLabel(text: block.label)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(block.steps.enumerated()), id: \.offset) { index, step in
                    let state = states[index]
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            marker(state)
                            if index < block.steps.count - 1 {
                                Rectangle().fill(state == "done" ? t.good : t.track).frame(width: 2).frame(minHeight: 22)
                            }
                        }.frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(step.title).font(state == "current" ? Fonts.row.weight(.bold) : Fonts.row)
                                    .foregroundStyle(state == "upcoming" ? t.quiet : (state == "failed" ? t.criticalInk : t.ink))
                                Spacer(minLength: 6)
                                if let time = step.time { Text(time).font(Fonts.meta).foregroundStyle(t.quiet) }
                            }
                            if let detail = step.detail { Text(detail).font(Fonts.meta).foregroundStyle(t.quiet).fixedSize(horizontal: false, vertical: true) }
                        }.padding(.bottom, index < block.steps.count - 1 ? 10 : 0)
                    }
                }
            }
        }
    }

    @ViewBuilder func marker(_ state: String) -> some View {
        switch state {
        case "done":
            Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(t.good)
        case "current":
            Circle().fill(t.slot(1)).frame(width: 14, height: 14).padding(4).overlay(Circle().stroke(t.slot(1).opacity(0.35), lineWidth: 4))
        case "failed":
            Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(t.critical)
        default:
            Circle().stroke(t.quiet.opacity(0.6), lineWidth: 2).frame(width: 14, height: 14).padding(4)
        }
    }
}

// MARK: - Map

struct MapBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardWords) var words
    @Environment(\.cardMaps) var maps
    var block: MapBlock; var index: Int
    var body: some View {
        let height = CGFloat(block.height ?? 200)
        Group {
            if let image = maps[index] {
                Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    t.panel
                    VStack(spacing: 6) {
                        Image(systemName: "map").font(.system(size: 22)).foregroundStyle(t.quiet)
                        Text(words("map_unavailable")).font(Fonts.meta).foregroundStyle(t.quiet).multilineTextAlignment(.center)
                    }.padding()
                }
            }
        }
        .frame(width: Metric.inner, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Metric.panelRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metric.panelRadius, style: .continuous).stroke(t.divider, lineWidth: 0.5))
    }
}

// MARK: - QR

struct QRBlockView: View {
    @Environment(\.cardTheme) var t
    var block: QRBlock
    var body: some View {
        Panel(padding: 14) {
            HStack(spacing: 14) {
                if let code = QRCode.image(block.payload) {
                    Image(decorative: code, scale: 1).interpolation(.none).resizable().frame(width: 132, height: 132)
                        .padding(8).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let title = block.title { Text(title).font(Fonts.title).foregroundStyle(t.ink).fixedSize(horizontal: false, vertical: true) }
                    if let detail = block.detail { Text(detail).font(Fonts.meta).foregroundStyle(t.quiet).fixedSize(horizontal: false, vertical: true) }
                }
            }
        }
    }
}

enum QRCode {
    /// The payload as a QR code, one pixel a module (scaled up without smoothing), medium error correction.
    static func image(_ payload: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
}

// MARK: - Pair

struct PairBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardWords) var words
    var block: PairBlock
    var body: some View {
        let width = (Metric.inner - 8) / 2
        HStack(alignment: .top, spacing: 8) {
            side(block.before, label: block.before.caption ?? words("before"), width: width)
            side(block.after, label: block.after.caption ?? words("after"), width: width)
        }
    }

    func side(_ picture: Picture, label: String, width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image = NSImage(contentsOfFile: (picture.path as NSString).expandingTildeInPath) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill).frame(width: width, height: width * 1.25).clipped()
            }
            Text(label).font(Fonts.meta.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Color.black.opacity(0.55))).padding(8)
        }
        .frame(width: width, height: width * 1.25)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Month

struct MonthBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: MonthBlock
    var body: some View {
        let weeks = CardMath.monthGrid(block.month) ?? []
        let marks = Dictionary(block.days.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        let legendSlots = CardMath.slots((block.legend ?? []).map(\.slot))
        VStack(alignment: .leading, spacing: 10) {
            Text(CardMath.monthTitle(block.month, locale: locale) ?? block.month).font(Fonts.title).foregroundStyle(t.ink)
            Grid(horizontalSpacing: 0, verticalSpacing: 6) {
                GridRow {
                    ForEach(Array(weekdayInitials.enumerated()), id: \.offset) { _, letter in
                        Text(letter).font(Fonts.section).foregroundStyle(t.quiet).frame(maxWidth: .infinity)
                    }
                }
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    GridRow {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            cell(day, mark: day.flatMap { marks[$0] })
                        }
                    }
                }
            }
            if let legend = block.legend {
                Flow(spacing: 12) {
                    ForEach(Array(legend.enumerated()), id: \.offset) { i, tag in LegendKey(color: t.slot(legendSlots[i]), text: tag.name, square: true) }
                }
            }
        }
    }

    /// Monday first, in the reader's language.
    var weekdayInitials: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }

    @ViewBuilder func cell(_ day: Int?, mark: MonthDay?) -> some View {
        if let day {
            let color = mark.map { m in m.status.map { t.look($0).mark } ?? t.slot(m.slot ?? 1) }
            Text("\(day)").font(.system(size: 14, weight: mark != nil ? .semibold : .regular, design: .rounded)).monospacedDigit()
                .foregroundStyle(color != nil ? Color.white : t.ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color ?? .clear))
                .overlay(Circle().stroke(day == block.today ? t.ink : .clear, lineWidth: 2).padding(-2))
                .frame(maxWidth: .infinity)
        } else {
            Color.clear.frame(height: 32).frame(maxWidth: .infinity)
        }
    }
}
