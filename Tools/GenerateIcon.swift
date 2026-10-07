import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func drawIcon(size: Int, filename: String) throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let frame = NSRect(x: 72, y: 72, width: 880, height: 880)
    let shape = NSBezierPath(roundedRect: frame, xRadius: 196, yRadius: 196)
    NSGraphicsContext.saveGraphicsState()
    let tileShadow = NSShadow()
    tileShadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
    tileShadow.shadowBlurRadius = 24
    tileShadow.shadowOffset = NSSize(width: 0, height: -8)
    tileShadow.set()
    NSColor(calibratedRed: 0.06, green: 0.20, blue: 0.29, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    shape.addClip()
    NSGradient(colors: [
        NSColor(calibratedRed: 0.035, green: 0.12, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.31, blue: 0.44, alpha: 1),
        NSColor(calibratedRed: 0.24, green: 0.55, blue: 0.64, alpha: 1)
    ])!.draw(in: shape, angle: 90)

    func glow(at center: CGPoint, radius: CGFloat, color: NSColor) {
        let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        context.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                            endCenter: center, endRadius: radius, options: [])
    }
    glow(at: CGPoint(x: 218, y: 952), radius: 660,
         color: NSColor(calibratedRed: 0.65, green: 0.93, blue: 0.88, alpha: 0.16))
    glow(at: CGPoint(x: 736, y: 738), radius: 216,
         color: NSColor(calibratedRed: 1, green: 0.76, blue: 0.39, alpha: 0.22))

    let sun = NSBezierPath(ovalIn: NSRect(x: 668, y: 670, width: 136, height: 136))
    NSGradient(starting: NSColor(calibratedRed: 1, green: 0.72, blue: 0.36, alpha: 1),
               ending: NSColor(calibratedRed: 1, green: 0.93, blue: 0.70, alpha: 1))!
        .draw(in: sun, angle: 90)
    NSColor.white.withAlphaComponent(0.35).setStroke()
    sun.lineWidth = 1.5
    sun.stroke()

    let coast = NSBezierPath()
    coast.move(to: NSPoint(x: 72, y: 418))
    coast.curve(to: NSPoint(x: 322, y: 578), controlPoint1: NSPoint(x: 174, y: 467), controlPoint2: NSPoint(x: 234, y: 601))
    coast.curve(to: NSPoint(x: 596, y: 450), controlPoint1: NSPoint(x: 443, y: 548), controlPoint2: NSPoint(x: 502, y: 462))
    coast.curve(to: NSPoint(x: 952, y: 506), controlPoint1: NSPoint(x: 759, y: 424), controlPoint2: NSPoint(x: 815, y: 557))
    coast.line(to: NSPoint(x: 952, y: 246))
    coast.line(to: NSPoint(x: 72, y: 246))
    coast.close()
    NSGradient(starting: NSColor(calibratedRed: 0.11, green: 0.32, blue: 0.39, alpha: 1),
               ending: NSColor(calibratedRed: 0.34, green: 0.59, blue: 0.61, alpha: 1))!
        .draw(in: coast, angle: 90)

    let ridge = NSBezierPath()
    ridge.move(to: NSPoint(x: 132, y: 384))
    ridge.line(to: NSPoint(x: 386, y: 700))
    ridge.curve(to: NSPoint(x: 406, y: 702), controlPoint1: NSPoint(x: 393, y: 710), controlPoint2: NSPoint(x: 398, y: 711))
    ridge.line(to: NSPoint(x: 584, y: 465))
    ridge.line(to: NSPoint(x: 712, y: 588))
    ridge.curve(to: NSPoint(x: 733, y: 587), controlPoint1: NSPoint(x: 720, y: 596), controlPoint2: NSPoint(x: 727, y: 595))
    ridge.line(to: NSPoint(x: 912, y: 379))
    ridge.close()
    NSGraphicsContext.saveGraphicsState()
    let ridgeShadow = NSShadow()
    ridgeShadow.shadowColor = NSColor(calibratedRed: 0.01, green: 0.10, blue: 0.16, alpha: 0.24)
    ridgeShadow.shadowBlurRadius = 24
    ridgeShadow.shadowOffset = NSSize(width: 0, height: -12)
    ridgeShadow.set()
    NSColor(calibratedRed: 0.77, green: 0.88, blue: 0.88, alpha: 1).setFill()
    ridge.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(calibratedRed: 0.58, green: 0.76, blue: 0.80, alpha: 1),
               ending: NSColor(calibratedRed: 0.94, green: 0.97, blue: 0.91, alpha: 1))!
        .draw(in: ridge, angle: 90)

    let facet = NSBezierPath()
    facet.move(to: NSPoint(x: 399, y: 705))
    facet.line(to: NSPoint(x: 462, y: 385))
    facet.line(to: NSPoint(x: 644, y: 382))
    facet.close()
    NSGraphicsContext.saveGraphicsState()
    ridge.addClip()
    NSGradient(starting: NSColor(calibratedRed: 0.39, green: 0.63, blue: 0.69, alpha: 0.8),
               ending: NSColor(calibratedRed: 0.63, green: 0.81, blue: 0.82, alpha: 0.65))!
        .draw(in: facet, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    let bay = NSBezierPath()
    bay.move(to: NSPoint(x: 56, y: 380))
    bay.curve(to: NSPoint(x: 968, y: 352), controlPoint1: NSPoint(x: 336, y: 455), controlPoint2: NSPoint(x: 679, y: 227))
    bay.line(to: NSPoint(x: 968, y: 56))
    bay.line(to: NSPoint(x: 56, y: 56))
    bay.close()
    NSGradient(starting: NSColor(calibratedRed: 0.04, green: 0.21, blue: 0.31, alpha: 1),
               ending: NSColor(calibratedRed: 0.12, green: 0.47, blue: 0.53, alpha: 1))!
        .draw(in: bay, angle: 90)

    let shoreline = NSBezierPath()
    shoreline.move(to: NSPoint(x: 93, y: 388))
    shoreline.curve(to: NSPoint(x: 951, y: 348), controlPoint1: NSPoint(x: 364, y: 433), controlPoint2: NSPoint(x: 689, y: 245))
    shoreline.lineWidth = 3
    NSColor(calibratedRed: 0.57, green: 0.88, blue: 0.83, alpha: 0.30).setStroke()
    shoreline.stroke()

    let wave = NSBezierPath()
    wave.move(to: NSPoint(x: 227, y: 277))
    wave.curve(to: NSPoint(x: 798, y: 245), controlPoint1: NSPoint(x: 432, y: 337), controlPoint2: NSPoint(x: 644, y: 190))
    wave.lineWidth = 15
    wave.lineCapStyle = .round
    NSColor(calibratedRed: 0.75, green: 0.94, blue: 0.88, alpha: 0.85).setStroke()
    wave.stroke()

    let reflection = NSBezierPath()
    reflection.move(to: NSPoint(x: 297, y: 213))
    reflection.curve(to: NSPoint(x: 710, y: 179), controlPoint1: NSPoint(x: 438, y: 240), controlPoint2: NSPoint(x: 571, y: 159))
    reflection.lineWidth = 5
    reflection.lineCapStyle = .round
    NSColor(calibratedRed: 0.55, green: 0.83, blue: 0.82, alpha: 0.22).setStroke()
    reflection.stroke()

    let border = NSBezierPath(roundedRect: frame.insetBy(dx: 1, dy: 1), xRadius: 195, yRadius: 195)
    border.lineWidth = 2
    NSColor.white.withAlphaComponent(0.18).setStroke()
    border.stroke()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(filename))
}

for points in [16, 32, 128, 256, 512] {
    try drawIcon(size: points, filename: "icon_\(points)x\(points).png")
    try drawIcon(size: points * 2, filename: "icon_\(points)x\(points)@2x.png")
}
