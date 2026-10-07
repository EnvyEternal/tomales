import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem?
    private lazy var panel = FloatingPanel(model: model)
    private var awakeSubscription: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private var iconEnabled = false
    private var pendingOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let identifier = Bundle.main.bundleIdentifier,
           NSWorkspace.shared.runningApplications.contains(where: {
               $0.bundleIdentifier == identifier && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
           }) {
            NSApplication.shared.terminate(nil)
            return
        }
        NSApplication.shared.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        item.button?.sendAction(on: .leftMouseDown)
        panel.onDismiss = { [weak self] in
            self?.statusItem?.button?.layer?.removeAnimation(forKey: "tomales-toggle")
            self?.model.hidePanel()
        }
        updateIcon(enabled: false)
        awakeSubscription = model.awake.$isEnabled.sink { [weak self] enabled in
            self?.updateIcon(enabled: enabled)
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) {
            [weak self] _ in Task { @MainActor in self?.model.pauseMonitoring() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) {
            [weak self] _ in Task { @MainActor in self?.model.resumeMonitoring() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) {
            [weak self] _ in Task { @MainActor in self?.panel.dismiss() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) {
            [weak self] _ in Task { @MainActor in self?.panel.dismiss() }
        })
        if pendingOpen { togglePanel(); pendingOpen = false }
    }

    @objc private func togglePanel() {
        guard let button = statusItem?.button else { return }
        if panel.isPresented { panel.dismiss() }
        else {
            model.showPanel()
            let animated = model.preferences.configuration.animations && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            if !panel.present(below: button, animated: animated) { model.hidePanel() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !panel.isPresented { togglePanel() }
        return false
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        if statusItem == nil { pendingOpen = true }
        else if !panel.isPresented { togglePanel() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        panel.dismiss()
        model.shutdown()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    private func updateIcon(enabled: Bool) {
        guard let button = statusItem?.button else { return }
        button.image = enabled ? MenuBarArtwork.awake : MenuBarArtwork.idle
        button.toolTip = enabled ? "Tomales — display stays awake" : "Tomales"
        button.setAccessibilityLabel(enabled ? "Tomales, keep display awake on" : "Tomales, keep display awake off")
        if iconEnabled != enabled && model.isPanelVisible && model.preferences.configuration.animations &&
            !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            button.wantsLayer = true
            let animation = CAKeyframeAnimation(keyPath: "transform.scale")
            animation.values = [1, 0.86, 1.08, 1]
            animation.keyTimes = [0, 0.25, 0.65, 1]
            animation.duration = 0.35
            button.layer?.add(animation, forKey: "tomales-toggle")
        }
        iconEnabled = enabled
    }
}

@main
enum TomalesApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
