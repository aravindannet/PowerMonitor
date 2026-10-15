import SwiftUI
import AppKit

/// Shows and hides the main window together with the Dock icon.
/// With no window open the app runs as a menu bar item only.
@MainActor enum AppController {
    /// Set by AppDelegate on launch. NSApp.delegate isn't reliable under SwiftUI's app lifecycle.
    static weak var delegate: AppDelegate?

    static func showMainWindow() {
        delegate?.showMainWindow()
    }

    static func hideMainWindow() {
        delegate?.hideMainWindow()
    }

    /// Drops the Dock icon once no main window is left open, however it was closed.
    static func updateDockIcon() {
        let windowOpen = NSApp.windows.contains { $0.canBecomeMain && $0.isVisible }
        NSApp.setActivationPolicy(windowOpen ? .regular : .accessory)
    }
}

/// Owns the power data, the menu bar item and the main window.
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = MacmonModel()
    private var statusItem: StatusItemController?
    private var mainWindow: NSWindow?

    override init() {
        super.init()
        AppController.delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        statusItem = StatusItemController(model: model)

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            // The window is still listed while it closes, so check on the next turn of the run loop.
            DispatchQueue.main.async { AppController.updateDockIcon() }
        }

        // Launched by the login item: start in the menu bar without opening the window.
        let launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: 0x6C676974) != nil   // 'lgit' keyAELaunchedAsLogInItem
        if launchedAtLogin {
            NSApp.setActivationPolicy(.accessory)
        } else {
            showMainWindow()
        }
    }

    /// Keeps the app running after its window closes, so the menu bar item stays available.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Clicking the app again (from the Dock or Finder) brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 1120),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "PowerMonitor"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: ContentView(model: model))
            window.center()
            mainWindow = window
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideMainWindow() {
        mainWindow?.close()
        NSApp.setActivationPolicy(.accessory)
    }
}

@main struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The main window and the menu bar item are managed by AppDelegate.
        Settings { EmptyView() }
    }
}
