import SwiftUI

struct TimerEditor: View {
    @ObservedObject var controller: AwakeController
    let onDismiss: () -> Void
    @State private var hours: Double
    @State private var minutes: Double
    @State private var error: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tomalesMotionEnabled) private var motionEnabled

    init(controller: AwakeController, onDismiss: @escaping () -> Void) {
        self.controller = controller
        self.onDismiss = onDismiss
        let initial = controller.duration.rawValue > 0 ? controller.duration.rawValue : controller.customMinutes
        _hours = State(initialValue: Double(initial / 60))
        _minutes = State(initialValue: Double(initial % 60))
    }

    private var totalMinutes: Int { Int(hours.rounded()) * 60 + Int(minutes.rounded()) }
    private var timeLabel: String {
        if hours == 0 { return "\(Int(minutes.rounded())) min" }
        if minutes == 0 { return "\(Int(hours.rounded())) h" }
        return "\(Int(hours.rounded())) h \(Int(minutes.rounded())) min"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Custom timer").font(.system(size: 15, weight: .semibold))
            Text(timeLabel)
                .font(.system(size: 32, weight: .medium)).monospacedDigit()
                .frame(maxWidth: .infinity).padding(.vertical, 4)
                .contentTransition(.opacity)
                .animation(motionEnabled && !reduceMotion ? .easeInOut(duration: 0.12) : nil, value: totalMinutes)
            timeControl("Hours", value: $hours, maximum: 24)
            timeControl("Minutes", value: $minutes, maximum: 59).disabled(hours == 24)
            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                Button("Cancel", action: onDismiss).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Set timer") {
                    if controller.selectDuration(.custom, customMinutes: totalMinutes) { onDismiss() }
                    else { error = controller.errorMessage }
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                .disabled(totalMinutes == 0)
            }.controlSize(.regular)
        }
        .padding(22).frame(width: 340)
        .onChange(of: hours) { value in if value == 24 { minutes = 0 } }
    }

    private func timeControl(_ title: String, value: Binding<Double>, maximum: Double) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer()
                Stepper(value: value, in: 0...maximum, step: 1) {
                    Text("\(Int(value.wrappedValue.rounded()))").monospacedDigit().frame(width: 24, alignment: .trailing)
                }.fixedSize().accessibilityLabel(title)
            }.font(.system(size: 12))
            Slider(value: value, in: 0...maximum, step: 1).labelsHidden().accessibilityLabel(title)
        }
    }
}
