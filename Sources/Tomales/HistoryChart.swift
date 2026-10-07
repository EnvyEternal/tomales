import SwiftUI

struct HistorySample: Equatable {
    let time: Double
    let cpuPercent: Double?
    let memoryPercent: Double?
    let swapBytes: Double?
}

private struct PlotVector: VectorArithmetic {
    var values: [Double]
    static var zero: PlotVector { PlotVector(values: Array(repeating: 0, count: 302)) }

    static func + (lhs: PlotVector, rhs: PlotVector) -> PlotVector {
        PlotVector(values: zip(lhs.values, rhs.values).map(+))
    }

    static func - (lhs: PlotVector, rhs: PlotVector) -> PlotVector {
        PlotVector(values: zip(lhs.values, rhs.values).map(-))
    }

    mutating func scale(by rhs: Double) { values = values.map { $0 * rhs } }
    var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }
}

private struct ChartTrace: Shape {
    var coordinates: PlotVector
    var filled = false
    var animatableData: PlotVector {
        get { coordinates }
        set { coordinates = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let values = coordinates.values
        guard values.count == 302 else { return Path() }
        var path = Path()
        for index in stride(from: 0, to: values.count, by: 2) {
            let point = CGPoint(x: values[index] * rect.width,
                                y: (1 - values[index + 1]) * rect.height)
            if index == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        if filled {
            path.addLine(to: CGPoint(x: values[300] * rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: values[0] * rect.width, y: rect.height))
            path.closeSubpath()
        }
        return path
    }
}

struct HistoryChart: View {
    let samples: [HistorySample]
    let value: KeyPath<HistorySample, Double?>
    let window: HistoryWindow
    let ceiling: Double
    let scaleLabel: String
    let showScale: Bool
    let compact: Bool
    let isVisible: Bool
    var available = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tomalesMotionEnabled) private var motionEnabled

    private var segments: [PlotVector] {
        guard let end = samples.last?.time, ceiling > 0 else { return [] }
        let start = end - Double(window.rawValue)
        var groups: [[(Double, Double)]] = []
        var current: [(Double, Double)] = []
        var previousTime: Double?
        for sample in samples where sample.time >= start {
            guard let reading = sample[keyPath: value], reading.isFinite else {
                if !current.isEmpty { groups.append(current); current = [] }
                previousTime = nil
                continue
            }
            if let previousTime, sample.time - previousTime > 4.5, !current.isEmpty {
                groups.append(current)
                current = []
            }
            current.append((max(0, min(1, (sample.time - start) / Double(window.rawValue))),
                            max(0, min(1, reading / ceiling))))
            previousTime = sample.time
        }
        if !current.isEmpty { groups.append(current) }
        return groups.filter { $0.count > 1 }.map { points in
            let bounded = Array(points.suffix(151))
            let first = bounded[0]
            let padding = Array(repeating: first, count: 151 - bounded.count)
            return PlotVector(values: (padding + bounded).flatMap { [$0.0, $0.1] })
        }
    }

    var body: some View {
        let traces = segments
        VStack(spacing: 3) {
            if showScale {
                HStack {
                    Text(scaleLabel)
                    Spacer()
                }.font(.system(size: 9)).foregroundStyle(.tertiary)
            }
            ZStack {
                GeometryReader { geometry in
                    Path { path in
                        for fraction in [0.0, 0.5, 1.0] {
                            let y = geometry.size.height * fraction
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                    }.stroke(Color.primary.opacity(0.06), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                }
                ForEach(traces.indices, id: \.self) { index in
                    ChartTrace(coordinates: traces[index], filled: true)
                        .fill(LinearGradient(colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.01)],
                                             startPoint: .top, endPoint: .bottom))
                    ChartTrace(coordinates: traces[index])
                        .stroke(Color.accentColor.opacity(0.9), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                }
                if traces.isEmpty {
                    Text(available ? "Collecting history…" : "Unavailable").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            .frame(height: compact ? 38 : 52)
            .clipped()
            .animation(!reduceMotion && motionEnabled && isVisible ? .easeInOut(duration: 0.65) : nil, value: samples)
            .animation(!reduceMotion && motionEnabled && isVisible ? .easeInOut(duration: 0.3) : nil, value: window)
            .animation(!reduceMotion && motionEnabled && isVisible ? .easeInOut(duration: 0.3) : nil, value: ceiling)
            if showScale {
                HStack {
                    Text("−\(window.label)")
                    Spacer()
                    Text("now")
                }.font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("History over \(window.label)")
        .accessibilityValue(traces.isEmpty ? (available ? "Collecting readings" : "Unavailable") : "Scale zero to \(scaleLabel)")
    }
}

struct UsageScale: View {
    let fraction: Double?
    var tint: Color = .accentColor
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tomalesMotionEnabled) private var motionEnabled

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.07))
                Capsule().fill(tint)
                    .frame(width: geometry.size.width * max(0, min(1, fraction ?? 0)))
            }
        }
        .frame(height: 4)
        .animation(!reduceMotion && motionEnabled && isVisible ? .easeInOut(duration: 0.55) : nil, value: fraction)
        .accessibilityLabel("Usage")
        .accessibilityValue(fraction.map { "\(Int($0 * 100)) percent" } ?? "Unavailable")
    }
}
