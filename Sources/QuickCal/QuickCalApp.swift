import AppKit
import SwiftUI

@main
struct QuickCalApp: App {
    @NSApplicationDelegateAdaptor(QuickCalAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class QuickCalAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        guard let button = item.button else {
            NSApplication.shared.terminate(nil)
            return
        }

        let symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 18,
            weight: .medium
        )
        let image = NSImage(
            systemSymbolName: "calendar",
            accessibilityDescription: "QuickCal"
        )?.withSymbolConfiguration(symbolConfiguration)
        image?.isTemplate = true

        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.target = self
        button.action = #selector(togglePopover)
        button.setAccessibilityLabel("QuickCal")

        let contentController = NSHostingController(
            rootView: CalendarPopoverView()
        )
        contentController.sizingOptions = [.preferredContentSize]

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = contentController
        statusItem = item
    }

    @objc
    private func togglePopover() {
        guard let button = statusItem?.button else {
            return
        }

        if popover.isShown {
            popover.performClose(button)
        } else {
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
