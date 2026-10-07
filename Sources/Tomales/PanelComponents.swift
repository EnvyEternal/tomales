import SwiftUI

private struct MotionPreferenceKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var tomalesMotionEnabled: Bool {
        get { self[MotionPreferenceKey.self] }
        set { self[MotionPreferenceKey.self] = newValue }
    }
}

struct PanelSurface<Content: View>: View {
    var compact = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(compact ? 14 : 17)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
    }
}

struct MetricHeading: View {
    let title: String
    let symbol: String
    let isVisible: Bool
    var trigger = 0
    var spinning = false

    var body: some View {
        HStack(spacing: 7) {
            MetricIcon(symbol: symbol, tint: .secondary, isVisible: isVisible, trigger: trigger, spinning: spinning)
            Text(title).font(.system(size: 12, weight: .medium))
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }.font(.system(size: 11))
    }
}

struct EmptyReading: View {
    let text: String

    var body: some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
