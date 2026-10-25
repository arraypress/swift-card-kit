//
//  BlockViews.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  The blocks that are rows, figures and words: list, tiles, breakdown,
//  limits, segmented, hourly, chips, comparison, table, score, text, images.
//  The charts are in ChartViews.
//

import AppKit
import SwiftUI

/// One block, by its type.
struct BlockView: View {
    var block: Block
    var body: some View {
        switch block {
        case .list(let b): ListBlockView(block: b)
        case .tiles(let b): TilesBlockView(block: b)
        case .breakdown(let b): BreakdownBlockView(block: b)
        case .limits(let b): LimitsBlockView(block: b)
        case .bars(let b): BarsBlockView(block: b)
        case .trend(let b): TrendBlockView(block: b)
        case .range(let b): RangeBlockView(block: b)
        case .hourly(let b): HourlyBlockView(block: b)
        case .rings(let b): RingsBlockView(block: b)
        case .gauges(let b): GaugesBlockView(block: b)
        case .segmented(let b): SegmentedBlockView(block: b)
        case .timeline(let b): TimelineBlockView(block: b)
        case .heatmap(let b): HeatmapBlockView(block: b)
        case .sparklines(let b): SparklinesBlockView(block: b)
        case .chips(let b): ChipsBlockView(block: b)
        case .comparison(let b): ComparisonBlockView(block: b)
        case .table(let b): TableBlockView(block: b)
        case .score(let b): ScoreBlockView(block: b)
        case .text(let b): TextBlockView(block: b)
        case .images(let b): ImagesBlockView(block: b)
        }
    }
}

/// A block's own small-capitals label, when it has one.
struct BlockLabel: View {
    var text: String?
    var body: some View { if let text, !text.isEmpty { SectionLabel(text: text) } }
}

// MARK: - list

struct ListBlockView: View {
    @Environment(\.cardTheme) var t
    var block: ListBlock
    var body: some View {
        Panel {
            BlockLabel(text: block.label)
            ForEach(Array(block.rows.enumerated()), id: \.offset) { _, row in RowView(row: row) }
        }
    }
}

// MARK: - tiles

struct TilesBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: TilesBlock
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(Array(block.tiles.enumerated()), id: \.offset) { _, tile in
                Panel(padding: 12) {
                    HStack(spacing: 5) {
                        if let symbol = tile.symbol { Image(systemName: symbol).symbolRenderingMode(.multicolor) }
                        Text(tile.label).lineLimit(1)
                    }.font(Fonts.meta).foregroundStyle(t.quiet)
                    Text(CardMath.text(tile.value, unit: tile.unit, whole: true, locale: locale))
                        .font(Fonts.figure).foregroundStyle(t.ink).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                    if let detail = tile.detail {
                        HStack(spacing: 4) {
                            if let status = tile.status, let icon = t.look(status).icon { Image(systemName: icon).foregroundStyle(t.look(status).ink) }
                            Text(detail).foregroundStyle(tile.status.map { t.look($0).ink } ?? t.quiet).lineLimit(2)
                        }.font(Fonts.meta)
                    }
                }.frame(maxHeight: .infinity, alignment: .top)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - breakdown

struct BreakdownBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: BreakdownBlock
    var body: some View {
        let ordered = CardMath.ordered(block.rows)
        let shares = CardMath.shares(ordered.map { CardMath.double($0.part.value) })
        let top = ordered.first.map { CardMath.double($0.part.value) } ?? 1
        let changes = ordered.contains { $0.part.previous != nil }
        Panel {
            BlockLabel(text: block.label)
            ForEach(Array(ordered.enumerated()), id: \.offset) { index, entry in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Dot(color: t.slot(entry.slot))
                        Text(entry.part.name).font(Fonts.row).foregroundStyle(t.ink).lineLimit(1)
                        Spacer(minLength: 6)
                        Text(CardMath.text(entry.part.value, unit: block.unit, whole: true, locale: locale)).font(Fonts.row).foregroundStyle(t.ink).monospacedDigit().fixedSize()
                        Text("\(shares[index]) %").font(Fonts.meta).foregroundStyle(t.quiet).monospacedDigit().frame(width: 36, alignment: .trailing)
                    }
                    HStack(spacing: 8) {
                        GeometryReader { g in
                            Capsule().fill(t.slot(entry.slot)).frame(width: max(6, g.size.width * (top > 0 ? CardMath.double(entry.part.value) / top : 0)))
                        }.frame(height: Metric.bar)
                        if changes { change(CardMath.change(entry.part)).frame(width: 64, alignment: .trailing) }
                    }
                }
            }
        }
    }

    @ViewBuilder func change(_ change: CardMath.Change?) -> some View {
        let parts: (String, String)? = switch change {
            case .up(let a): ("arrow.up", CardMath.text(a, unit: block.unit, whole: true, locale: locale))
            case .down(let a): ("arrow.down", CardMath.text(a, unit: block.unit, whole: true, locale: locale))
            case .same: ("equal", "same")
            case nil: nil
        }
        if let parts {
            HStack(spacing: 2) {
                Image(systemName: parts.0).font(.system(size: 9, weight: .bold))
                Text(parts.1)
            }.font(Fonts.meta.monospacedDigit()).foregroundStyle(t.quiet)
        } else {
            Text("new").font(Fonts.meta).foregroundStyle(t.quiet)
        }
    }
}

// MARK: - limits

struct LimitsBlockView: View {
    @Environment(\.cardTheme) var t
    var block: LimitsBlock
    var body: some View {
        let totals = CardMath.totals(block)
        VStack(alignment: .leading, spacing: Metric.gap) {
            if block.rows.count > 1 { LimitBar(value: totals.used, of: totals.limit, color: t.ink.opacity(t.dark ? 0.85 : 0.8)) }
            Panel {
                BlockLabel(text: block.label)
                ForEach(Array(CardMath.ordered(block).enumerated()), id: \.offset) { _, entry in
                    LimitRowView(row: entry.row, slot: entry.slot, unit: block.unit)
                }
            }
        }
    }
}

// MARK: - segmented

struct SegmentedBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: SegmentedBlock
    var body: some View {
        let (pieces, rest) = CardMath.segments(block)
        let shares = CardMath.shares(pieces.map(\.fraction) + (rest > 0 ? [rest] : []))
        VStack(alignment: .leading, spacing: 12) {
            BlockLabel(text: block.label)
            GeometryReader { g in
                let gaps = CGFloat(max(0, pieces.count - (rest > 0 ? 0 : 1))) * 2
                let width = g.size.width - gaps
                HStack(spacing: 2) {
                    ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                        Rectangle().fill(t.slot(piece.slot)).frame(width: max(2, width * piece.fraction))
                    }
                    if rest > 0 { Rectangle().fill(t.track) }
                }.clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }.frame(height: 18)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(Array(pieces.enumerated()), id: \.offset) { index, piece in
                    legend(t.slot(piece.slot), piece.part.name, CardMath.text(piece.part.value, unit: block.unit, whole: true, locale: locale), shares[index])
                }
                if rest > 0, let of = block.of {
                    let free = CardMath.minus(of, CardMath.sum(block.parts.map(\.value)) ?? Amount(0))
                    legend(t.track, block.restLabel ?? "Free", CardMath.text(free, unit: block.unit, whole: true, locale: locale), shares.last ?? 0)
                }
            }
        }
    }

    func legend(_ color: Color, _ name: String, _ value: String, _ share: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Dot(color: color, size: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(Fonts.body.weight(.medium)).foregroundStyle(t.ink).lineLimit(1)
                Text("\(value) · \(share) %").font(Fonts.meta).foregroundStyle(t.quiet).monospacedDigit()
            }
        }
    }
}

// MARK: - hourly

struct HourlyBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: HourlyBlock
    var body: some View {
        Panel {
            BlockLabel(text: block.label)
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(block.items.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 7) {
                        Text(item.label).font(Fonts.meta.weight(.medium)).foregroundStyle(t.quiet)
                        Image(systemName: item.symbol ?? "circle.dotted").symbolRenderingMode(.multicolor).font(.system(size: 20)).frame(height: 22)
                        Text(CardMath.text(item.value, locale: locale)).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(t.ink)
                        if let detail = item.detail { Text(detail).font(Fonts.meta).foregroundStyle(t.slot(1)) }
                    }.frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - chips

struct ChipsBlockView: View {
    @Environment(\.cardTheme) var t
    var block: ChipsBlock
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BlockLabel(text: block.label)
            Flow { ForEach(Array(block.chips.enumerated()), id: \.offset) { _, chip in chipView(chip) } }
        }
    }

    func chipView(_ chip: Chip) -> some View {
        let maybe = chip.maybe == true
        let color: Color? = chip.status.map { t.look($0).mark == t.quiet ? nil : t.look($0).mark } ?? chip.slot.map(t.slot)
        let strong = chip.status == .critical && !maybe
        return HStack(spacing: 5) {
            if let slot = chip.slot, chip.status == nil { Dot(color: t.slot(slot), size: 7) }
            Text(chip.text).font(Fonts.meta.weight(chip.status == nil ? .medium : .semibold))
                .foregroundStyle(strong ? .white : chip.status.map { t.look($0).ink } ?? t.ink)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(strong ? t.critical : (chip.status != nil ? (color ?? t.quiet).opacity(0.14) : t.panel)))
        .overlay(Capsule().stroke((color ?? t.quiet).opacity(maybe ? 0.75 : 0), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
        .fixedSize()
    }
}

// MARK: - comparison

struct ComparisonBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: ComparisonBlock
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(block.options.enumerated()), id: \.offset) { _, option in tile(option) }
            }.fixedSize(horizontal: false, vertical: true)
            if let reason = block.reason { Text(reason).font(Fonts.body).foregroundStyle(t.ink).fixedSize(horizontal: false, vertical: true) }
        }
    }

    func tile(_ option: Choice) -> some View {
        let best = option.best == true
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(option.name).font(Fonts.title).foregroundStyle(t.ink).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if best { Image(systemName: "checkmark.circle.fill").foregroundStyle(t.good) }
            }
            Text(CardMath.text(option.value, unit: option.unit, whole: true, locale: locale)).font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(t.ink).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            if let detail = option.detail { Text(detail).font(Fonts.meta).foregroundStyle(t.quiet) }
            ForEach(Array((option.lines ?? []).enumerated()), id: \.offset) { _, line in
                Text(line).font(Fonts.meta).foregroundStyle(t.ink).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(best ? t.good.opacity(0.08) : t.panel))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(best ? t.good : .clear, lineWidth: 2))
    }
}

// MARK: - table

/// Rows of figures: the first column takes the room, the others fit their longest cell, numbers to the right.
struct TableBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: TableBlock
    var body: some View {
        let cells = block.rows.map { $0.map { CardMath.text($0, locale: locale) } }
        let widths = block.columns.indices.map { column in
            CGFloat(([block.columns[column].title.count] + cells.map { $0[column].count }).max() ?? 1) * 8.5 + 6
        }
        Panel {
            BlockLabel(text: block.label)
            VStack(spacing: 0) {
                row(block.columns.map { $0.title.uppercased() }, widths: widths, header: true, strong: false)
                    .padding(.bottom, 6).padding(.horizontal, 6)
                ForEach(Array(cells.enumerated()), id: \.offset) { index, cellRow in
                    Divider().overlay(t.divider)
                    row(cellRow, widths: widths, header: false, strong: index == block.highlight)
                        .padding(.vertical, 7).padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(index == block.highlight ? t.slot(1).opacity(0.12) : .clear))
                }
            }
        }
    }

    func row(_ texts: [String], widths: [CGFloat], header: Bool, strong: Bool) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(texts.enumerated()), id: \.offset) { column, text in
                let leading = alignment(column) == .leading
                Text(text)
                    .font(header ? Fonts.section : (strong || column == 0 ? Fonts.body.weight(strong ? .bold : .medium) : Fonts.body))
                    .tracking(header ? 0.4 : 0).monospacedDigit().foregroundStyle(header ? t.quiet : t.ink).lineLimit(1)
                    .frame(maxWidth: column == 0 ? .infinity : nil, alignment: leading ? .leading : .trailing)
                    .frame(width: column == 0 ? nil : widths[column], alignment: leading ? .leading : .trailing)
            }
        }
    }

    func alignment(_ index: Int) -> HorizontalAlignment {
        if let align = block.columns[index].align { return align == "leading" ? .leading : .trailing }
        return index == 0 ? .leading : .trailing
    }
}

// MARK: - score

struct ScoreBlockView: View {
    @Environment(\.cardTheme) var t
    var block: ScoreBlock
    var body: some View {
        Panel(padding: 16) {
            HStack(alignment: .center, spacing: 8) {
                side(block.home, alignment: .leading)
                VStack(spacing: 4) {
                    Text("\(block.home.score) – \(block.away.score)").font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(t.ink).monospacedDigit().fixedSize()
                    Text(block.state).font(Fonts.meta.weight(.semibold)).foregroundStyle(t.quiet)
                        .padding(.horizontal, 8).padding(.vertical, 2).background(Capsule().fill(t.track))
                }
                side(block.away, alignment: .trailing)
            }
            if let detail = block.detail {
                Text(detail).font(Fonts.meta).foregroundStyle(t.quiet).frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }
        }
    }

    func side(_ side: Side, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(side.name).font(Fonts.title).foregroundStyle(t.ink).lineLimit(2).multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            if let detail = side.detail { Text(detail).font(Fonts.meta).foregroundStyle(t.quiet).lineLimit(2) }
        }.frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

// MARK: - text

struct TextBlockView: View {
    @Environment(\.cardTheme) var t
    var block: TextBlock
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BlockLabel(text: block.label)
            HStack(alignment: .top, spacing: 10) {
                if block.quote == true { RoundedRectangle(cornerRadius: 1.5).fill(t.slot(1)).frame(width: 3) }
                VStack(alignment: .leading, spacing: 6) {
                    if let text = block.text, !text.isEmpty {
                        Text(text).font(.system(size: 15)).foregroundStyle(t.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array((block.bullets ?? []).enumerated()), id: \.offset) { _, bullet in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(t.quiet).frame(width: 5, height: 5).alignmentGuide(.firstTextBaseline) { $0[.bottom] + 4 }
                            Text(bullet).font(.system(size: 15)).foregroundStyle(t.ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }.fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - images

struct ImagesBlockView: View {
    @Environment(\.cardTheme) var t
    var block: ImagesBlock
    var body: some View {
        let columns = block.columns ?? (block.images.count == 1 ? 1 : 3)
        let size = (Metric.inner - CGFloat(columns - 1) * 6) / CGFloat(columns)
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(size), spacing: 6), count: columns), alignment: .leading, spacing: 8) {
            ForEach(Array(block.images.enumerated()), id: \.offset) { _, picture in
                VStack(alignment: .leading, spacing: 4) {
                    if let image = NSImage(contentsOfFile: (picture.path as NSString).expandingTildeInPath) {
                        if columns == 1 {
                            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).frame(width: size)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill).frame(width: size, height: size)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    if let caption = picture.caption { Text(caption).font(Fonts.meta).foregroundStyle(t.quiet).lineLimit(2) }
                }
            }
        }
    }
}
