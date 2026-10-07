import SwiftUI

struct AwakeControl: View {
    @ObservedObject var controller: AwakeController
    let isVisible: Bool
    let compact: Bool
    let onCustomTimer: () -> Void
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tomalesMotionEnabled) private var motionEnabled

    private let presets: [AwakeDuration] = [.unlimited, .fifteen, .thirty, .hour, .twoHours]
    private var motion: Animation? {
        isVisible && motionEnabled && !reduceMotion ? .easeInOut(duration: 0.22) : nil
    }

    var body: some View {
        PanelSurface(compact: compact) {
            HStack(spacing: 10) {
                AwakeIcon(isEnabled: controller.isEnabled, isVisible: isVisible)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keep display awake").font(.system(size: 13, weight: .medium))
                    Text(controller.isEnabled ? controller.statusText : "Display can sleep")
                        .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer(minLength: 8)
                Toggle("Keep display awake", isOn: Binding(get: { controller.isEnabled }, set: { controller.setEnabled($0) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            timerChoices
            if let error = controller.errorMessage {
                Text(error).font(.system(size: 11)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(motion, value: controller.duration)
    }

    private var timerChoices: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(presets) { duration in
                    Button { controller.selectDuration(duration) } label: {
                        Text(shortLabel(duration))
                            .font(.system(size: duration == .unlimited ? 16 : 11, weight: .medium))
                            .monospacedDigit().lineLimit(1)
                            .frame(maxWidth: .infinity).frame(height: 28)
                            .foregroundStyle(controller.duration == duration ? .primary : .secondary)
                            .background { if controller.duration == duration { selectedTimer } }
                            .contentShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain).accessibilityLabel(duration.label)
                    .accessibilityAddTraits(controller.duration == duration ? .isSelected : [])
                    .help(duration.label)
                }
            }
            .padding(3)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            Button(action: onCustomTimer) {
                Group {
                    if controller.duration == .custom {
                        Text("\(controller.customMinutes)m").font(.system(size: 11, weight: .medium))
                            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
                    } else { Image(systemName: "ellipsis").font(.system(size: 13, weight: .medium)) }
                }
                .frame(width: 44, height: 28).padding(3)
                .foregroundStyle(controller.duration == .custom ? .primary : .secondary)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                .background { if controller.duration == .custom { selectedTimer.padding(3) } }
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Custom timer, \(controller.customMinutes) minutes")
            .accessibilityAddTraits(controller.duration == .custom ? .isSelected : [])
            .help("Set a custom timer")
        }
        .help(controller.isEnabled ? "Changing the timer restarts the awake session." : "Choose a timer, then turn the switch on.")
    }

    private var selectedTimer: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(Color(nsColor: .controlBackgroundColor))
            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            .matchedGeometryEffect(id: "duration", in: selection)
    }

    private func shortLabel(_ duration: AwakeDuration) -> String {
        switch duration {
        case .unlimited: return "∞"
        case .fifteen: return "15m"
        case .thirty: return "30m"
        case .hour: return "1h"
        case .twoHours: return "2h"
        case .custom: return "\(controller.customMinutes)m"
        }
    }
}
