import SwiftUI

private enum SettingsPage: String, CaseIterable, Identifiable {
    case display = "Display", graphs = "Graphs", more = "More"
    var id: String { rawValue }
}

private enum MetricPresentation: String, CaseIterable, Identifiable {
    case numbers = "Numbers only", bars = "Bars", graphs = "Graphs", both = "Graphs & bars"
    var id: String { rawValue }
}

struct SettingsView: View {
    @ObservedObject var preferences: DisplayPreferences
    let version: String
    let osVersion: String
    @State private var page: SettingsPage = .display
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tomalesMotionEnabled) private var motionEnabled

    private var configuration: DisplayConfiguration { preferences.configuration }
    private var motion: Animation? { motionEnabled && !reduceMotion ? .easeInOut(duration: 0.2) : nil }
    private var presentation: Binding<MetricPresentation> {
        Binding(get: {
            if configuration.showCharts { return configuration.showUsageBars ? .both : .graphs }
            return configuration.showUsageBars ? .bars : .numbers
        }, set: { value in
            preferences.configuration.showCharts = value == .graphs || value == .both
            preferences.configuration.showUsageBars = value == .bars || value == .both
            if preferences.configuration.showCharts && !configuration.memoryChart && !configuration.cpuChart && !configuration.swapChart {
                preferences.configuration.memoryChart = true
                preferences.configuration.cpuChart = true
            }
        })
    }

    var body: some View {
        VStack(spacing: 14) {
            Picker("Settings section", selection: $page) {
                ForEach(SettingsPage.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 16)
            AdaptiveScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch page {
                    case .display: displaySettings
                    case .graphs: graphSettings
                    case .more: moreSettings
                    }
                }
                .font(.system(size: 12)).controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
            }.id(page).transition(.opacity)
        }
        .animation(motion, value: page)
    }

    private var displaySettings: some View {
        Group {
            explanation("Choose what appears in the panel.")
            SettingsGroup(title: "System") {
                settingsToggle("Memory", detail: "Used RAM and memory pressure", value: $preferences.configuration.showMemory)
                Divider()
                settingsToggle("CPU", detail: "Overall processor load", value: $preferences.configuration.showCPU)
                Divider()
                settingsToggle("Swap & compression", detail: "Swap on disk and compressed RAM", value: $preferences.configuration.showSwap)
            }
            SettingsGroup(title: "Activity") {
                settingsToggle("Top processes", detail: "Processes using the most resources", value: $preferences.configuration.showProcesses)
                Divider()
                settingsToggle("Fans", detail: "Fan speed, when available", value: $preferences.configuration.showFans)
            }
        }
    }

    private var graphSettings: some View {
        Group {
            explanation("Choose how memory and CPU usage look.")
            SettingsGroup(title: "Presentation") {
                HStack {
                    Text("Style")
                    Spacer()
                    Picker("Metric style", selection: presentation) {
                        ForEach(MetricPresentation.allCases) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().frame(width: 155)
                }.padding(.vertical, 3)
                Divider()
                HStack {
                    Text("History length")
                    Spacer()
                    Picker("History length", selection: $preferences.configuration.historyWindow) {
                        ForEach(HistoryWindow.allCases) { window in
                            Text("\(window.rawValue / 60) \(window == .minute ? "minute" : "minutes")").tag(window)
                        }
                    }.labelsHidden().frame(width: 155)
                }.padding(.vertical, 3).disabled(!configuration.showCharts)
            }
            explanation("History starts when you open the panel and clears when you close it.")
            SettingsGroup(title: "Options") {
                DisclosureGroup("Customize graphs") {
                    VStack(spacing: 10) {
                        settingsToggle("Memory", value: $preferences.configuration.memoryChart).disabled(!configuration.showMemory)
                        settingsToggle("CPU", value: $preferences.configuration.cpuChart).disabled(!configuration.showCPU)
                        settingsToggle("Swap", value: $preferences.configuration.swapChart).disabled(!configuration.showSwap)
                        Divider()
                        settingsToggle("Show axis labels", value: $preferences.configuration.showChartScale)
                    }.padding(.top, 12)
                }.disabled(!configuration.showCharts)
            }
        }
    }

    private var moreSettings: some View {
        Group {
            SettingsGroup(title: "Appearance") {
                settingsToggle("Compact spacing", value: $preferences.configuration.compactLayout)
                Divider()
                settingsToggle("Animations", value: $preferences.configuration.animations)
            }
            explanation("Uses your Mac’s appearance and Reduce Motion setting.")
            SettingsGroup(title: "Details") {
                settingsToggle("Memory breakdown", value: $preferences.configuration.showMemoryDetails).disabled(!configuration.showMemory)
                Divider()
                HStack {
                    Text("Processes shown")
                    Spacer()
                    Picker("Processes shown", selection: $preferences.configuration.processCount) {
                        ForEach([3, 5, 8], id: \.self) { Text("\($0)").tag($0) }
                    }.labelsHidden().frame(width: 90)
                }.disabled(!configuration.showProcesses)
                Divider()
                DisclosureGroup("Process options") {
                    VStack(spacing: 12) {
                        settingsToggle("Show process IDs", value: $preferences.configuration.showProcessIDs)
                        HStack {
                            Text("Default sorting")
                            Spacer()
                            Picker("Default sorting", selection: $preferences.configuration.defaultSort) {
                                ForEach(ProcessSort.allCases) { Text($0.rawValue).tag($0) }
                            }.labelsHidden().frame(width: 115)
                        }
                    }.padding(.top, 12)
                }.disabled(!configuration.showProcesses)
            }
            SettingsGroup(title: "About") {
                HStack {
                    Text("Tomales")
                    Spacer()
                    Text(version).foregroundStyle(.secondary)
                }.help(osVersion)
                Divider()
                DisclosureGroup("Updates") { UpdateInformation().padding(.top, 10) }
            }
            Button("Restore default settings") { preferences.reset() }
                .buttonStyle(.borderless).frame(maxWidth: .infinity).padding(.vertical, 5)
        }
    }

    private func settingsToggle(_ title: String, detail: String? = nil, value: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                if let detail { Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Toggle(title, isOn: value).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }.padding(.vertical, 3)
    }

    private func explanation(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 3)
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).padding(.leading, 3)
            PanelSurface { content() }
        }
    }
}

private struct UpdateInformation: View {
    @State private var copied = false
    private var tap: String? { Bundle.main.object(forInfoDictionaryKey: "TomalesHomebrewTap") as? String }
    private var isFormula: Bool { Bundle.main.object(forInfoDictionaryKey: "TomalesHomebrewKind") as? String == "formula" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let tap, !tap.isEmpty {
                let command = isFormula
                    ? "brew update && brew upgrade \(tap)/tomales && tomales --restart"
                    : "brew update && brew upgrade --cask \(tap)/tomales && open -a Tomales"
                Text("Update with Homebrew.").foregroundStyle(.secondary)
                Text(command).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                Text("Updating ends the awake session. Your settings are kept.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(copied ? "Copied" : "Copy update command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    copied = true
                }
            } else {
                Text("This local version isn’t connected to Homebrew releases yet.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
