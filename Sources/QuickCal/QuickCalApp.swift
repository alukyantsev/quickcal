import AppKit
import Combine
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
    private let menuBarInformationSettings = MenuBarInformationSettingsStore()
    private let weatherController = WeatherController(
        provider: try! OpenMeteoWeatherClient(),
        locationService: CoreLocationWeatherService()
    )
    private let quoteController = QuoteController(
        provider: try! MOEXISSMarketQuoteProvider()
    )
    private lazy var refreshCoordinator = ForegroundRefreshCoordinator(
        weatherController: weatherController,
        quoteController: quoteController
    )
    private var menuBarCancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        let item = NSStatusBar.system.statusItem(
            withLength: MenuBarStatusItemRenderer.preferredLength
        )
        guard let button = item.button else {
            NSApplication.shared.terminate(nil)
            return
        }

        button.target = self
        button.action = #selector(togglePopover)
        MenuBarStatusItemRenderer.apply(
            presentation: currentMenuBarPresentation,
            to: button
        )

        let contentController = NSHostingController(
            rootView: CalendarPopoverView(
                themeStore: themeStore,
                weatherController: weatherController,
                quoteController: quoteController,
                menuBarInformationSettings: menuBarInformationSettings,
                refreshCoordinator: refreshCoordinator,
                onRefresh: { [weak self] in self?.refreshCoordinator.refresh() },
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
        observeMenuBarPresentation()

        // Refresh starts with the menu bar app, not when the popover opens.
        // In manual mode this never asks macOS for location permission.
        refreshCoordinator.start()
        refreshCoordinator.refresh()
    }

    func applicationWillTerminate(
        _ notification: Notification
    ) {
        menuBarCancellables.removeAll()
        refreshCoordinator.stop()
    }

    private var currentMenuBarPresentation: MenuBarInformationPresentation {
        MenuBarInformationPresentation.make(
            isEnabled: menuBarInformationSettings.isEnabled,
            weatherIsVisible: weatherController.settings.isVisible,
            weatherState: weatherController.state,
            quoteIsVisible: quoteController.settings.isVisible,
            quoteState: quoteController.state
        )
    }

    private func observeMenuBarPresentation() {
        weatherController.$state
            .combineLatest(
                weatherController.$settings,
                quoteController.$state,
                quoteController.$settings
            )
            .combineLatest(menuBarInformationSettings.$isEnabled)
            .sink { [weak self] states, isEnabled in
                self?.updateMenuBarPresentation(
                    isEnabled: isEnabled,
                    weatherIsVisible: states.1.isVisible,
                    weatherState: states.0,
                    quoteIsVisible: states.3.isVisible,
                    quoteState: states.2
                )
            }
            .store(in: &menuBarCancellables)
    }

    private func updateMenuBarPresentation(
        isEnabled: Bool,
        weatherIsVisible: Bool,
        weatherState: WeatherPresentationState,
        quoteIsVisible: Bool,
        quoteState: QuotePresentationState
    ) {
        guard let button = statusItem?.button else { return }
        MenuBarStatusItemRenderer.apply(
            presentation: MenuBarInformationPresentation.make(
                isEnabled: isEnabled,
                weatherIsVisible: weatherIsVisible,
                weatherState: weatherState,
                quoteIsVisible: quoteIsVisible,
                quoteState: quoteState
            ),
            to: button
        )
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
                relativeTo: MenuBarPopoverLayout.positioningRect(
                    in: button.bounds
                ),
                of: button,
                preferredEdge: .minY
            )
            application.activate()
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
