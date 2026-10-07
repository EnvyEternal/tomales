import AppKit
import SwiftUI

enum BrandStyle {
    static let teal = Color(red: 0.10, green: 0.55, blue: 0.60)
    static let blue = Color(red: 0.24, green: 0.48, blue: 0.79)
    static let gold = Color(red: 0.86, green: 0.58, blue: 0.18)
    static let violet = Color(red: 0.52, green: 0.44, blue: 0.74)
}

struct BrandBadge: View {
    @ObservedObject var controller: AwakeController
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tomalesMotionEnabled) private var motionEnabled

    var body: some View {
        Image(nsImage: MenuBarArtwork.applicationIcon)
            .resizable()
            .interpolation(.high)
            .frame(width: 32, height: 32)
            .shadow(color: BrandStyle.teal.opacity(0.12), radius: 4, y: 2)
            .scaleEffect(isVisible ? (controller.isEnabled ? 1.04 : 1) : 0.86)
            .rotationEffect(.degrees(isVisible && controller.isEnabled ? -3 : 0))
            .animation(reduceMotion || !motionEnabled || !isVisible ? nil : .spring(response: 0.4, dampingFraction: 0.72), value: isVisible)
            .animation(reduceMotion || !motionEnabled || !isVisible ? nil : .spring(response: 0.4, dampingFraction: 0.72), value: controller.isEnabled)
            .accessibilityHidden(true)
    }
}

struct MetricIcon: View {
    let symbol: String
    let tint: Color
    let isVisible: Bool
    var trigger = 0
    var spinning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tomalesMotionEnabled) private var motionEnabled
    @State private var pulsing = false
    @State private var hovered = false

    private struct MotionKey: Equatable {
        let trigger: Int
        let visible: Bool
        let reduced: Bool
        let spinning: Bool
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04))
            if spinning && isVisible && !reduceMotion && motionEnabled {
                RotatingFan(symbol: symbol)
            } else {
                Image(systemName: symbol)
                    .id(symbol)
                    .transition(.opacity.combined(with: .scale(scale: 0.82)))
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(tint)
        .frame(width: 22, height: 22)
        .scaleEffect(reduceMotion || !motionEnabled || !isVisible ? 1 : (hovered ? 1.10 : (pulsing ? 1.07 : 1)))
        .animation(reduceMotion || !motionEnabled || !isVisible ? nil : .easeInOut(duration: 0.18), value: hovered)
        .animation(reduceMotion || !motionEnabled || !isVisible ? nil : .easeInOut(duration: 0.2), value: symbol)
        .onHover { hovered = $0 }
        .task(id: MotionKey(trigger: trigger, visible: isVisible, reduced: reduceMotion || !motionEnabled, spinning: spinning)) {
            pulsing = false
            guard isVisible && !reduceMotion && motionEnabled && !spinning else { return }
            withAnimation(.easeOut(duration: 0.16)) { pulsing = true }
            do { try await Task.sleep(nanoseconds: 180_000_000) }
            catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.28)) { pulsing = false }
        }
        .accessibilityHidden(true)
    }
}

private struct RotatingFan: View {
    let symbol: String
    @State private var rotating = false

    var body: some View {
        Image(systemName: symbol)
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .animation(.linear(duration: 5).repeatForever(autoreverses: false), value: rotating)
            .onAppear { rotating = true }
    }
}

struct AwakeIcon: View {
    let isEnabled: Bool
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tomalesMotionEnabled) private var motionEnabled

    var body: some View {
        ZStack {
            Circle().fill(BrandStyle.gold.opacity(isEnabled ? 0.14 : 0.04))
            Image(systemName: isEnabled ? "sun.max.fill" : "sun.max")
                .id(isEnabled)
                .transition(.opacity.combined(with: .scale(scale: 0.65)))
                .rotationEffect(.degrees(isEnabled ? 30 : 0))
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(isEnabled ? BrandStyle.gold : .secondary)
        .frame(width: 26, height: 26)
        .scaleEffect(isEnabled ? 1.06 : 1)
        .animation(reduceMotion || !motionEnabled || !isVisible ? nil : .spring(response: 0.38, dampingFraction: 0.7), value: isEnabled)
        .accessibilityHidden(true)
    }
}

@MainActor
enum MenuBarArtwork {
    static let idle = draw(enabled: false)
    static let awake = draw(enabled: true)
    static let applicationIcon: NSImage = {
        guard let url = Bundle.main.url(forResource: "TomalesIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return idle }
        return image
    }()

    private static func draw(enabled: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let ridge = NSBezierPath()
            ridge.move(to: NSPoint(x: 2.5, y: 5.8))
            ridge.line(to: NSPoint(x: 7.2, y: 13.3))
            ridge.line(to: NSPoint(x: 11.7, y: 6.1))
            ridge.line(to: NSPoint(x: 14.3, y: 9.5))
            ridge.line(to: NSPoint(x: 17.5, y: 5.8))
            ridge.lineWidth = 1.35
            ridge.lineJoinStyle = .round
            ridge.lineCapStyle = .round
            ridge.stroke()
            let wave = NSBezierPath()
            wave.move(to: NSPoint(x: 2.5, y: 3.2))
            wave.curve(to: NSPoint(x: 17.5, y: 3.2), controlPoint1: NSPoint(x: 7, y: 5.2), controlPoint2: NSPoint(x: 13, y: 1.2))
            wave.lineWidth = 1.25
            wave.lineCapStyle = .round
            wave.stroke()
            let sun = NSBezierPath(ovalIn: NSRect(x: 13.2, y: 12, width: 3.4, height: 3.4))
            sun.lineWidth = 1.1
            if enabled { sun.fill() } else { sun.stroke() }
            return true
        }
        image.isTemplate = true
        return image
    }
}
