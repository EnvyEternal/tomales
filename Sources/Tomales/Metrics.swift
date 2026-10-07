import Foundation
import SystemProbe

enum MemoryPressure: Int {
    case unavailable = 0, normal = 1, warning = 2, critical = 4

    var label: String {
        switch self {
        case .unavailable: return "Unavailable"
        case .normal: return "Normal"
        case .warning: return "Elevated"
        case .critical: return "Critical"
        }
    }
}

struct MemoryMetrics {
    let total: UInt64
    let used: UInt64
    let apps: UInt64
    let wired: UInt64
    let compressed: UInt64
    let cached: UInt64
    let swapUsed: UInt64?
    let swapTotal: UInt64?
    let pressure: MemoryPressure
}

struct ProcessMetrics: Identifiable {
    let pid: Int32
    let start: UInt64
    let name: String
    let memory: UInt64
    let cpuPercent: Double?
    let estimatedMilliwatts: Double?
    var id: String { "\(pid)-\(start)" }
}

struct FanMetrics: Identifiable {
    let id: Int
    let rpm: Double?
}

enum FanReading {
    case unavailable
    case noFans
    case readings([FanMetrics])
}

struct MetricsSnapshot {
    var memory: MemoryMetrics?
    var cpuPercent: Double?
    var cpuAvailable = true
    var processes: [ProcessMetrics] = []
    var processesAvailable = true
    var skippedProcesses = 0
    var fans: FanReading = .unavailable
    var sampledAt: Date?
}

actor MetricsReader {
    private struct ProcessBaseline {
        let start: UInt64
        let cpu: UInt64
        let energy: UInt64
        let hasEnergy: Bool
    }

    private var session: UUID?
    private var cpuBaseline: [UInt64]?
    private var processBaseline: [Int32: ProcessBaseline] = [:]
    private var processTime: Double?
    private var nextProcessRead = 0.0
    private var nextFanRead = 0.0
    private var snapshot = MetricsSnapshot()

    func begin(_ token: UUID) {
        session = token
        cpuBaseline = nil
        processBaseline.removeAll(keepingCapacity: false)
        processTime = nil
        nextProcessRead = 0
        nextFanRead = 0
        snapshot = MetricsSnapshot()
    }

    func end(_ token: UUID) {
        guard session == token else { return }
        session = nil
        cpuBaseline = nil
        processBaseline.removeAll(keepingCapacity: false)
        snapshot = MetricsSnapshot()
    }

    func read(_ token: UUID, options: CollectionOptions) -> MetricsSnapshot? {
        guard session == token else { return nil }
        let now = tm_continuous_seconds()
        if options.system {
            readSystem()
        } else {
            snapshot.memory = nil
            snapshot.cpuPercent = nil
            cpuBaseline = nil
        }
        if options.processes {
            if now >= nextProcessRead { readProcesses(now: now) }
        } else {
            snapshot.processes = []
            snapshot.skippedProcesses = 0
            processBaseline.removeAll(keepingCapacity: false)
            processTime = nil
            nextProcessRead = 0
        }
        if options.fans && now >= nextFanRead {
            snapshot.fans = readFans()
            nextFanRead = now + 6
        }
        if !options.fans { snapshot.fans = .unavailable; nextFanRead = 0 }
        snapshot.sampledAt = Date()
        return snapshot
    }

    private func readSystem() {
        let raw = tm_read_system()
        if raw.memory_valid {
            snapshot.memory = MemoryMetrics(
                total: raw.total_bytes, used: raw.used_bytes, apps: raw.app_bytes,
                wired: raw.wired_bytes, compressed: raw.compressed_bytes, cached: raw.cached_bytes,
                swapUsed: raw.swap_valid ? raw.swap_used_bytes : nil,
                swapTotal: raw.swap_valid ? raw.swap_total_bytes : nil,
                pressure: MemoryPressure(rawValue: Int(raw.pressure_level)) ?? .unavailable
            )
        } else {
            snapshot.memory = nil
        }
        snapshot.cpuAvailable = raw.cpu_valid
        if raw.cpu_valid {
            let ticks = [raw.cpu_user, raw.cpu_system, raw.cpu_idle, raw.cpu_nice]
            if let previous = cpuBaseline {
                let deltas = zip(ticks, previous).map { UInt64(UInt32(truncatingIfNeeded: $0) &- UInt32(truncatingIfNeeded: $1)) }
                let total = deltas.reduce(0, +)
                snapshot.cpuPercent = total > 0 ? Double(total - deltas[2]) / Double(total) * 100 : nil
            } else { snapshot.cpuPercent = nil }
            cpuBaseline = ticks
        } else {
            cpuBaseline = nil
            snapshot.cpuPercent = nil
        }
    }

    private func readProcesses(now: Double) {
        var count = 0
        var skipped = 0
        guard let buffer = tm_read_processes(&count, &skipped) else {
            snapshot.processesAvailable = false
            snapshot.processes = []
            snapshot.skippedProcesses = 0
            processBaseline.removeAll(keepingCapacity: false)
            processTime = nil
            nextProcessRead = now + 6
            return
        }
        defer { tm_free_processes(buffer) }
        let elapsed = processTime.map { now - $0 }
        var newBaseline: [Int32: ProcessBaseline] = [:]
        var processes: [ProcessMetrics] = []
        processes.reserveCapacity(count)
        for index in 0..<count {
            var raw = buffer[index]
            let name = withUnsafePointer(to: &raw.name) {
                $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
            }
            var cpu: Double?
            var power: Double?
            if let previous = processBaseline[raw.pid], previous.start == raw.start_time,
               let elapsed, elapsed > 0 {
                if raw.cpu_nanoseconds >= previous.cpu {
                    cpu = Double(raw.cpu_nanoseconds - previous.cpu) / 1e9 / elapsed * 100
                }
                if previous.hasEnergy && raw.energy_available && raw.energy_nanojoules >= previous.energy {
                    power = Double(raw.energy_nanojoules - previous.energy) / 1e6 / elapsed
                }
            }
            processes.append(ProcessMetrics(
                pid: raw.pid, start: raw.start_time, name: name, memory: raw.footprint_bytes,
                cpuPercent: cpu, estimatedMilliwatts: power
            ))
            newBaseline[raw.pid] = ProcessBaseline(
                start: raw.start_time, cpu: raw.cpu_nanoseconds,
                energy: raw.energy_nanojoules, hasEnergy: raw.energy_available
            )
        }
        nextProcessRead = now + (processTime == nil ? 2 : 6)
        processTime = now
        processBaseline = newBaseline
        snapshot.processes = processes
        snapshot.processesAvailable = true
        snapshot.skippedProcesses = skipped
    }

    private func readFans() -> FanReading {
        var raw = tm_read_fans()
        guard raw.available else { return .unavailable }
        guard raw.count > 0 else { return .noFans }
        let count = Int(raw.count)
        return withUnsafePointer(to: &raw.fans) { pointer in
            pointer.withMemoryRebound(to: TMFanSample.self, capacity: 10) { buffer in
                .readings((0..<count).map { index in
                    let fan = buffer[index]
                    return FanMetrics(id: Int(fan.index), rpm: fan.available ? fan.rpm : nil)
                })
            }
        }
    }
}

enum DisplayFormat {
    static func bytes(_ value: UInt64) -> String {
        if value >= 1 << 30 { return String(format: "%.1f GiB", Double(value) / Double(1 << 30)) }
        if value >= 1 << 20 { return String(format: "%.0f MiB", Double(value) / Double(1 << 20)) }
        return String(format: "%.0f KiB", Double(value) / 1024)
    }

    static func percent(_ value: Double?) -> String {
        value.map { String(format: "%.1f%%", $0) } ?? "—"
    }

    static func power(_ milliwatts: Double?) -> String {
        guard let milliwatts else { return "—" }
        return milliwatts >= 1000 ? String(format: "%.2f W", milliwatts / 1000) : String(format: "%.0f mW", milliwatts)
    }
}
