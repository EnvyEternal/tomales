import AppKit
import SwiftUI

struct PanelView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: DisplayPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: AppModel) {
        self.model = model
        preferences = model.preferences
    }

    private var configuration: DisplayConfiguration { preferences.configuration }
    private var motion: Animation? {
        configuration.animations && !reduceMotion && model.isPanelVisible ? .easeInOut(duration: 0.24) : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .top) {
                if model.isSettingsVisible {
                    SettingsView(preferences: preferences, version: model.version, osVersion: model.osVersion)
                        .transition(.opacity.combined(with: .offset(x: 8)))
                } else {
                    overview.transition(.opacity.combined(with: .offset(x: -8)))
                }
            }
            .frame(maxHeight: .infinity)
            .animation(motion, value: model.isSettingsVisible)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PanelBackdrop())
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        .environment(\.tomalesMotionEnabled, configuration.animations && !model.isTimerEditorVisible)
        .sheet(isPresented: Binding(get: { model.isTimerEditorVisible }, set: { if !$0 { model.closeTimerEditor() } })) {
            TimerEditor(controller: model.awake, onDismiss: model.closeTimerEditor)
                .environment(\.tomalesMotionEnabled, configuration.animations)
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            if model.isSettingsVisible {
                Button { model.closeSettings() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .medium)).frame(width: 30, height: 30)
                }.buttonStyle(.plain).help("Back to overview")
                Text("Settings").font(.system(size: 15, weight: .semibold))
            } else {
                BrandBadge(controller: model.awake, isVisible: model.isPanelVisible)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tomales").font(.system(size: 15, weight: .semibold))
                    Text("System overview").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !model.isSettingsVisible {
                Button { model.openSettings() } label: {
                    Image(systemName: "gearshape").font(.system(size: 14)).foregroundStyle(.secondary).frame(width: 30, height: 30)
                }.buttonStyle(.plain).help("Settings").keyboardShortcut(",", modifiers: .command)
            }
        }
        .frame(height: 32).padding(.horizontal, 17).padding(.vertical, 10)
        .animation(motion, value: model.isSettingsVisible)
    }

    private var overview: some View {
        AdaptiveScrollView {
            VStack(spacing: configuration.compactLayout ? 11 : 15) {
                AwakeControl(controller: model.awake, isVisible: model.isPanelVisible, compact: configuration.compactLayout,
                             onCustomTimer: model.openTimerEditor)
                if configuration.showMemory || configuration.showCPU || configuration.showSwap { systemOverview }
                if configuration.showMemory && configuration.showMemoryDetails { memoryDetails }
                if configuration.showProcesses { processSection }
                if configuration.showFans { fanSection }
                if !configuration.hasMetrics {
                    EmptyReading(text: "Choose what to display in Settings.").padding(.vertical, 20)
                }
            }
            .padding(.horizontal, 16)
            .animation(motion, value: configuration)
        }
    }

    private var systemOverview: some View {
        PanelSurface(compact: configuration.compactLayout) {
            if configuration.showMemory || configuration.showCPU {
                HStack(alignment: .top, spacing: 18) {
                    if configuration.showMemory { memoryMetric }
                    if configuration.showCPU { cpuMetric }
                }.fixedSize(horizontal: false, vertical: true)
            }
            if configuration.showMemory {
                HStack(spacing: 5) {
                    let pressure = model.snapshot.memory?.pressure ?? .unavailable
                    Circle().fill(pressureColor(pressure)).frame(width: 5, height: 5)
                    Text("Memory pressure: \(pressure.label.lowercased())").foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }.font(.system(size: 11))
            }
            if configuration.showSwap {
                if configuration.showMemory || configuration.showCPU { Divider() }
                swapReadings
            }
        }
    }

    private var memoryMetric: some View {
        VStack(alignment: .leading, spacing: 7) {
            MetricHeading(title: "Memory", symbol: "memorychip", isVisible: model.isPanelVisible,
                          trigger: Int(model.history.last?.memoryPercent ?? -5) / 5)
            metricValue(model.snapshot.memory.map { DisplayFormat.bytes($0.used) } ?? "—")
            Text(model.snapshot.memory.map { "of \(DisplayFormat.bytes($0.total))" }
                 ?? (model.snapshot.sampledAt == nil ? "Reading memory…" : "Unavailable"))
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            if configuration.showUsageBars {
                UsageScale(fraction: model.history.last?.memoryPercent.map { $0 / 100 }, isVisible: model.isPanelVisible)
            }
            if configuration.showCharts && configuration.memoryChart {
                historyChart(\.memoryPercent, ceiling: 100, scale: "100%")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cpuMetric: some View {
        VStack(alignment: .leading, spacing: 7) {
            MetricHeading(title: "CPU", symbol: "cpu", isVisible: model.isPanelVisible,
                          trigger: Int(model.snapshot.cpuPercent ?? -10) / 10)
            metricValue(DisplayFormat.percent(model.snapshot.cpuPercent))
            Text(model.snapshot.cpuAvailable ? "\(model.coreCount) logical cores" : "CPU unavailable")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            if configuration.showUsageBars {
                UsageScale(fraction: model.snapshot.cpuPercent.map { $0 / 100 }, isVisible: model.isPanelVisible)
            }
            if configuration.showCharts && configuration.cpuChart {
                historyChart(\.cpuPercent, ceiling: 100, scale: "100%")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var swapReadings: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Swap used").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(model.snapshot.memory?.swapUsed.map(DisplayFormat.bytes) ?? "—")
                        .font(.system(size: 13, weight: .medium)).monospacedDigit()
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Compressed").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(model.snapshot.memory.map { DisplayFormat.bytes($0.compressed) } ?? "—")
                        .font(.system(size: 13, weight: .medium)).monospacedDigit()
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if configuration.showCharts && configuration.swapChart {
                historyChart(\.swapBytes, ceiling: swapCeiling, scale: DisplayFormat.bytes(UInt64(swapCeiling)))
                    .help("Swap history. The vertical scale adapts to usage, with a minimum of 1 GiB.")
            }
        }
    }

    private var memoryDetails: some View {
        PanelSurface(compact: configuration.compactLayout) {
            MetricHeading(title: "Memory breakdown", symbol: "square.stack", isVisible: model.isPanelVisible)
            if let memory = model.snapshot.memory {
                DetailRow(title: "App memory", value: DisplayFormat.bytes(memory.apps))
                DetailRow(title: "Wired", value: DisplayFormat.bytes(memory.wired))
                DetailRow(title: "Cached files", value: DisplayFormat.bytes(memory.cached))
            } else { EmptyReading(text: "Memory details unavailable") }
        }
    }

    private var processSection: some View {
        PanelSurface(compact: configuration.compactLayout) {
            HStack {
                MetricHeading(title: "Top processes", symbol: model.sort == .energy ? "bolt" : "list.bullet",
                              isVisible: model.isPanelVisible, trigger: ProcessSort.allCases.firstIndex(of: model.sort) ?? 0)
                Spacer()
                Picker("Sort processes", selection: $model.sort) {
                    ForEach(ProcessSort.allCases) { sort in Text(sort.rawValue).tag(sort) }
                }.labelsHidden().controlSize(.small).frame(width: 106)
            }
            if !model.snapshot.processesAvailable {
                EmptyReading(text: "Process data unavailable")
            } else if model.sort == .energy && !model.hasEnergyReadings {
                EmptyReading(text: "Energy estimates are unavailable or still collecting.")
            } else if model.topProcesses.isEmpty {
                EmptyReading(text: "Reading processes…")
            } else {
                VStack(spacing: 0) {
                    ForEach(model.topProcesses) { process in
                        HStack(spacing: 7) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(process.name).lineLimit(1).truncationMode(.middle)
                                if configuration.showProcessIDs {
                                    Text("PID \(process.pid)").font(.system(size: 9)).foregroundStyle(.tertiary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text(processValue(process)).foregroundStyle(.secondary)
                                .frame(minWidth: 78, alignment: .trailing)
                        }
                        .font(.system(size: 12)).monospacedDigit()
                        .padding(.vertical, configuration.compactLayout ? 5 : 8)
                        .help("\(process.name) · PID \(process.pid)")
                        .transition(.opacity)
                    }
                }
                .animation(motion, value: model.topProcesses.map(\.id))
                .animation(motion, value: model.sort)
            }
            if model.sort == .energy {
                Text("Estimated process power").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .help(model.sort == .energy
                  ? "Estimated from available kernel counters over the sample interval. Not Activity Monitor's Energy Impact or whole-Mac power. Some Macs do not expose these counters."
                  : "Processes refresh every 6 seconds. A process can use multiple cores. Exited or inaccessible processes are skipped.")
    }

    private var fanSection: some View {
        HStack {
            MetricHeading(title: "Fans", symbol: "fanblades", isVisible: model.isPanelVisible, spinning: hasRunningFans)
            Spacer()
            switch model.snapshot.fans {
            case .unavailable:
                Text(model.snapshot.sampledAt == nil ? "Reading…" : "Unavailable")
                    .foregroundStyle(.secondary).help("This Mac has not exposed compatible fan sensors.")
            case .noFans: Text("No fans reported").foregroundStyle(.secondary)
            case .readings(let fans):
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(fans) { fan in
                        Text(fan.rpm.map { "\(Int($0.rounded())) RPM" } ?? "Unavailable")
                            .monospacedDigit().help("Fan \(fan.id + 1)")
                    }
                }
            }
        }.font(.system(size: 11)).padding(.horizontal, 13).padding(.vertical, 4)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.7)
            HStack {
                Text("v\(model.version)").foregroundStyle(.tertiary).help(model.osVersion)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
            }
            .buttonStyle(.borderless).font(.system(size: 10))
            .padding(.horizontal, 18).padding(.vertical, 11)
        }
    }

    private func metricValue(_ text: String) -> some View {
        Text(text).font(.system(size: configuration.compactLayout ? 23 : 26, weight: .semibold))
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            .contentTransition(.opacity).animation(motion, value: text)
    }

    private func processValue(_ process: ProcessMetrics) -> String {
        switch model.sort {
        case .memory: return DisplayFormat.bytes(process.memory)
        case .cpu: return DisplayFormat.percent(process.cpuPercent)
        case .energy: return DisplayFormat.power(process.estimatedMilliwatts)
        }
    }

    private func historyChart(_ key: KeyPath<HistorySample, Double?>, ceiling: Double, scale: String) -> some View {
        let available = model.snapshot.sampledAt == nil || (key == \HistorySample.cpuPercent
            ? model.snapshot.cpuAvailable
            : key == \HistorySample.swapBytes ? model.snapshot.memory?.swapUsed != nil : model.snapshot.memory != nil)
        return HistoryChart(samples: model.history, value: key, window: configuration.historyWindow,
                     ceiling: ceiling, scaleLabel: scale, showScale: configuration.showChartScale,
                     compact: configuration.compactLayout, isVisible: model.isPanelVisible && !model.isSettingsVisible,
                     available: available)
    }

    private var swapCeiling: Double {
        let end = model.history.last?.time ?? 0
        let maximum = model.history.filter { $0.time >= end - Double(configuration.historyWindow.rawValue) }
            .compactMap(\.swapBytes).max() ?? 0
        let gib = Double(1 << 30)
        return max(gib, ceil(maximum * 1.1 / gib) * gib)
    }

    private var hasRunningFans: Bool {
        guard case .readings(let fans) = model.snapshot.fans else { return false }
        return fans.contains { ($0.rpm ?? 0) > 0 }
    }

    private func pressureColor(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unavailable: return .secondary
        }
    }
}
