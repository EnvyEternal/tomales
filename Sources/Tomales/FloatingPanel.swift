import AppKit
import SwiftUI

@MainActor
final class FloatingPanel: NSPanel {
    var onDismiss: (() -> Void)?
    private(set) var isPresented = false
    private var anchor = NSRect.zero
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var observers: [NSObjectProtocol] = []

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(model: AppModel) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 380, height: 650),
                   styleMask: .borderless, backing: .buffered, defer: false)
        title = "Tomales"
        isReleasedWhenClosed = false
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        animationBehavior = .none
        contentViewController = NSHostingController(rootView: PanelView(model: model))
    }

    @discardableResult
    func present(below button: NSStatusBarButton, animated: Bool) -> Bool {
        guard let window = button.window, let screen = window.screen else { return false }
        anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let bounds = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let size = NSSize(width: min(380, bounds.width), height: min(650, bounds.height))
        let x = min(max(anchor.midX - size.width / 2, bounds.minX), bounds.maxX - size.width)
        let top = min(anchor.minY - 8, bounds.maxY)
        let y = max(bounds.minY, top - size.height)
        setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
        alphaValue = animated ? 0 : 1
        NSApplication.shared.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        isPresented = true
        installDismissalHandlers()
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                animator().alphaValue = 1
            }
        }
        return true
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        removeDismissalHandlers()
        orderOut(nil)
        alphaValue = 1
        onDismiss?()
    }

    override func cancelOperation(_ sender: Any?) { dismiss() }

    private func installDismissalHandlers() {
        removeDismissalHandlers()
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.anchor.contains(NSEvent.mouseLocation) else { return }
                self.dismiss()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                let point = NSEvent.mouseLocation
                if self.frame.contains(point) || self.anchor.contains(point) { return }
                if let window = event.window, window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue { return }
                self.dismiss()
            }
            return event
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didResignActiveNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // The status button owns its mouse-down toggle.
                if NSEvent.pressedMouseButtons & 1 != 0 && self.anchor.contains(NSEvent.mouseLocation) { return }
                self.dismiss()
            }
        })
        for name in [NSApplication.didHideNotification, NSApplication.didChangeScreenParametersNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.dismiss() }
            })
        }
    }

    private func removeDismissalHandlers() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}

struct PanelBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
