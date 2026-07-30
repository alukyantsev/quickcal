import AppKit
import Foundation
import SwiftUI
import Testing
@testable import QuickCal
import QuickCalKit

@Suite(.serialized)
@MainActor
struct ThemeRenderingTests {
    @Test(arguments: QuickCalTheme.allCases)
    func everyThemeRendersAsANonEmptyPopover(theme: QuickCalTheme) throws {
        let suiteName = "QuickCalTests.ThemeRendering.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(
            theme.rawValue,
            forKey: QuickCalThemeStore.defaultKey
        )
        let store = QuickCalThemeStore(userDefaults: defaults)
        let view = CalendarPopoverView(
            themeStore: store,
            onThemeChanged: { _ in }
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        let image = try #require(renderer.nsImage)

        #expect(image.size.width >= 328)
        #expect(image.size.height >= 360)

        if let outputDirectory = ProcessInfo.processInfo.environment[
            "QUICKCAL_SNAPSHOT_DIR"
        ] {
            try save(
                image,
                to: URL(fileURLWithPath: outputDirectory)
                    .appendingPathComponent(snapshotName(for: theme))
            )
        }
    }

    private func snapshotName(for theme: QuickCalTheme) -> String {
        switch theme {
        case .systemLight:
            "quickcal-six-themes-system-light.png"
        case .systemDark:
            "quickcal-six-themes-system-dark.png"
        case .swissLight:
            "quickcal-six-themes-swiss-light.png"
        case .swissDark:
            "quickcal-six-themes-swiss-dark.png"
        case .colorLight:
            "quickcal-six-themes-color-light.png"
        case .colorDark:
            "quickcal-six-themes-color-dark.png"
        }
    }

    private func save(_ image: NSImage, to url: URL) throws {
        let data = try #require(image.tiffRepresentation)
        let representation = try #require(NSBitmapImageRep(data: data))
        let pngData = try #require(
            representation.representation(
                using: .png,
                properties: [:]
            )
        )

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try pngData.write(to: url, options: .atomic)
    }
}
