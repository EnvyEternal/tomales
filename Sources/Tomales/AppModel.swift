import AppKit
import Combine

enum ProcessSort: String, Codable, CaseIterable, Identifiable {
    case memory = "Memory", cpu = "CPU", energy = "Energy"
    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot = MetricsSnapshot()
    @Published private(set) var isPanelVisible = false
    @Published private(set) var isSettingsVisible = false
    @Published private(set) var isTimerEditorVisible = false
    @Published private(set) var history: [HistorySample] = []
    @Published var sort: ProcessSort
    let preferences = DisplayPreferences()
    let awake = AwakeController()
    let coreCount = ProcessInfo.processInfo.activeProcessorCount
    let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }
    private let reader = MetricsReader()
    private var monitorTask: Task<Void, Never>?
    private var token: UUID?
    private var preferenceSubscription: AnyCancellable?

    init() {
        sort = preferences.configuration.defaultSort
        preferenceSubscription = preferences.$configuration
            .map(\.defaultSort).removeDuplicates().dropFirst()
            .sink { [weak self] in self?.sort = $0 }
    }

    var topProcesses: [ProcessMetrics] {
        let sorted = snapshot.processes.sorted { left, right in
            switch sort {
            case .memory: return left.memory == right.memory ? left.pid < right.pid : left.memory > right.memory
            case .cpu:
                let a = left.cpuPercent ?? -1, b = right.cpuPercent ?? -1
                return a == b ? left.pid < right.pid : a > b
            case .energy:
                let a = left.estimatedMilliwatts ?? -1, b = right.estimatedMilliwatts ?? -1
                return a == b ? left.pid < right.pid : a > b
            }
        }
        return Array(sorted.prefix(preferences.configuration.processCount))
    }

    var hasEnergyReadings: Bool { snapshot.processes.contains { $0.estimatedMilliwatts != nil } }

    func showPanel() {
        isSettingsVisible = false
        isTimerEditorVisible = false
        isPanelVisible = true
        awake.reconcile()
        startMonitoring()
    }

    func hidePanel() {
        isPanelVisible = false
        stopMonitoring()
        isSettingsVisible = false
        isTimerEditorVisible = false
    }

    func pauseMonitoring() { stopMonitoring() }

    func resumeMonitoring() {
        if isPanelVisible && !isSettingsVisible && !isTimerEditorVisible { awake.reconcile(); startMonitoring() }
    }

    func openSettings() {
        isSettingsVisible = true
        stopMonitoring(clearData: false)
    }

    func closeSettings() {
        isSettingsVisible = false
        if isPanelVisible && !isTimerEditorVisible { startMonitoring(clearData: false) }
    }

    func openTimerEditor() {
        guard isPanelVisible else { return }
        awake.reconcile()
        isTimerEditorVisible = true
        stopMonitoring(clearData: false)
    }

    func closeTimerEditor() {
        guard isTimerEditorVisible else { return }
        isTimerEditorVisible = false
        awake.reconcile()
        if isPanelVisible && !isSettingsVisible { startMonitoring(clearData: false) }
    }

    func shutdown() {
        hidePanel()
        awake.shutdown()
    }

    private func startMonitoring(clearData: Bool = true) {
        guard monitorTask == nil else { return }
        if clearData { snapshot = MetricsSnapshot(); history.removeAll() }
        let session = UUID()
        token = session
        let collector = reader
        monitorTask = Task { [weak self] in
            await collector.begin(session)
            while !Task.isCancelled {
                guard let options = self?.preferences.configuration.collection else { break }
                let snapshot = await collector.read(session, options: options)
                guard !Task.isCancelled, let self, self.token == session else { break }
                if let snapshot {
                    self.snapshot = snapshot
                    self.record(snapshot)
                }
                self.awake.reconcile()
                if self.awake.isEnabled { self.awake.objectWillChange.send() }
                do { try await Task.sleep(nanoseconds: 2_000_000_000) }
                catch { break }
            }
            await collector.end(session)
        }
    }

    private func stopMonitoring(clearData: Bool = true) {
        token = nil
        monitorTask?.cancel()
        monitorTask = nil
        if clearData { snapshot = MetricsSnapshot(); history.removeAll() }
    }

    private func record(_ snapshot: MetricsSnapshot) {
        let time = ProcessInfo.processInfo.systemUptime
        let memory = snapshot.memory
        let fraction = memory.flatMap { $0.total > 0 ? Double($0.used) / Double($0.total) * 100 : nil }
        history.append(HistorySample(time: time, cpuPercent: snapshot.cpuPercent,
                                     memoryPercent: fraction, swapBytes: memory?.swapUsed.map(Double.init)))
        history.removeAll { $0.time < time - 300 }
        if history.count > 151 { history.removeFirst(history.count - 151) }
    }
}
