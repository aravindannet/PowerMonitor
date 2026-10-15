import SwiftUI
import AppKit

/// The menu bar item: total watts and a stacked power-breakdown bar, with the popup on click.
/// Drawn with AppKit rather than MenuBarExtra so the system doesn't highlight it while open.
@MainActor final class StatusItemController: NSObject {
    private let model: MacmonModel
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var timer: Timer?
    private var dismissMonitors: [Any] = []

    init(model: MacmonModel) {
        self.model = model
        super.init()

        guard let button = item.button else { return }
        (button.cell as? NSButtonCell)?.highlightsBy = []   // no grey box while the popup is open
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePopover)

        let hosting = NSHostingController(rootView: MenuBarView(model: model))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.delegate = self

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// Redraws the item from the latest reading. The bar is drawn to an image, which the menu bar shows.
    private func refresh() {
        let snapshot = PowerSnapshot(total: model.totalW, cpu: model.cpuW, gpu: model.gpuW,
                                     ane: model.aneW, ram: model.ramW, other: model.otherW)
        let renderer = ImageRenderer(content: PowerBreakdownBar(snapshot: snapshot))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return }
        image.isTemplate = false
        item.length = image.size.width
        item.button?.image = image
    }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Activate first, so clicking anywhere else dismisses the popup.
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startDismissMonitors()
        }
    }

    /// Closes the popup on a click anywhere outside it and outside the status item.
    /// The transient behaviour alone doesn't catch clicks in other apps reliably.
    private func startDismissMonitors() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let button = self.item.button, let window = button.window else { return }
                let buttonRect = window.convertToScreen(button.convert(button.bounds, to: nil))
                if !buttonRect.contains(NSEvent.mouseLocation) { self.popover.performClose(nil) }
            }
        }) {
            dismissMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                let popoverWindow = self.popover.contentViewController?.view.window
                if event.window !== popoverWindow && event.window !== self.item.button?.window {
                    self.popover.performClose(nil)
                }
            }
            return event
        }) {
            dismissMonitors.append(local)
        }
    }

    private func stopDismissMonitors() {
        dismissMonitors.forEach { NSEvent.removeMonitor($0) }
        dismissMonitors.removeAll()
    }
}

extension StatusItemController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        stopDismissMonitors()
    }
}
