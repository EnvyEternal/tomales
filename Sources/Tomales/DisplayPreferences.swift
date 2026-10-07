import Combine
import Foundation

enum HistoryWindow: Int, Codable, CaseIterable, Identifiable {
    case minute = 60, threeMinutes = 180, fiveMinutes = 300
    var id: Int { rawValue }
    var label: String { "\(rawValue / 60) min" }
}

struct DisplayConfiguration: Codable, Equatable {
    var showMemory = true
    var showCPU = true
    var showSwap = true
    var showProcesses = true
    var showFans = true
    var showMemoryDetails = false
    var showUsageBars = false
    var showCharts = true
    var memoryChart = true
    var cpuChart = true
    var swapChart = false
    var showChartScale = false
    var historyWindow: HistoryWindow = .minute
    var processCount = 3
    var showProcessIDs = false
    var defaultSort: ProcessSort = .memory
    var compactLayout = true
    var animations = true

    var collection: CollectionOptions {
        CollectionOptions(system: showMemory || showCPU || showSwap,
                          processes: showProcesses, fans: showFans)
    }

    var hasMetrics: Bool { showMemory || showCPU || showSwap || showProcesses || showFans }

    enum CodingKeys: String, CodingKey {
        case showMemory, showCPU, showSwap, showProcesses, showFans, showMemoryDetails
        case showUsageBars, showCharts, memoryChart, cpuChart, swapChart, showChartScale
        case historyWindow, processCount, showProcessIDs, defaultSort, compactLayout, animations
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        showMemory = try values.decodeIfPresent(Bool.self, forKey: .showMemory) ?? true
        showCPU = try values.decodeIfPresent(Bool.self, forKey: .showCPU) ?? true
        showSwap = try values.decodeIfPresent(Bool.self, forKey: .showSwap) ?? true
        showProcesses = try values.decodeIfPresent(Bool.self, forKey: .showProcesses) ?? true
        showFans = try values.decodeIfPresent(Bool.self, forKey: .showFans) ?? true
        showMemoryDetails = try values.decodeIfPresent(Bool.self, forKey: .showMemoryDetails) ?? false
        showUsageBars = try values.decodeIfPresent(Bool.self, forKey: .showUsageBars) ?? false
        showCharts = try values.decodeIfPresent(Bool.self, forKey: .showCharts) ?? true
        memoryChart = try values.decodeIfPresent(Bool.self, forKey: .memoryChart) ?? true
        cpuChart = try values.decodeIfPresent(Bool.self, forKey: .cpuChart) ?? true
        swapChart = try values.decodeIfPresent(Bool.self, forKey: .swapChart) ?? false
        showChartScale = try values.decodeIfPresent(Bool.self, forKey: .showChartScale) ?? false
        historyWindow = try values.decodeIfPresent(HistoryWindow.self, forKey: .historyWindow) ?? .minute
        processCount = try values.decodeIfPresent(Int.self, forKey: .processCount) ?? 3
        if ![3, 5, 8].contains(processCount) { processCount = 3 }
        showProcessIDs = try values.decodeIfPresent(Bool.self, forKey: .showProcessIDs) ?? false
        defaultSort = try values.decodeIfPresent(ProcessSort.self, forKey: .defaultSort) ?? .memory
        compactLayout = try values.decodeIfPresent(Bool.self, forKey: .compactLayout) ?? true
        animations = try values.decodeIfPresent(Bool.self, forKey: .animations) ?? true
    }
}

@MainActor
final class DisplayPreferences: ObservableObject {
    @Published var configuration: DisplayConfiguration {
        didSet {
            if let data = try? JSONEncoder().encode(configuration) {
                UserDefaults.standard.set(data, forKey: "displayConfiguration.v1")
            }
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "displayConfiguration.v1"),
           let stored = try? JSONDecoder().decode(DisplayConfiguration.self, from: data) {
            configuration = stored
        } else { configuration = DisplayConfiguration() }
    }

    func reset() { configuration = DisplayConfiguration() }
}

struct CollectionOptions: Sendable {
    var system = true
    var processes = true
    var fans = true
}
