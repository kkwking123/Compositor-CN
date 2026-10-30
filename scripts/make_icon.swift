#!/usr/bin/swift
// Draws this fork's app icon: the upstream artwork with a "CN" badge added, so the two editions are
// distinguishable in the Dock and on the Desktop at a glance.
//
// The badge sits bottom-left on purpose. Upstream's folded corner (bottom-right) is the icon's whole idea —
// a page peeling back to a transparent canvas — and covering it would make the fork's icon the worse one.
// Bottom-left is the flat orange field, where a deep indigo badge has both the contrast and the room.
//
// Only scripts/icon/base-1024.png is hand-made; every size the asset catalog wants is derived from the
// 1024 render here, so the set can never drift out of step with itself.
//
//   swift scripts/make_icon.swift                       # rewrite the asset catalog
//   swift scripts/make_icon.swift --preview /tmp/x.png  # 1024 render only, changes nothing
import AppKit
import Foundation

let catalogURL = URL(fileURLWithPath: "Compositor/Assets.xcassets/AppIcon.appiconset")
let baseURL = URL(fileURLWithPath: "scripts/icon/base-1024.png")
let badgeText = "CN"
// name → pixel edge. 16/32/64/128/256/512/1024 covers every slot in Contents.json.
let sizes: [(String, Int)] = [("16", 16), ("32", 32), ("64", 64), ("128", 128),
                              ("256", 256), ("512", 512), ("1024", 1024)]

var previewPath: String?
if let i = CommandLine.arguments.firstIndex(of: "--preview"), i + 1 < CommandLine.arguments.count {
    previewPath = CommandLine.arguments[i + 1]
}

guard let base = NSImage(contentsOf: baseURL) else {
    FileHandle.standardError.write("missing \(baseURL.path)\n".data(using: .utf8)!)
    exit(1)
}
let side = 1024

// Everything below is expressed in 1024 units and scaled by `s` for the requested size, so one set of
// numbers describes the design at every resolution.
func render(_ edge: Int) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: edge, pixelsHigh: edge,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    let s = CGFloat(edge) / CGFloat(side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    base.draw(in: NSRect(x: 0, y: 0, width: edge, height: edge),
              from: NSRect(x: 0, y: 0, width: base.size.width, height: base.size.height),
              operation: .copy, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])

    // Badge geometry, in 1024 units. The artwork's rounded square does not reach the canvas edge — it
    // starts around 100 — so the badge is measured from that inset, otherwise it hangs off the icon.
    let inset: CGFloat = 100
    let margin: CGFloat = 46          // from the artwork's own edge
    let w: CGFloat = 262, h: CGFloat = 128
    let rect = NSRect(x: (inset + margin) * s, y: (inset + margin) * s, width: w * s, height: h * s)
    let radius = (h / 2 * 0.44) * s

    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    // The shadow is set on the CGContext rather than through NSShadow, because the same context has to
    // switch it off again before the hairline and the glyphs draw — those must stay crisp.
    let cg = ctx.cgContext
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -6 * s), blur: 20 * s,
                 color: NSColor(srgbRed: 0.05, green: 0.04, blue: 0.2, alpha: 0.55).cgColor)
    // Indigo, taken from the icon's own top edge, so the badge reads as part of the artwork.
    NSGradient(starting: NSColor(srgbRed: 0.30, green: 0.26, blue: 0.72, alpha: 1),
               ending: NSColor(srgbRed: 0.10, green: 0.11, blue: 0.44, alpha: 1))?
        .draw(in: path, angle: -90)
    cg.restoreGState()

    NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.92).setStroke()
    path.lineWidth = 6 * s
    path.stroke()

    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let kern: CGFloat = 5 * s
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 86 * s, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: style,
        .kern: kern, // the default pair spacing makes "CN" look cramped at display size
    ]
    let text = NSAttributedString(string: badgeText, attributes: attrs)
    let textSize = text.size()
    // Kern is applied after the last glyph too, so centring on textSize shifts the letters half a kern left.
    text.draw(in: NSRect(x: rect.minX + kern / 2,
                         y: rect.midY - textSize.height / 2,
                         width: rect.width - kern, height: textSize.height))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

if let previewPath {
    guard let data = render(side) else { exit(1) }
    try! data.write(to: URL(fileURLWithPath: previewPath))
    print("preview → \(previewPath)")
    exit(0)
}

for (name, edge) in sizes {
    guard let data = render(edge) else {
        FileHandle.standardError.write("failed to render \(edge)px\n".data(using: .utf8)!)
        exit(1)
    }
    let url = catalogURL.appendingPathComponent("app-icon-\(name).png")
    try! data.write(to: url)
    print("wrote \(url.lastPathComponent) (\(edge)px)")
}
