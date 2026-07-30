import SwiftUI
import QuickCalKit

struct QuickCalThemeStyle {
    let theme: QuickCalTheme
    let primaryText: Color
    let secondaryText: Color
    let dividerColor: Color
    let weekendColor: Color
    let todayColor: Color
    let todayText: Color
    let selectionColor: Color
    let selectedText: Color
    let panelColor: Color
    let panelBorderColor: Color
    let hoverColor: Color
    let headerBackground: Color
    let headerBorderColor: Color
    let shellPadding: CGFloat
    let calendarPadding: CGFloat
    let outerCornerRadius: CGFloat
    let panelCornerRadius: CGFloat
    let controlCornerRadius: CGFloat
    let dayCornerRadius: CGFloat
    let usesUppercaseHeaders: Bool
    let usesHeaderPill: Bool
    let showsSwissStripe: Bool

    init(theme: QuickCalTheme) {
        self.theme = theme

        switch theme {
        case .systemLight:
            primaryText = Color(rgb: 0x151821)
            secondaryText = Color(rgb: 0x707887)
            dividerColor = Color(rgb: 0x31394C, opacity: 0.10)
            weekendColor = Color(rgb: 0xDF5964)
            todayColor = Color(rgb: 0x247BF2)
            todayText = .white
            selectionColor = Color(rgb: 0x48A66F)
            selectedText = .white
            panelColor = .white.opacity(0.36)
            panelBorderColor = .white.opacity(0.70)
            hoverColor = .black.opacity(0.055)
            headerBackground = .clear
            headerBorderColor = .clear
            shellPadding = 17
            calendarPadding = 12
            outerCornerRadius = 24
            panelCornerRadius = 18
            controlCornerRadius = 8
            dayCornerRadius = 16
            usesUppercaseHeaders = false
            usesHeaderPill = false
            showsSwissStripe = false

        case .systemDark:
            primaryText = Color(rgb: 0xF4F7FA)
            secondaryText = Color(rgb: 0x808995)
            dividerColor = Color(rgb: 0x2A3039)
            weekendColor = Color(rgb: 0xFF7079)
            todayColor = Color(rgb: 0x628CFF)
            todayText = .white
            selectionColor = Color(rgb: 0x258E6B)
            selectedText = .white
            panelColor = Color(rgb: 0x1B2027)
            panelBorderColor = Color(rgb: 0x2A3039)
            hoverColor = .white.opacity(0.065)
            headerBackground = .clear
            headerBorderColor = .clear
            shellPadding = 17
            calendarPadding = 12
            outerCornerRadius = 24
            panelCornerRadius = 18
            controlCornerRadius = 8
            dayCornerRadius = 16
            usesUppercaseHeaders = false
            usesHeaderPill = false
            showsSwissStripe = false

        case .swissLight:
            primaryText = Color(rgb: 0x20201F)
            secondaryText = Color(rgb: 0x777672)
            dividerColor = Color(rgb: 0x20201F, opacity: 0.18)
            weekendColor = Color(rgb: 0xD75555)
            todayColor = Color(rgb: 0x30312F)
            todayText = .white
            selectionColor = Color(rgb: 0x83996F)
            selectedText = .white
            panelColor = .clear
            panelBorderColor = .clear
            hoverColor = Color(rgb: 0x1C1C1B, opacity: 0.05)
            headerBackground = .clear
            headerBorderColor = .clear
            shellPadding = 19
            calendarPadding = 0
            outerCornerRadius = 10
            panelCornerRadius = 0
            controlCornerRadius = 5
            dayCornerRadius = 5
            usesUppercaseHeaders = true
            usesHeaderPill = false
            showsSwissStripe = true

        case .swissDark:
            primaryText = Color(rgb: 0xF0EFE9)
            secondaryText = Color(rgb: 0x898A83)
            dividerColor = Color.white.opacity(0.16)
            weekendColor = Color(rgb: 0xEF7770)
            todayColor = Color(rgb: 0xF0EFE9)
            todayText = Color(rgb: 0x191A17)
            selectionColor = Color(rgb: 0x748C65)
            selectedText = .white
            panelColor = .clear
            panelBorderColor = .clear
            hoverColor = .white.opacity(0.055)
            headerBackground = .clear
            headerBorderColor = .clear
            shellPadding = 19
            calendarPadding = 0
            outerCornerRadius = 10
            panelCornerRadius = 0
            controlCornerRadius = 5
            dayCornerRadius = 5
            usesUppercaseHeaders = true
            usesHeaderPill = false
            showsSwissStripe = true

        case .colorLight:
            primaryText = Color(rgb: 0x332B39)
            secondaryText = Color(rgb: 0x8D7F8E)
            dividerColor = Color(rgb: 0x533B54, opacity: 0.10)
            weekendColor = Color(rgb: 0xD45F70)
            todayColor = Color(rgb: 0x846FE3)
            todayText = .white
            selectionColor = Color(rgb: 0x58A892)
            selectedText = .white
            panelColor = Color(rgb: 0xFFFAF7)
            panelBorderColor = .clear
            hoverColor = Color(rgb: 0x634769, opacity: 0.06)
            headerBackground = Color(rgb: 0xEEE2FF)
            headerBorderColor = .clear
            shellPadding = 13
            calendarPadding = 12
            outerCornerRadius = 29
            panelCornerRadius = 20
            controlCornerRadius = 9
            dayCornerRadius = 16
            usesUppercaseHeaders = false
            usesHeaderPill = true
            showsSwissStripe = false

        case .colorDark:
            primaryText = .white
            secondaryText = .white.opacity(0.62)
            dividerColor = .white.opacity(0.15)
            weekendColor = Color(rgb: 0xFF9FBE)
            todayColor = Color(rgb: 0x73A8FF)
            todayText = .white
            selectionColor = Color(rgb: 0x48BCA5)
            selectedText = .white
            panelColor = .white.opacity(0.075)
            panelBorderColor = .white.opacity(0.16)
            hoverColor = .white.opacity(0.08)
            headerBackground = .white.opacity(0.075)
            headerBorderColor = .white.opacity(0.12)
            shellPadding = 13
            calendarPadding = 12
            outerCornerRadius = 29
            panelCornerRadius = 20
            controlCornerRadius = 9
            dayCornerRadius = 16
            usesUppercaseHeaders = false
            usesHeaderPill = true
            showsSwissStripe = false
        }
    }

    var colorScheme: ColorScheme {
        theme.isDark ? .dark : .light
    }
}

struct QuickCalThemeBackground: View {
    let theme: QuickCalTheme

    var body: some View {
        background
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var background: some View {
        switch theme {
        case .systemLight:
            LinearGradient(
                colors: [
                    Color(rgb: 0xF8FAFF),
                    Color(rgb: 0xE4E9F4),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .systemDark:
            Color(rgb: 0x15181D)

        case .swissLight:
            Color(rgb: 0xFBFAF6)

        case .swissDark:
            Color(rgb: 0x181916)

        case .colorLight:
            Color(rgb: 0xF8F1EC)

        case .colorDark:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(rgb: 0x22244F),
                        Color(rgb: 0x3C2256),
                        Color(rgb: 0x19243E),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color(rgb: 0x5BE0FF, opacity: 0.29),
                        .clear,
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 250
                )

                RadialGradient(
                    colors: [
                        Color(rgb: 0xFF72DC, opacity: 0.27),
                        .clear,
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 280
                )
            }
        }
    }
}

private struct QuickCalThemeStyleKey: EnvironmentKey {
    static let defaultValue = QuickCalThemeStyle(theme: .systemLight)
}

extension EnvironmentValues {
    var quickCalThemeStyle: QuickCalThemeStyle {
        get { self[QuickCalThemeStyleKey.self] }
        set { self[QuickCalThemeStyleKey.self] = newValue }
    }
}

private extension Color {
    init(rgb: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: opacity
        )
    }
}
