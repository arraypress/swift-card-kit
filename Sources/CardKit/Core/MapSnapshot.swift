//
//  MapSnapshot.swift
//  CardKit
//
//  Created by David Sherlock on 2026.
//
//  A map block as a picture: an Apple Maps snapshot (MKMapSnapshotter works
//  from a command line tool — measured 2026-10-26, about 3 s with the
//  network), points of interest off so the pins read, the route and pins
//  drawn on top in the card's colours.
//

import AppKit
@preconcurrency import MapKit
import SwiftUI

enum MapSnapshot {

    static func image(_ block: MapBlock, theme: CardTheme, scale: CGFloat) async -> CGImage? {
        let region = CardMath.mapRegion(block)
        let size = NSSize(width: Metric.inner, height: CGFloat(block.height ?? 200))
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: region.lat, longitude: region.lon),
                                            span: MKCoordinateSpan(latitudeDelta: region.latSpan, longitudeDelta: region.lonSpan))
        options.size = size
        options.appearance = NSAppearance(named: theme == .dark ? .darkAqua : .aqua)
        options.pointOfInterestFilter = .excludingAll
        let snapshotter = MKMapSnapshotter(options: options)
        let palette = Theme.of(theme)
        // The snapshot is drawn on inside the handler, so only a finished CGImage leaves it; offline, MapKit can
        // wait a long time, so a timeout cancels it. Whichever comes first answers, once.
        return await withCheckedContinuation { (continuation: CheckedContinuation<CGImage?, Never>) in
            let once = Once()
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                if once.claim() { snapshotter.cancel(); continuation.resume(returning: nil) }
            }
            snapshotter.start(with: .main) { snapshot, _ in
                guard once.claim() else { return }
                continuation.resume(returning: snapshot.flatMap { draw($0, block: block, theme: palette, size: size, scale: scale) })
            }
        }
    }

    /// True the first time only.
    final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func claim() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
    }

    /// The snapshot redrawn at `scale` with the route (a 4 pt line in the first slot's colour, white edge) and the
    /// pins (a dot in the pin's colour, white ring, its title beside it on a white label).
    static func draw(_ snapshot: MKMapSnapshotter.Snapshot, block: MapBlock, theme: Theme, size: NSSize, scale: CGFloat) -> CGImage? {
        let width = Int(size.width * scale), height = Int(size.height * scale)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let base = snapshot.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        context.interpolationQuality = .high
        context.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))
        // Snapshot points are top-left in points; the context is bottom-left in pixels.
        func pixel(_ lat: Double, _ lon: Double) -> CGPoint {
            let p = snapshot.point(for: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            return CGPoint(x: p.x * scale, y: (size.height - p.y) * scale)
        }
        if let route = block.route, route.count > 1 {
            let path = CGMutablePath()
            path.addLines(between: route.map { pixel($0.lat, $0.lon) })
            context.setLineCap(.round); context.setLineJoin(.round)
            context.addPath(path); context.setStrokeColor(NSColor.white.cgColor); context.setLineWidth(7 * scale); context.strokePath()
            context.addPath(path); context.setStrokeColor(NSColor(theme.slot(1)).cgColor); context.setLineWidth(4 * scale); context.strokePath()
        }
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
        for pin in block.pins {
            let at = pixel(pin.lat, pin.lon), radius = 7 * scale
            let color = NSColor(pin.status.map { theme.look($0).mark } ?? theme.slot(pin.slot ?? 1))
            NSColor.white.setFill(); NSBezierPath(ovalIn: CGRect(x: at.x - radius - 2.5 * scale, y: at.y - radius - 2.5 * scale,
                                                                width: 2 * radius + 5 * scale, height: 2 * radius + 5 * scale)).fill()
            color.setFill(); NSBezierPath(ovalIn: CGRect(x: at.x - radius, y: at.y - radius, width: 2 * radius, height: 2 * radius)).fill()
            if let title = pin.title, !title.isEmpty {
                let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12 * scale, weight: .semibold),
                                                                 .foregroundColor: NSColor(hex: 0x1D1D1F)]
                let text = NSAttributedString(string: title, attributes: attributes), box = text.size()
                let label = CGRect(x: at.x + radius + 5 * scale, y: at.y - box.height / 2 - 2 * scale, width: box.width + 10 * scale, height: box.height + 4 * scale)
                NSColor.white.withAlphaComponent(0.92).setFill()
                NSBezierPath(roundedRect: label, xRadius: 5 * scale, yRadius: 5 * scale).fill()
                text.draw(at: CGPoint(x: label.minX + 5 * scale, y: label.minY + 2 * scale))
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

}

extension NSColor {
    convenience init(hex: Int) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
