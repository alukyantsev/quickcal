import SwiftUI
import QuickCalKit

enum QuickCalLayoutStyle {
    case nativeToolbar
    case deadlineLedger
    case instrumentGrid
}

struct QuickCalThemeStyle {
    let theme: QuickCalTheme
    let layout: QuickCalLayoutStyle
    let primaryText: Color
    let secondaryText: Color
    let dividerColor: Color
    let weekendColor: Color
    let todayColor: Color
    let todayText: Color
    let selectionColor: Color
    let selectedText: Color
    let selectionOpacity: Double
    let panelColor: Color
    let panelBorderColor: Color
    let hoverColor: Color
    let shellPadding: CGFloat
    let calendarPadding: CGFloat
    let outerCornerRadius: CGFloat
    let panelCornerRadius: CGFloat
    let controlCornerRadius: CGFloat
    let dayCornerRadius: CGFloat
    let monthFontSize: CGFloat
    let monthFontWeight: Font.Weight
    let monthFontDesign: Font.Design
    let dayFontDesign: Font.Design
    let uppercaseMonth: Bool
    let usesWeekRules: Bool

    var calendarLabelFontDesign: Font.Design {
        layout == .instrumentGrid ? .default : dayFontDesign
    }

    var outOfMonthOpacity: Double {
        theme.isDark ? 0.62 : 0.56
    }

    var weekNumberOpacity: Double {
        theme.isDark ? 0.54 : 0.48
    }

    var sprintHighlightColor: Color {
        theme.isDark ? .white.opacity(0.08) : .black.opacity(0.055)
    }

    var headerRuleOpacity: Double {
        theme.family == .signalGrid ? 0.42 : 1
    }

    var rowRuleOpacity: Double {
        theme.family == .signalGrid ? 0.28 : 0.62
    }

    init(theme: QuickCalTheme) {
        self.theme = theme

        switch theme {
        case .systemLight:
            layout = .nativeToolbar
            primaryText = Color(rgb: 0x171A20)
            secondaryText = Color(rgb: 0x626B78)
            dividerColor = Color(rgb: 0x273142, opacity: 0.12)
            weekendColor = Color(rgb: 0xD84E57)
            todayColor = Color(rgb: 0x247BF2)
            todayText = .white
            selectionColor = Color(rgb: 0xDCEAFF)
            selectedText = Color(rgb: 0x171A20)
            selectionOpacity = 1
            panelColor = .white.opacity(0.40)
            panelBorderColor = .white.opacity(0.72)
            hoverColor = .black.opacity(0.055)
            shellPadding = 14
            calendarPadding = 11
            outerCornerRadius = 16
            panelCornerRadius = 12
            controlCornerRadius = 8
            dayCornerRadius = 16
            monthFontSize = 21
            monthFontWeight = .semibold
            monthFontDesign = .default
            dayFontDesign = .default
            uppercaseMonth = false
            usesWeekRules = false

        case .systemDark:
            layout = .nativeToolbar
            primaryText = Color(rgb: 0xF6F8FC)
            secondaryText = Color(rgb: 0xB7C0CB)
            dividerColor = Color.white.opacity(0.16)
            weekendColor = Color(rgb: 0xFF7D89)
            todayColor = Color(rgb: 0x5684DC)
            todayText = .white
            selectionColor = Color(rgb: 0x455E7C)
            selectedText = .white
            selectionOpacity = 1
            panelColor = Color(rgb: 0x303944)
            panelBorderColor = Color(rgb: 0x465361)
            hoverColor = .white.opacity(0.07)
            shellPadding = 14
            calendarPadding = 11
            outerCornerRadius = 16
            panelCornerRadius = 12
            controlCornerRadius = 8
            dayCornerRadius = 16
            monthFontSize = 21
            monthFontWeight = .semibold
            monthFontDesign = .default
            dayFontDesign = .default
            uppercaseMonth = false
            usesWeekRules = false

        case .swissLight:
            layout = .deadlineLedger
            primaryText = Color(rgb: 0x20201F)
            secondaryText = Color(rgb: 0x666762)
            dividerColor = Color(rgb: 0x20201F, opacity: 0.16)
            weekendColor = Color(rgb: 0xD75555)
            todayColor = Color(rgb: 0x30312F)
            todayText = .white
            selectionColor = Color(rgb: 0xC9D3BD)
            selectedText = Color(rgb: 0x20201F)
            selectionOpacity = 1
            panelColor = .clear
            panelBorderColor = .clear
            hoverColor = Color(rgb: 0x1C1C1B, opacity: 0.055)
            shellPadding = 16
            calendarPadding = 0
            outerCornerRadius = 10
            panelCornerRadius = 0
            controlCornerRadius = 5
            dayCornerRadius = 5
            monthFontSize = 23
            monthFontWeight = .bold
            monthFontDesign = .default
            dayFontDesign = .default
            uppercaseMonth = true
            usesWeekRules = true

        case .swissDark:
            layout = .deadlineLedger
            primaryText = Color(rgb: 0xF5EEE9)
            secondaryText = Color(rgb: 0xC5B4BB)
            dividerColor = Color(rgb: 0xF5EEE9, opacity: 0.18)
            weekendColor = Color(rgb: 0xFF8B7F)
            todayColor = Color(rgb: 0xF2E8E2)
            todayText = Color(rgb: 0x2A1E24)
            selectionColor = Color(rgb: 0x6F5362)
            selectedText = .white
            selectionOpacity = 1
            panelColor = .clear
            panelBorderColor = .clear
            hoverColor = .white.opacity(0.06)
            shellPadding = 16
            calendarPadding = 0
            outerCornerRadius = 10
            panelCornerRadius = 0
            controlCornerRadius = 5
            dayCornerRadius = 5
            monthFontSize = 23
            monthFontWeight = .bold
            monthFontDesign = .default
            dayFontDesign = .default
            uppercaseMonth = true
            usesWeekRules = true

        case .colorLight:
            layout = .nativeToolbar
            primaryText = Color(rgb: 0x30283B)
            secondaryText = Color(rgb: 0x796D82)
            dividerColor = Color(rgb: 0x513D61, opacity: 0.12)
            weekendColor = Color(rgb: 0xC84F63)
            todayColor = Color(rgb: 0x755FE0)
            todayText = .white
            selectionColor = Color(rgb: 0xCDE9E2)
            selectedText = Color(rgb: 0x273732)
            selectionOpacity = 1
            panelColor = Color(rgb: 0xFFFBFE, opacity: 0.72)
            panelBorderColor = Color(rgb: 0xFFFFFF, opacity: 0.78)
            hoverColor = Color(rgb: 0x634769, opacity: 0.07)
            shellPadding = 13
            calendarPadding = 11
            outerCornerRadius = 20
            panelCornerRadius = 14
            controlCornerRadius = 9
            dayCornerRadius = 15
            monthFontSize = 21
            monthFontWeight = .semibold
            monthFontDesign = .rounded
            dayFontDesign = .rounded
            uppercaseMonth = false
            usesWeekRules = false

        case .colorDark:
            layout = .nativeToolbar
            primaryText = Color(rgb: 0xFCF5FF)
            secondaryText = Color(rgb: 0xD9BFDF)
            dividerColor = .white.opacity(0.17)
            weekendColor = Color(rgb: 0xFF9AAC)
            todayColor = Color(rgb: 0xC184FF)
            todayText = Color(rgb: 0x251A35)
            selectionColor = Color(rgb: 0x317B70)
            selectedText = .white
            selectionOpacity = 1
            panelColor = .white.opacity(0.09)
            panelBorderColor = .white.opacity(0.18)
            hoverColor = .white.opacity(0.08)
            shellPadding = 13
            calendarPadding = 11
            outerCornerRadius = 20
            panelCornerRadius = 14
            controlCornerRadius = 9
            dayCornerRadius = 15
            monthFontSize = 21
            monthFontWeight = .semibold
            monthFontDesign = .rounded
            dayFontDesign = .rounded
            uppercaseMonth = false
            usesWeekRules = false

        case .ledgerLight:
            layout = .deadlineLedger
            primaryText = Color(rgb: 0x1D1E1B)
            secondaryText = Color(rgb: 0x67685F)
            dividerColor = Color(rgb: 0x6F6C60, opacity: 0.20)
            weekendColor = Color(rgb: 0xD64B40)
            todayColor = Color(rgb: 0x2458B3)
            todayText = .white
            selectionColor = Color(rgb: 0xBFD8C7)
            selectedText = Color(rgb: 0x1D1E1B)
            selectionOpacity = 0.92
            panelColor = .clear
            panelBorderColor = .clear
            hoverColor = Color(rgb: 0x1D1E1B, opacity: 0.055)
            shellPadding = 16
            calendarPadding = 0
            outerCornerRadius = 8
            panelCornerRadius = 0
            controlCornerRadius = 5
            dayCornerRadius = 6
            monthFontSize = 23
            monthFontWeight = .bold
            monthFontDesign = .serif
            dayFontDesign = .serif
            uppercaseMonth = true
            usesWeekRules = true

        case .ledgerDark:
            layout = .deadlineLedger
            primaryText = Color(rgb: 0xF2E9DA)
            secondaryText = Color(rgb: 0xC9B9A5)
            dividerColor = Color(rgb: 0xF2E9DA, opacity: 0.18)
            weekendColor = Color(rgb: 0xFF8A70)
            todayColor = Color(rgb: 0x8DB7FF)
            todayText = Color(rgb: 0x2B2119)
            selectionColor = Color(rgb: 0x53775F)
            selectedText = .white
            selectionOpacity = 1
            panelColor = .clear
            panelBorderColor = .clear
            hoverColor = .white.opacity(0.06)
            shellPadding = 16
            calendarPadding = 0
            outerCornerRadius = 8
            panelCornerRadius = 0
            controlCornerRadius = 5
            dayCornerRadius = 6
            monthFontSize = 23
            monthFontWeight = .bold
            monthFontDesign = .serif
            dayFontDesign = .serif
            uppercaseMonth = true
            usesWeekRules = true

        case .prismLight:
            layout = .nativeToolbar
            primaryText = Color(rgb: 0x13252C)
            secondaryText = Color(rgb: 0x5E747B)
            dividerColor = Color(rgb: 0x2E6875, opacity: 0.16)
            weekendColor = Color(rgb: 0xD85661)
            todayColor = Color(rgb: 0x2D7E95)
            todayText = .white
            selectionColor = Color(rgb: 0xDCE3FF)
            selectedText = Color(rgb: 0x1B2741)
            selectionOpacity = 0.95
            panelColor = .white.opacity(0.58)
            panelBorderColor = .white.opacity(0.84)
            hoverColor = Color(rgb: 0x5B67F1, opacity: 0.08)
            shellPadding = 13
            calendarPadding = 11
            outerCornerRadius = 18
            panelCornerRadius = 13
            controlCornerRadius = 8
            dayCornerRadius = 14
            monthFontSize = 21
            monthFontWeight = .semibold
            monthFontDesign = .default
            dayFontDesign = .default
            uppercaseMonth = false
            usesWeekRules = false

        case .prismDark:
            layout = .nativeToolbar
            primaryText = Color(rgb: 0xF4F7FF)
            secondaryText = Color(rgb: 0xB8D3D9)
            dividerColor = Color(rgb: 0x79C7D4, opacity: 0.20)
            weekendColor = Color(rgb: 0xFF8291)
            todayColor = Color(rgb: 0x63D6E3)
            todayText = Color(rgb: 0x102B32)
            selectionColor = Color(rgb: 0x5368A8)
            selectedText = .white
            selectionOpacity = 1
            panelColor = Color(rgb: 0x143C4C, opacity: 0.90)
            panelBorderColor = Color(rgb: 0x3C7886, opacity: 0.52)
            hoverColor = Color(rgb: 0x55E2E8, opacity: 0.10)
            shellPadding = 13
            calendarPadding = 11
            outerCornerRadius = 18
            panelCornerRadius = 13
            controlCornerRadius = 8
            dayCornerRadius = 14
            monthFontSize = 21
            monthFontWeight = .semibold
            monthFontDesign = .default
            dayFontDesign = .default
            uppercaseMonth = false
            usesWeekRules = false

        case .signalGridLight:
            layout = .instrumentGrid
            primaryText = Color(rgb: 0x111512)
            secondaryText = Color(rgb: 0x5F6A62)
            dividerColor = Color(rgb: 0xCDD3CC)
            weekendColor = Color(rgb: 0xD94F4B)
            todayColor = Color(rgb: 0xA4D936)
            todayText = Color(rgb: 0x111512)
            selectionColor = Color(rgb: 0x1EA7B7)
            selectedText = .white
            selectionOpacity = 0.88
            panelColor = Color(rgb: 0xFFFFFF, opacity: 0.40)
            panelBorderColor = Color(rgb: 0x9FAAA1, opacity: 0.45)
            hoverColor = Color(rgb: 0x1EA7B7, opacity: 0.09)
            shellPadding = 11
            calendarPadding = 10
            outerCornerRadius = 12
            panelCornerRadius = 9
            controlCornerRadius = 7
            dayCornerRadius = 7
            monthFontSize = 21
            monthFontWeight = .bold
            monthFontDesign = .default
            dayFontDesign = .monospaced
            uppercaseMonth = true
            usesWeekRules = true

        case .signalGridDark:
            layout = .instrumentGrid
            primaryText = Color(rgb: 0xF0F7F2)
            secondaryText = Color(rgb: 0xB6CABC)
            dividerColor = Color(rgb: 0x396657)
            weekendColor = Color(rgb: 0xFF8377)
            todayColor = Color(rgb: 0xCEFF63)
            todayText = Color(rgb: 0x102B24)
            selectionColor = Color(rgb: 0x187783)
            selectedText = .white
            selectionOpacity = 0.90
            panelColor = Color(rgb: 0x17382F)
            panelBorderColor = Color(rgb: 0x396657)
            hoverColor = Color(rgb: 0x31C0CE, opacity: 0.11)
            shellPadding = 11
            calendarPadding = 10
            outerCornerRadius = 12
            panelCornerRadius = 9
            controlCornerRadius = 7
            dayCornerRadius = 7
            monthFontSize = 21
            monthFontWeight = .bold
            monthFontDesign = .default
            dayFontDesign = .monospaced
            uppercaseMonth = true
            usesWeekRules = true

        case .titaniumChronoLight:
            layout = .instrumentGrid
            primaryText = Color(rgb: 0x202522)
            secondaryText = Color(rgb: 0x656D68)
            dividerColor = Color(rgb: 0xBFC4BE)
            weekendColor = Color(rgb: 0xD95338)
            todayColor = Color(rgb: 0xF05A3C)
            todayText = .white
            selectionColor = Color(rgb: 0x2D8F88)
            selectedText = .white
            selectionOpacity = 0.86
            panelColor = Color(rgb: 0xF8F8F3, opacity: 0.65)
            panelBorderColor = Color(rgb: 0xAEB4AE, opacity: 0.70)
            hoverColor = Color(rgb: 0x2D8F88, opacity: 0.09)
            shellPadding = 11
            calendarPadding = 10
            outerCornerRadius = 10
            panelCornerRadius = 8
            controlCornerRadius = 6
            dayCornerRadius = 7
            monthFontSize = 21
            monthFontWeight = .bold
            monthFontDesign = .default
            dayFontDesign = .monospaced
            uppercaseMonth = true
            usesWeekRules = true

        case .titaniumChronoDark:
            layout = .instrumentGrid
            primaryText = Color(rgb: 0xF2F5F6)
            secondaryText = Color(rgb: 0xBDC8CC)
            dividerColor = Color(rgb: 0x4B606B)
            weekendColor = Color(rgb: 0xFF8164)
            todayColor = Color(rgb: 0xFF8066)
            todayText = Color(rgb: 0x1E2A32)
            selectionColor = Color(rgb: 0x397C7F)
            selectedText = .white
            selectionOpacity = 0.92
            panelColor = Color(rgb: 0x2B3A43)
            panelBorderColor = Color(rgb: 0x4B606B)
            hoverColor = Color(rgb: 0x49AAA1, opacity: 0.11)
            shellPadding = 11
            calendarPadding = 10
            outerCornerRadius = 10
            panelCornerRadius = 8
            controlCornerRadius = 6
            dayCornerRadius = 7
            monthFontSize = 21
            monthFontWeight = .bold
            monthFontDesign = .default
            dayFontDesign = .monospaced
            uppercaseMonth = true
            usesWeekRules = true

        case .monochromeLight:
            layout = .deadlineLedger
            primaryText = Color(rgb: 0x111211)
            secondaryText = Color(rgb: 0x676A67)
            dividerColor = Color(rgb: 0xD8DAD7)
            weekendColor = Color(rgb: 0xA23D3D)
            todayColor = Color(rgb: 0x111211)
            todayText = .white
            selectionColor = Color(rgb: 0xD9E2FF)
            selectedText = Color(rgb: 0x111211)
            selectionOpacity = 1
            panelColor = .clear
            panelBorderColor = .clear
            hoverColor = .black.opacity(0.05)
            shellPadding = 15
            calendarPadding = 0
            outerCornerRadius = 8
            panelCornerRadius = 0
            controlCornerRadius = 6
            dayCornerRadius = 6
            monthFontSize = 21
            monthFontWeight = .semibold
            monthFontDesign = .default
            dayFontDesign = .default
            uppercaseMonth = false
            usesWeekRules = true

        case .monochromeDark:
            layout = .deadlineLedger
            primaryText = Color(rgb: 0xF6F4FA)
            secondaryText = Color(rgb: 0xC2BDC9)
            dividerColor = Color(rgb: 0x4C4858)
            weekendColor = Color(rgb: 0xF39389)
            todayColor = Color(rgb: 0xF6F4FA)
            todayText = Color(rgb: 0x292632)
            selectionColor = Color(rgb: 0x4B5F91)
            selectedText = .white
            selectionOpacity = 1
            panelColor = .clear
            panelBorderColor = .clear
            hoverColor = .white.opacity(0.06)
            shellPadding = 15
            calendarPadding = 0
            outerCornerRadius = 8
            panelCornerRadius = 0
            controlCornerRadius = 6
            dayCornerRadius = 6
            monthFontSize = 21
            monthFontWeight = .semibold
            monthFontDesign = .default
            dayFontDesign = .default
            uppercaseMonth = false
            usesWeekRules = true
        }
    }

    var colorScheme: ColorScheme {
        theme.isDark ? .dark : .light
    }
}

struct QuickCalThemeBackground: View {
    let theme: QuickCalTheme

    var body: some View {
        background.ignoresSafeArea()
    }

    @ViewBuilder
    private var background: some View {
        switch theme {
        case .systemLight:
            LinearGradient(
                colors: [Color(rgb: 0xF4F5F7), Color(rgb: 0xE3E7EC)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .systemDark:
            LinearGradient(
                colors: [Color(rgb: 0x2A3038), Color(rgb: 0x222831)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .swissLight:
            Color(rgb: 0xFBFAF6)
        case .swissDark:
            Color(rgb: 0x2A1E24)
        case .colorLight:
            LinearGradient(
                colors: [Color(rgb: 0xFBF0FF), Color(rgb: 0xEEE1F8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .colorDark:
            LinearGradient(
                colors: [Color(rgb: 0x4B234C), Color(rgb: 0x2A2B59)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .ledgerLight:
            Color(rgb: 0xF2EFE6)
        case .ledgerDark:
            Color(rgb: 0x2B2119)
        case .prismLight:
            LinearGradient(
                colors: [Color(rgb: 0xF1FAFA), Color(rgb: 0xDFF2F5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .prismDark:
            LinearGradient(
                colors: [Color(rgb: 0x103945), Color(rgb: 0x18365D)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .signalGridLight:
            Color(rgb: 0xF3F5F1)
        case .signalGridDark:
            Color(rgb: 0x102B24)
        case .titaniumChronoLight:
            LinearGradient(
                colors: [Color(rgb: 0xF1F1EC), Color(rgb: 0xD9DAD5)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .titaniumChronoDark:
            LinearGradient(
                colors: [Color(rgb: 0x2B3942), Color(rgb: 0x1F2C34)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .monochromeLight:
            Color(rgb: 0xFAFAF8)
        case .monochromeDark:
            Color(rgb: 0x292632)
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

extension Color {
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
