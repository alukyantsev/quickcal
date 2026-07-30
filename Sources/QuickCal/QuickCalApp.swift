import AppKit
import SwiftUI
import QuickCalKit

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
enum PopoverAppearanceSynchronizer {
    static func apply(
        _ appearance: NSAppearance,
        to popover: NSPopover
    ) {
        popover.appearance = appearance
    }

    static func apply(
        theme: QuickCalTheme,
        to popover: NSPopover
    ) {
        let name: NSAppearance.Name = theme.isDark
            ? .darkAqua
            : .aqua
        guard let appearance = NSAppearance(named: name) else {
            return
        }
        apply(appearance, to: popover)
    }

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

@MainActor
final class QuickCalAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let themeStore = QuickCalThemeStore()

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
            systemSymbolName: "calendar.badge.clock",
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
            rootView: CalendarPopoverView(
                themeStore: themeStore,
                onThemeChanged: { [weak self] theme in
                    guard let self else {
                        return
                    }
                    PopoverAppearanceSynchronizer.apply(
                        theme: theme,
                        to: self.popover
                    )
                }
            )
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
            let application = NSApplication.shared
            let systemAppearance = application.effectiveAppearance
            let theme = themeStore.resolvedTheme(
                systemIsDark: PopoverAppearanceSynchronizer.isDark(
                    systemAppearance
                )
            )
            PopoverAppearanceSynchronizer.apply(
                theme: theme,
                to: popover
            )
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
            application.activate()
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
