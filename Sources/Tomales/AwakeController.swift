import AppKit
import Combine
import IOKit.pwr_mgt
import SystemProbe

enum AwakeDuration: Int, CaseIterable, Identifiable {
    case unlimited = 0, fifteen = 15, thirty = 30, hour = 60, twoHours = 120, custom = -1
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .unlimited: return "Until turned off"
        case .fifteen: return "15 minutes"
        case .thirty: return "30 minutes"
        case .hour: return "1 hour"
        case .twoHours: return "2 hours"
        case .custom: return "Custom…"
        }
    }
}

@MainActor
final class AwakeController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var duration: AwakeDuration
    @Published private(set) var customMinutes: Int
    @Published private(set) var errorMessage: String?
    private var assertionID: IOPMAssertionID?
    private var continuousDeadline: Double?
    private var expiryTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init() {
        duration = AwakeDuration(rawValue: UserDefaults.standard.integer(forKey: "awakeDuration")) ?? .unlimited
        customMinutes = min(1440, max(1, UserDefaults.standard.object(forKey: "customMinutes") as? Int ?? 45))
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.reconcile() } })
    }

    var remainingSeconds: Double? { continuousDeadline.map { max(0, $0 - tm_continuous_seconds()) } }

    var statusText: String {
        guard isEnabled else { return "Your normal display sleep settings apply." }
        guard let remaining = remainingSeconds else { return "On until you turn it off." }
        let seconds = Int(ceil(remaining))
        return String(format: "%02d:%02d:%02d remaining", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }

    func setEnabled(_ enabled: Bool) {
        if enabled { replaceAssertion(duration: duration, minutes: customMinutes) }
        else { releaseAssertion() }
    }

    @discardableResult
    func selectDuration(_ newDuration: AwakeDuration, customMinutes newMinutes: Int? = nil) -> Bool {
        let minutes = min(1440, max(1, newMinutes ?? customMinutes))
        if isEnabled && !replaceAssertion(duration: newDuration, minutes: minutes) { return false }
        duration = newDuration
        customMinutes = minutes
        UserDefaults.standard.set(newDuration.rawValue, forKey: "awakeDuration")
        UserDefaults.standard.set(minutes, forKey: "customMinutes")
        return true
    }

    func reconcile() {
        guard isEnabled, let remaining = remainingSeconds else { return }
        if remaining <= 0 { releaseAssertion() }
        else if expiryTimer?.isValid != true { scheduleExpiry(after: remaining) }
    }

    func shutdown() {
        releaseAssertion()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
    }

    @discardableResult
    private func replaceAssertion(duration selected: AwakeDuration, minutes: Int) -> Bool {
        let timeout = selected == .custom ? Double(minutes * 60) : Double(selected.rawValue * 60)
        var newID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithDescription(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            "Tomales: keep display awake" as CFString,
            "User enabled Keep display awake" as CFString,
            "Keep display awake" as CFString,
            nil, max(0, timeout), kIOPMAssertionTimeoutActionTurnOff as CFString, &newID
        )
        guard result == kIOReturnSuccess else {
            errorMessage = "Could not keep the display awake (\(result))."
            return false
        }
        if let oldID = assertionID {
            let release = IOPMAssertionRelease(oldID)
            guard release == kIOReturnSuccess else {
                IOPMAssertionRelease(newID)
                errorMessage = "Could not replace the current awake session (\(release))."
                return false
            }
        }
        assertionID = newID
        continuousDeadline = timeout > 0 ? tm_continuous_seconds() + timeout : nil
        isEnabled = true
        errorMessage = nil
        if timeout > 0 { scheduleExpiry(after: timeout) }
        else { expiryTimer?.invalidate(); expiryTimer = nil }
        return true
    }

    private func releaseAssertion() {
        if let id = assertionID {
            let result = IOPMAssertionRelease(id)
            guard result == kIOReturnSuccess else {
                errorMessage = "Could not end the awake session (\(result)). Try again or quit Tomales."
                return
            }
        }
        expiryTimer?.invalidate()
        expiryTimer = nil
        assertionID = nil
        continuousDeadline = nil
        isEnabled = false
        errorMessage = nil
    }

    private func scheduleExpiry(after seconds: Double) {
        expiryTimer?.invalidate()
        let timer = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.reconcile() }
        }
        timer.tolerance = min(1, seconds * 0.01)
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }
}
