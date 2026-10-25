//
//  Parts.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  The building blocks every card is made of, in one order:
//  Eyebrow → Hero (+ status) → one visual → panel → footnote.
//  Layout only: every number and word comes from CardMath or the input.
//

import SwiftUI

private struct ThemeKey: EnvironmentKey { static let defaultValue = Theme.light }
private struct LocaleKey: EnvironmentKey { static let defaultValue = Locale.current }
private struct WordsKey: EnvironmentKey { static let defaultValue = Words() }
private struct OpaqueKey: EnvironmentKey { static let defaultValue = false }
private struct MapsKey: EnvironmentKey { nonisolated(unsafe) static let defaultValue: [Int: CGImage] = [:] }

extension EnvironmentValues {
    var cardTheme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
    /// The kit's own phrases, as the card words them.
    var cardWords: Words {
        get { self[WordsKey.self] }
        set { self[WordsKey.self] = newValue }
    }
    /// Draw the page around the card (grey / black) instead of leaving it transparent.
    var cardOpaque: Bool {
        get { self[OpaqueKey.self] }
        set { self[OpaqueKey.self] = newValue }
    }
    /// Map snapshots prepared before drawing, by block index.
    var cardMaps: [Int: CGImage] {
        get { self[MapsKey.self] }
        set { self[MapsKey.self] = newValue }
    }
    /// The reader's locale for numbers and money ("2,209" in Britain, "2.209" in Germany).
    var cardLocale: Locale {
        get { self[LocaleKey.self] }
        set { self[LocaleKey.self] = newValue }
    }
}

/// The card: 390 pt with a 14 pt margin around it, 20 pt inside, sections 16 pt apart.
struct CardShell<Content: View>: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardOpaque) var opaque
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: Metric.gap) { content }
            .padding(Metric.pad).frame(width: Metric.width, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous).fill(t.card)
                .shadow(color: .black.opacity(t.dark ? 0 : 0.06), radius: 12, y: 4))
            // The margin leaves room for the shadow; it is transparent, so in a chat the card sits on the
            // conversation's own background, unless an opaque page is asked for (docs, galleries).
            .padding(Metric.margin).background(opaque ? t.page : Color.clear)
    }
}

/// What and when: "Spent · 12:42".
struct Eyebrow: View {
    @Environment(\.cardTheme) var t
    var text: String
    var body: some View { Text(text).font(Fonts.eyebrow).foregroundStyle(t.quiet) }
}

/// The one number that answers the card's question, with its unit or qualifier.
struct HeroNumber: View {
    @Environment(\.cardTheme) var t
    var value: String; var unit: String? = nil
    var body: some View {
        // The unit sits beside the value when it fits, and drops to its own line when it doesn't — never cut short.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 5) { number; unitText.fixedSize() }
            VStack(alignment: .leading, spacing: 2) { number; unitText.fixedSize(horizontal: false, vertical: true) }
        }
    }

    var number: some View {
        // A figure is drawn big; words ("Dr Patel's surgery") a size down, as a title.
        Text(value).font(value.count > 10 ? Fonts.heroWords : Fonts.hero).foregroundStyle(t.ink).monospacedDigit()
            .minimumScaleFactor(0.5).lineLimit(value.count > 10 ? 2 : 1)
    }

    @ViewBuilder var unitText: some View {
        if let unit, !unit.isEmpty { Text(unit).font(Fonts.heroUnit).foregroundStyle(t.quiet) }
    }
}

extension Theme {
    /// A status's icon and the colour of its words.
    func look(_ status: Status) -> (icon: String?, ink: Color, mark: Color) {
        switch status {
        case .good: ("checkmark.circle.fill", goodInk, good)
        case .over: ("arrow.up.circle.fill", overInk, over)
        case .critical: ("exclamationmark.triangle.fill", criticalInk, critical)
        case .neutral: (nil, quiet, quiet)
        }
    }
}

/// Where things stand, in words, with the status's icon: never colour alone.
struct StatusLine: View {
    @Environment(\.cardTheme) var t
    var status: StatusText
    var body: some View {
        let look = t.look(status.status)
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let icon = look.icon { Image(systemName: icon).font(.system(size: 13)) }
            Text(status.text).font(.system(size: 14, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
        }.foregroundStyle(look.ink)
    }
}

/// A grouped block on the panel colour.
struct Panel<Content: View>: View {
    @Environment(\.cardTheme) var t
    var padding: CGFloat = 14
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metric.panelRadius, style: .continuous).fill(t.panel))
    }
}

/// A small capitals label over a group: "TODAY".
struct SectionLabel: View {
    @Environment(\.cardTheme) var t
    var text: String
    var body: some View { Text(text.uppercased()).font(Fonts.section).tracking(0.6).foregroundStyle(t.quiet) }
}

/// 45° stripes in a colour on a tint of it: the texture for "past the limit".
struct Stripes: View {
    var color: Color
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color.opacity(0.28)))
            var path = Path(), x = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height)); path.addLine(to: CGPoint(x: x + size.height, y: 0)); x += 5
            }
            context.stroke(path, with: .color(color), lineWidth: 2)
        }
    }
}

/// Progress against a limit. Past it, the bar is full and the excess is the same colour striped, 2 pt apart:
/// the part keeps its colour, and "over" is texture + icon + words, never a second colour.
struct LimitBar: View {
    @Environment(\.cardTheme) var t
    var value: Amount; var of: Amount; var color: Color
    var body: some View {
        GeometryReader { g in
            if CardMath.isOver(value, of: of) {
                HStack(spacing: 2) {
                    Capsule().fill(color)
                    Stripes(color: color).clipShape(Capsule()).frame(width: g.size.width * CardMath.overShare(value, of: of))
                }
            } else {
                ZStack(alignment: .leading) {
                    Capsule().fill(t.track)
                    Capsule().fill(color).frame(width: g.size.width * CardMath.fill(value, of: of))
                }
            }
        }.frame(height: Metric.bar)
    }
}

/// A part's colour next to its name; the name itself stays ink.
struct Dot: View {
    var color: Color; var size: CGFloat = 9
    var body: some View { Circle().fill(color).frame(width: size, height: size) }
}

/// One part against its limit: name, amount "of" limit, the bar, and how far over.
struct LimitRowView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    @Environment(\.cardWords) var words
    var row: LimitRow; var slot: Int; var unit: String?
    var body: some View {
        let color = t.slot(slot)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Dot(color: color)
                Text(row.name).font(Fonts.row).foregroundStyle(t.ink).lineLimit(1)
                Spacer(minLength: 6)
                Text(CardMath.text(row.value, unit: unit, whole: true, locale: locale)).font(Fonts.row).foregroundStyle(t.ink).monospacedDigit().fixedSize()
                Text(words("of", ["total": CardMath.text(row.of, whole: true, locale: locale)])).font(Fonts.meta).foregroundStyle(t.quiet).monospacedDigit().fixedSize()
            }
            LimitBar(value: row.value, of: row.of, color: color)
            if CardMath.isOver(row.value, of: row.of) {
                let excess = CardMath.text(CardMath.minus(row.value, row.of), unit: unit, whole: true, locale: locale)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text(words("row_over", ["amount": excess]))
                }.font(Fonts.meta.weight(.semibold)).foregroundStyle(t.overInk)
            }
        }
    }
}

/// A plain row: a time or icon, title and detail, a value at the end. A checklist row (`done`) draws Reminders'
/// circle: open, or filled with the title dimmed.
struct RowView: View {
    @Environment(\.cardTheme) var t
    @Environment(\.cardLocale) var locale
    var row: Row
    var body: some View {
        let look = row.status.map(t.look)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let lead = row.lead { Text(lead).font(Fonts.meta.monospacedDigit()).foregroundStyle(t.quiet).frame(width: 40, alignment: .leading) }
            if let done = row.done {
                Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.system(size: 15))
                    .foregroundStyle(done ? t.slot(1) : t.quiet).frame(width: 18)
            } else if let symbol = row.symbol ?? look?.icon {
                Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(look?.mark ?? t.quiet).frame(width: 18)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title).font(Fonts.row).foregroundStyle(row.done == true ? t.quiet : t.ink).lineLimit(1)
                if let detail = row.detail {
                    Text(detail).font(Fonts.meta).foregroundStyle(row.status == .critical ? t.criticalInk : t.quiet).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            if let value = row.value {
                Text(CardMath.text(value, locale: locale)).font(Fonts.body.monospacedDigit()).foregroundStyle(t.ink).fixedSize()
            }
        }
    }
}

/// Lines of views that wrap to the width given (chips).
struct Flow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Line { var items: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Line] {
        var lines = [Line()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !lines[lines.count - 1].items.isEmpty, lines[lines.count - 1].width + spacing + size.width > width {
                let last = lines[lines.count - 1]
                lines.append(Line(y: last.y + last.height + spacing))
            }
            lines[lines.count - 1].width += (lines[lines.count - 1].items.isEmpty ? 0 : spacing) + size.width
            lines[lines.count - 1].height = max(lines[lines.count - 1].height, size.height)
            lines[lines.count - 1].items.append(index)
        }
        return lines
    }
}

/// A rounded label with its colour dot: a category.
struct TagChip: View {
    @Environment(\.cardTheme) var t
    var text: String; var color: Color?
    var body: some View {
        HStack(spacing: 5) {
            if let color { Dot(color: color, size: 7) }
            Text(text).font(Fonts.meta.weight(.medium)).foregroundStyle(t.ink)
        }.padding(.horizontal, 9).padding(.vertical, 4).background(Capsule().fill(t.panel)).fixedSize()
    }
}

/// The quiet line at the bottom: where the numbers came from, what to do next.
struct Footnote: View {
    @Environment(\.cardTheme) var t
    var text: String
    var body: some View { Text(text).font(Fonts.footnote).foregroundStyle(t.quiet).fixedSize(horizontal: false, vertical: true) }
}

extension View {
    /// A multicolour SF Symbol on a light card: Apple draws weather clouds and moons white, which vanish on white,
    /// so they get a soft shadow for an edge (as Apple's light widgets do). Dark cards need nothing.
    func lifted(_ theme: Theme) -> some View {
        shadow(color: .black.opacity(theme.dark ? 0 : 0.28), radius: 1.2, y: 0.6)
    }
}
