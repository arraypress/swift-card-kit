//
//  ChartViews.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  The chart blocks, drawn the way Apple's apps draw them: Swift Charts with
//  recessive axes on the trailing side, the current bar or point strong and
//  the rest lighter, dashed reference lines, rounded marks.
//

import Charts
import SwiftUI

/// A dashed line's sample and name, for chart legends.
struct LegendKey: View {
    @Environment(\.cardTheme) var t
    var color: Color; var text: String; var width: CGFloat = 2; var dashed = false; var square = false
    var body: some View {
        HStack(spacing: 6) {
            if square {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            } else {
                Path { p in p.move(to: CGPoint(x: 0, y: 4)); p.addLine(to: CGPoint(x: 16, y: 4)) }
                    .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dashed ? [3, 3] : []))
                    .frame(width: 16, height: 8)
            }
            Text(text).font(Fonts.meta).foregroundStyle(t.quiet)
        }
    }
}

/// The y-axis every chart shares: trailing labels, hairline grid, no axis line.
@AxisContentBuilder
func quietYAxis(ticks: [Double], label: @escaping (Double) -> String, t: Theme) -> some AxisContent {
    AxisMarks(position: .trailing, values: ticks) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(t.divider)
        AxisValueLabel { if let v = value.as(Double.self) { Text(label(v)).font(Fonts.meta).foregroundStyle(t.quiet) } }
    }
}

// MARK: - bars

struct BarsBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: BarsBlock

    var body: some View {
        let top = CardMath.scaleTop(block)
        let strong = CardMath.highlighted(block)
        let currency = block.bars.compactMap { $0.value?.currency ?? $0.parts?.first?.currency }.first
        let label = { (v: Double) in CardMath.text(Amount(Decimal(v), currency: currency), whole: true, locale: locale) }
        let count = block.bars.count
        let every = count > 14 ? Int((Double(count) / 7).rounded(.up)) : 1
        let legendSlots = CardMath.slots((block.legend ?? []).map(\.slot))
        let marks = CardMath.stacks(block)
        // A 2 pt surface gap between stacked parts, in the chart's units (the plot is 160 pt tall).
        let gap = top * 2 / 160
        let barWidth = CGFloat((Double(Metric.inner) - 52) / Double(max(count, 1)) * 0.62)
        VStack(alignment: .leading, spacing: 10) {
            BlockLabel(text: block.label)
            Chart {
                if let band = block.band {
                    RectangleMark(xStart: .value("x", -0.5), xEnd: .value("x", Double(count) - 0.5),
                                  yStart: .value("low", CardMath.double(band.low)), yEnd: .value("high", CardMath.double(band.high)))
                        .foregroundStyle(t.good.opacity(0.13))
                }
                // One flat list with an id per mark: Charts drops marks whose ids repeat, as nested ForEach offsets do.
                ForEach(marks, id: \.id) { mark in
                    // A numeric x axis has no bands, so a ratio width is zero: the width is worked out from the plot.
                    BarMark(x: .value("x", Double(mark.bar)), yStart: .value("from", mark.from), yEnd: .value("to", mark.top ? mark.to : max(mark.from, mark.to - gap)),
                            width: .fixed(barWidth))
                        .foregroundStyle(t.slot(mark.slot).opacity(mark.bar == strong ? 1 : 0.38))
                        .cornerRadius(mark.top ? min(4, barWidth / 3) : 0)
                }
                if let goal = block.goal {
                    RuleMark(y: .value("goal", CardMath.double(goal))).foregroundStyle(t.goodInk)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
                if block.average == true, let average = CardMath.average(block) {
                    RuleMark(y: .value("avg", average)).foregroundStyle(t.ink.opacity(0.55)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
            }
            .chartXScale(domain: -0.5...(Double(count) - 0.5))
            .chartYScale(domain: 0...top)
            .chartXAxis {
                AxisMarks(values: Array(stride(from: 0, to: count, by: every)).map(Double.init)) { value in
                    AxisValueLabel(centered: false) {
                        if let v = value.as(Double.self), block.bars.indices.contains(Int(v)) {
                            Text(block.bars[Int(v)].label).font(Fonts.meta.weight(Int(v) == strong ? .semibold : .regular))
                                .foregroundStyle(Int(v) == strong ? t.ink : t.quiet)
                        }
                    }
                }
            }
            .chartYAxis { quietYAxis(ticks: CardMath.ticks(top: top), label: label, t: t) }
            .frame(height: 160)
            if let legend = block.legend {
                Flow(spacing: 12) {
                    ForEach(Array(legend.enumerated()), id: \.offset) { i, tag in LegendKey(color: t.slot(legendSlots[i]), text: tag.name, square: true) }
                }
            } else if block.goal != nil || block.band != nil || block.average == true {
                HStack(spacing: 14) {
                    if let goal = block.goal { LegendKey(color: t.goodInk, text: "Goal \(label(CardMath.double(goal)))", width: 1.5, dashed: true) }
                    if block.band != nil { LegendKey(color: t.good.opacity(0.35), text: "Target band", square: true) }
                    if block.average == true, let average = CardMath.average(block) {
                        LegendKey(color: t.ink.opacity(0.55), text: "Average \(label(average))", width: 1, dashed: true)
                    }
                }
            }
        }
    }
}

// MARK: - trend

struct TrendBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: TrendBlock

    var body: some View {
        let first = block.series[0]
        let currency = first.points.first?.value.currency
        let all = block.series.flatMap(\.points).map { CardMath.double($0.value) } + [block.target.map { CardMath.double($0.value) }].compactMap { $0 }
        let low = all.min() ?? 0, high = all.max() ?? 1
        let running = block.target != nil || low >= 0 && (first.points.first.map { CardMath.double($0.value) } ?? 0) <= high * 0.15
        let bottom = running ? 0 : low - (high - low) * 0.15
        let top = running ? CardMath.niceCeiling(high) : high + (high - low) * 0.15
        let xs = block.series.flatMap(\.points).map(\.x)
        let xStart = xs.min() ?? 0, xEnd = block.end ?? block.target?.at ?? xs.max() ?? 1
        let label = { (v: Double) in CardMath.text(Amount(Decimal(v.rounded()), currency: currency), whole: true, locale: locale) }
        let smoothed = block.smooth.map { CardMath.movingAverage(first.points.map { CardMath.double($0.value) }, window: $0) }
        let last = first.points.last!
        let references = block.series.dropFirst().enumerated().flatMap { s, series in
            series.points.enumerated().map { i, point in (id: "\(s)-\(i)", series: s, x: point.x, y: CardMath.double(point.value)) }
        }
        VStack(alignment: .leading, spacing: 10) {
            BlockLabel(text: block.label)
            Chart {
                if let target = block.target {
                    LineMark(x: .value("x", xStart), y: .value("v", 0.0), series: .value("s", "target"))
                        .foregroundStyle(t.quiet).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    LineMark(x: .value("x", target.at), y: .value("v", CardMath.double(target.value)), series: .value("s", "target"))
                        .foregroundStyle(t.quiet).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
                ForEach(references, id: \.id) { point in
                    LineMark(x: .value("x", point.x), y: .value("v", point.y), series: .value("s", "ref\(point.series)"))
                        .foregroundStyle(t.quiet.opacity(point.series == 0 ? 0.6 : 0.35)).lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.monotone)
                }
                if block.area == true {
                    ForEach(Array(first.points.enumerated()), id: \.offset) { _, point in
                        AreaMark(x: .value("x", point.x), yStart: .value("b", bottom), yEnd: .value("v", CardMath.double(point.value)))
                            .foregroundStyle(LinearGradient(colors: [t.slot(1).opacity(0.28), t.slot(1).opacity(0.02)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                    }
                }
                if let smoothed {
                    ForEach(Array(first.points.enumerated()), id: \.offset) { _, point in
                        PointMark(x: .value("x", point.x), y: .value("v", CardMath.double(point.value))).foregroundStyle(t.slot(1).opacity(0.35)).symbolSize(16)
                    }
                    ForEach(Array(zip(first.points, smoothed).enumerated()), id: \.offset) { _, pair in
                        LineMark(x: .value("x", pair.0.x), y: .value("v", pair.1), series: .value("s", "main"))
                            .foregroundStyle(t.slot(1)).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round)).interpolationMethod(.monotone)
                    }
                } else {
                    ForEach(Array(first.points.enumerated()), id: \.offset) { _, point in
                        LineMark(x: .value("x", point.x), y: .value("v", CardMath.double(point.value)), series: .value("s", "main"))
                            .foregroundStyle(t.slot(1)).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round)).interpolationMethod(.monotone)
                    }
                }
                PointMark(x: .value("x", last.x), y: .value("v", smoothed?.last ?? CardMath.double(last.value)))
                    .foregroundStyle(t.slot(1)).symbolSize(70)
                PointMark(x: .value("x", last.x), y: .value("v", smoothed?.last ?? CardMath.double(last.value)))
                    .foregroundStyle(t.card).symbolSize(18)
            }
            .chartXScale(domain: xStart...max(xEnd, xStart + 1), range: .plotDimension(endPadding: 8))
            .chartYScale(domain: bottom...max(top, bottom + 1))
            .chartXAxis {
                // Labels given: exactly those, at their x. Otherwise Charts picks about five.
                if let labels = block.xLabels, !labels.isEmpty {
                    let xs = labels.keys.compactMap(Double.init).sorted()
                    AxisMarks(values: xs) { value in
                        // The last label hangs left of its point, so the edge of the plot doesn't cut it off.
                        AxisValueLabel(anchor: value.as(Double.self) == xs.last ? .topTrailing : .top) {
                            if let v = value.as(Double.self) {
                                Text(labels[CardMath.plain(Decimal(v))] ?? "").font(Fonts.meta).foregroundStyle(t.quiet).fixedSize()
                            }
                        }
                    }
                } else {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v.formatted(.number.precision(.fractionLength(0...1)))).font(Fonts.meta).foregroundStyle(t.quiet)
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                quietYAxis(ticks: running ? CardMath.ticks(top: top) : [], label: label, t: t)
                if !running { AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { v in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(t.divider)
                    AxisValueLabel { if let n = v.as(Double.self) { Text(label(n)).font(Fonts.meta).foregroundStyle(t.quiet) } }
                } }
            }
            .frame(height: 170)
            if block.series.count > 1 || block.target != nil || block.smooth != nil {
                Flow(spacing: 14) {
                    LegendKey(color: t.slot(1), text: block.smooth.map { "\(first.name), \($0)-point average" } ?? first.name, width: 2.5)
                    ForEach(Array(block.series.dropFirst().enumerated()), id: \.offset) { s, series in
                        LegendKey(color: t.quiet.opacity(s == 0 ? 0.6 : 0.35), text: series.name)
                    }
                    if let target = block.target { LegendKey(color: t.quiet, text: target.label ?? "Target pace", width: 1.5, dashed: true) }
                }
            }
            if let projection = CardMath.projectionText(block, locale: locale) {
                Text(projection).font(Fonts.meta).foregroundStyle(t.quiet).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - range

struct RangeBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: RangeBlock

    /// Weather's scale: cold blue through green and yellow to hot red, positioned on the block's own scale.
    var temperature: [Color] { [hex(0x32ADE6), hex(0x34C759), hex(0xFFCC00), hex(0xFF9500), hex(0xFF3B30)] }

    var body: some View {
        let scale = CardMath.scale(block)
        Panel {
            BlockLabel(text: block.label)
            ForEach(Array(block.rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider().overlay(t.divider) }
                HStack(spacing: 10) {
                    Text(row.label).font(Fonts.row).foregroundStyle(t.ink).frame(width: 46, alignment: .leading).lineLimit(1)
                    if let symbol = row.symbol { Image(systemName: symbol).symbolRenderingMode(.multicolor).font(.system(size: 16)).frame(width: 24) }
                    Text(CardMath.text(row.low, unit: block.unit, whole: true, locale: locale)).font(Fonts.body.monospacedDigit()).foregroundStyle(t.quiet)
                        .frame(width: 40, alignment: .trailing)
                    GeometryReader { g in
                        let a = CardMath.position(CardMath.double(row.low), in: scale), b = CardMath.position(CardMath.double(row.high), in: scale)
                        ZStack(alignment: .leading) {
                            Capsule().fill(t.track)
                            Group {
                                if block.style == "temperature" {
                                    LinearGradient(colors: temperature, startPoint: .leading, endPoint: .trailing).frame(width: g.size.width)
                                        .mask(Capsule().frame(width: max(5, g.size.width * (b - a))).offset(x: g.size.width * a).frame(width: g.size.width, alignment: .leading))
                                } else {
                                    Capsule().fill(t.slot(1)).frame(width: max(5, g.size.width * (b - a))).offset(x: g.size.width * a)
                                }
                            }
                            if index == 0, let now = block.now {
                                Circle().fill(t.card).frame(width: 7, height: 7).overlay(Circle().stroke(t.ink.opacity(0.6), lineWidth: 1.5))
                                    .offset(x: g.size.width * CardMath.position(CardMath.double(now), in: scale) - 3.5)
                            }
                        }
                    }.frame(height: 5)
                    Text(CardMath.text(row.high, unit: block.unit, whole: true, locale: locale)).font(Fonts.body.weight(.medium).monospacedDigit()).foregroundStyle(t.ink)
                        .frame(width: 40, alignment: .trailing)
                }
                if let detail = row.detail { Text(detail).font(Fonts.meta).foregroundStyle(t.quiet).padding(.leading, 56) }
            }
        }
    }
}

// MARK: - rings

struct RingsBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: RingsBlock

    var body: some View {
        let slots = CardMath.slots(block.rings.map(\.slot))
        if block.style == "concentric" {
            HStack(spacing: 20) {
                ZStack {
                    ForEach(Array(block.rings.enumerated()), id: \.offset) { index, ring in
                        let size = 120 - CGFloat(index) * 30
                        arc(ring, color: t.slot(slots[index]), line: 12).frame(width: size, height: size)
                    }
                }.frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(block.rings.enumerated()), id: \.offset) { index, ring in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ring.label).font(Fonts.meta.weight(.semibold)).foregroundStyle(t.slot(slots[index]))
                            Text("\(CardMath.text(ring.value, whole: true, locale: locale))/\(CardMath.text(ring.of, unit: ring.unit, whole: true, locale: locale))")
                                .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(t.ink).monospacedDigit()
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(Array(block.rings.enumerated()), id: \.offset) { index, ring in
                    VStack(spacing: 6) {
                        ZStack {
                            arc(ring, color: t.slot(slots[index]), line: 7)
                            VStack(spacing: 0) {
                                Text(CardMath.text(ring.value, whole: true, locale: locale)).font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(t.ink).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                                Text("of \(CardMath.text(ring.of, unit: ring.unit, whole: true, locale: locale))").font(.system(size: 10)).foregroundStyle(t.quiet).lineLimit(1)
                            }.padding(.horizontal, 10)
                        }.frame(width: 76, height: 76)
                        Text(ring.label).font(Fonts.meta.weight(.medium)).foregroundStyle(t.quiet).lineLimit(1)
                    }.frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// Activity's ring: a dim track of the same colour and the progress over it; past one lap, it keeps going.
    func arc(_ ring: Ring, color: Color, line: CGFloat) -> some View {
        let progress = CardMath.double(ring.of) > 0 ? CardMath.double(ring.value) / CardMath.double(ring.of) : 0
        return ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: line)
            Circle().trim(from: 0, to: min(1, progress)).stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round)).rotationEffect(.degrees(-90))
            if progress > 1 {
                Circle().trim(from: 0, to: min(1, progress - 1)).stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90)).shadow(color: .black.opacity(0.25), radius: 2)
            }
        }
    }
}

// MARK: - gauges

struct GaugesBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: GaugesBlock

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(block.gauges.enumerated()), id: \.offset) { _, gauge in
                let color = gauge.status.map { $0 == .neutral ? t.slot(1) : t.look($0).mark } ?? t.slot(1)
                let fraction = CardMath.fill(gauge.value, of: gauge.of)
                VStack(spacing: 6) {
                    ZStack {
                        // A 270° dial, open at the bottom, like Apple's circular gauges.
                        Circle().trim(from: 0, to: 0.75).stroke(t.track, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(135))
                        Circle().trim(from: 0, to: 0.75 * fraction).stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(135))
                        VStack(spacing: 0) {
                            if let symbol = gauge.symbol { Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(t.quiet) }
                            // A short unit (%, °) stays with the number; a longer one (Mb/s) goes underneath.
                            let short = (gauge.unit ?? "").count <= 1
                            Text(CardMath.text(gauge.value, unit: short ? gauge.unit : nil, whole: true, locale: locale)).font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(t.ink).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                            if !short, let unit = gauge.unit { Text(unit).font(.system(size: 10, weight: .medium)).foregroundStyle(t.quiet) }
                        }.padding(.horizontal, 12)
                    }.frame(width: 76, height: 76)
                    Text(gauge.label).font(Fonts.meta.weight(.medium)).foregroundStyle(t.ink).lineLimit(1)
                    if let detail = gauge.detail { Text(detail).font(Fonts.meta).foregroundStyle(gauge.status.map { t.look($0).ink } ?? t.quiet).lineLimit(1) }
                }.frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - timeline

struct TimelineBlockView: View {
    @Environment(\.cardTheme) var t
    var block: TimelineBlock

    var body: some View {
        if block.layout == "vertical" { VerticalTimeline(block: block) } else { horizontal }
    }

    @ViewBuilder var horizontal: some View {
        let lanes = CardMath.lanes(block)
        let laneCount = (lanes.max() ?? 0) + 1
        let ticks = CardMath.timeTicks(start: block.start, end: block.end, scale: block.scale)
        let span = block.end - block.start
        let legendSlots = CardMath.slots((block.legend ?? []).map(\.slot))
        VStack(alignment: .leading, spacing: 8) {
            BlockLabel(text: block.label)
            GeometryReader { g in
                let x = { (v: Double) in CGFloat((v - block.start) / span) * g.size.width }
                ZStack(alignment: .topLeading) {
                    ForEach(Array(ticks.enumerated()), id: \.offset) { _, tick in
                        Rectangle().fill(t.divider).frame(width: 0.5, height: CGFloat(laneCount) * 30).offset(x: x(tick))
                    }
                    ForEach(Array(block.items.enumerated()), id: \.offset) { index, item in
                        let color = item.status.map { t.look($0).mark } ?? t.slot(item.slot ?? 1)
                        let y = CGFloat(lanes[index]) * 30
                        if let to = item.to {
                            let width = max(4, x(to) - x(item.from))
                            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.opacity(0.9))
                                .frame(width: width, height: 24)
                                .overlay(alignment: .leading) {
                                    if let title = item.title, width > 44 {
                                        Text(title).font(Fonts.meta.weight(.semibold)).foregroundStyle(.white).lineLimit(1).padding(.horizontal, 6)
                                    }
                                }
                                .offset(x: x(item.from), y: y)
                        } else {
                            HStack(spacing: 4) {
                                Circle().fill(color).frame(width: 10, height: 10).overlay(Circle().stroke(t.card, lineWidth: 2))
                                if let title = item.title { Text(title).font(Fonts.meta.weight(.medium)).foregroundStyle(t.ink).lineLimit(1).fixedSize() }
                            }
                            .offset(x: x(item.from) - 5, y: y + 7)
                        }
                    }
                }
            }.frame(height: CGFloat(laneCount) * 30)
            GeometryReader { g in
                ForEach(Array(ticks.enumerated()), id: \.offset) { _, tick in
                    Text(CardMath.timeText(tick, scale: block.scale)).font(Fonts.meta.monospacedDigit()).foregroundStyle(t.quiet).fixedSize()
                        .offset(x: min(g.size.width - 34, max(0, CGFloat((tick - block.start) / span) * g.size.width - 14)))
                }
            }.frame(height: 14)
            if let legend = block.legend {
                Flow(spacing: 12) {
                    ForEach(Array(legend.enumerated()), id: \.offset) { i, tag in LegendKey(color: t.slot(legendSlots[i]), text: tag.name, square: true) }
                }
            }
        }
    }
}

/// A day's agenda, Calendar-style: time runs down, events are tinted blocks with a coloured edge, overlapping
/// ones side by side, moments as a dot on a line.
struct VerticalTimeline: View {
    @Environment(\.cardTheme) var t
    var block: TimelineBlock

    var body: some View {
        let lanes = CardMath.lanes(block.items)
        let laneCount = CGFloat((lanes.max() ?? 0) + 1)
        let span = block.end - block.start
        let perUnit = max(26, min(44, 380 / CGFloat(span)))
        let height = CGFloat(span) * perUnit
        let ticks = CardMath.timeTicks(start: block.start, end: block.end, scale: block.scale)
        let gutter: CGFloat = 44
        VStack(alignment: .leading, spacing: 8) {
            BlockLabel(text: block.label)
            GeometryReader { g in
                let width = g.size.width - gutter
                let y = { (v: Double) in CGFloat(v - block.start) * perUnit }
                ZStack(alignment: .topLeading) {
                    ForEach(Array(ticks.enumerated()), id: \.offset) { _, tick in
                        Text(CardMath.timeText(tick, scale: block.scale)).font(Fonts.meta.monospacedDigit()).foregroundStyle(t.quiet)
                            .frame(width: gutter - 8, alignment: .trailing).offset(y: y(tick) - 7)
                        Rectangle().fill(t.divider).frame(width: width, height: 0.5).offset(x: gutter, y: y(tick))
                    }
                    ForEach(Array(block.items.enumerated()), id: \.offset) { index, item in
                        let color = item.status.map { t.look($0).mark } ?? t.slot(item.slot ?? 1)
                        if let to = item.to {
                            let lane = CGFloat(lanes[index]), w = width / laneCount
                            HStack(spacing: 0) {
                                Rectangle().fill(color).frame(width: 3)
                                VStack(alignment: .leading, spacing: 1) {
                                    if let title = item.title { Text(title).font(Fonts.meta.weight(.semibold)).foregroundStyle(t.ink).lineLimit(1) }
                                    if y(to) - y(item.from) > 30 {
                                        Text("\(CardMath.timeText(item.from, scale: block.scale))–\(CardMath.timeText(to, scale: block.scale))")
                                            .font(.system(size: 10)).foregroundStyle(t.quiet).lineLimit(1)
                                    }
                                }.padding(.horizontal, 6).padding(.vertical, 3)
                                Spacer(minLength: 0)
                            }
                            .frame(width: w - 3, height: max(16, y(to) - y(item.from) - 2), alignment: .topLeading)
                            .background(color.opacity(t.dark ? 0.30 : 0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .offset(x: gutter + lane * w, y: y(item.from) + 1)
                        } else {
                            HStack(spacing: 5) {
                                Circle().fill(color).frame(width: 8, height: 8)
                                Rectangle().fill(color).frame(width: 30, height: 1.5)
                                if let title = item.title { Text(title).font(Fonts.meta.weight(.semibold)).foregroundStyle(color == t.slot(1) ? t.ink : color).lineLimit(1) }
                            }.offset(x: gutter - 4, y: y(item.from) - 4)
                        }
                    }
                }
            }.frame(height: height + 4)
        }
    }
}

// MARK: - heatmap

struct HeatmapBlockView: View {
    @Environment(\.cardTheme) var t
    var block: HeatmapBlock

    var body: some View {
        let cells = CardMath.grid(start: block.start, count: block.values.count) ?? []
        let levels = CardMath.levels(block.values)
        let weeks = (cells.map(\.column).max() ?? 0) + 1
        let gap: CGFloat = 3
        let size = min(16, (Metric.inner - 22 - CGFloat(weeks - 1) * gap) / CGFloat(weeks))
        VStack(alignment: .leading, spacing: 8) {
            BlockLabel(text: block.label)
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .trailing, spacing: gap) {
                    ForEach(0..<7, id: \.self) { row in
                        Text(["M", "", "W", "", "F", "", ""][row]).font(.system(size: 9)).foregroundStyle(t.quiet).frame(height: size)
                    }
                }.frame(width: 12)
                ZStack(alignment: .topLeading) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                            .fill(block.values[index] == nil ? t.track.opacity(0.5) : t.ramp[levels[index]])
                            .frame(width: size, height: size)
                            .offset(x: CGFloat(cell.column) * (size + gap), y: CGFloat(cell.row) * (size + gap))
                    }
                }.frame(width: CGFloat(weeks) * (size + gap), height: 7 * (size + gap), alignment: .topLeading)
            }
            HStack(spacing: 4) {
                Spacer()
                Text(block.low ?? "Less").font(Fonts.meta).foregroundStyle(t.quiet)
                ForEach(0..<5, id: \.self) { RoundedRectangle(cornerRadius: 2).fill(t.ramp[$0]).frame(width: 10, height: 10) }
                Text(block.high ?? "More").font(Fonts.meta).foregroundStyle(t.quiet)
            }
        }
    }
}

// MARK: - sparklines

struct SparklinesBlockView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var block: SparklinesBlock

    var body: some View {
        Panel {
            BlockLabel(text: block.label)
            ForEach(Array(block.rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider().overlay(t.divider) }
                let rising = (row.change ?? ((row.points.last ?? 0) - (row.points.first ?? 0))) >= 0
                let good = rising != (row.inverted == true)
                let color = good ? t.good : t.critical
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.title).font(Fonts.row.weight(.semibold)).foregroundStyle(t.ink).lineLimit(1)
                        if let detail = row.detail { Text(detail).font(Fonts.meta).foregroundStyle(t.quiet).lineLimit(1) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Sparkline(points: row.points, color: color).frame(width: 70, height: 28)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(CardMath.text(row.value, locale: locale)).font(Fonts.row.monospacedDigit()).foregroundStyle(t.ink)
                        if let change = row.change {
                            Text(CardMath.percentChange(change, locale: locale)).font(Fonts.meta.weight(.semibold).monospacedDigit()).foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(good ? t.goodInk : t.criticalInk))
                        }
                    }.frame(width: 84, alignment: .trailing)
                }
            }
        }
    }
}

/// A tiny line, scaled to its own box, with a faint baseline at its first value (Stocks-style).
struct Sparkline: View {
    var points: [Double]; var color: Color
    var body: some View {
        GeometryReader { g in
            let low = points.min() ?? 0, high = points.max() ?? 1, range = max(high - low, 0.000_001)
            let y = { (v: Double) in g.size.height * (1 - CGFloat((v - low) / range)) }
            let step = g.size.width / CGFloat(max(1, points.count - 1))
            ZStack {
                Path { p in p.move(to: CGPoint(x: 0, y: y(points[0]))); p.addLine(to: CGPoint(x: g.size.width, y: y(points[0]))) }
                    .stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                Path { p in
                    for (i, v) in points.enumerated() {
                        let point = CGPoint(x: CGFloat(i) * step, y: y(v))
                        if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
                    }
                }.stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
