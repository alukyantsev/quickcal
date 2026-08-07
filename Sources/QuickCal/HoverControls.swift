import SwiftUI

struct HoverIconButton: View {
    let title: String
    let systemImage: String
    let symbolSize: CGFloat
    let controlSize: CGFloat
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.quickCalThemeStyle) private var themeStyle
    @State private var isHovered = false

    init(
        title: String,
        systemImage: String,
        symbolSize: CGFloat = 17,
        controlSize: CGFloat = 32,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.symbolSize = symbolSize
        self.controlSize = controlSize
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: symbolSize, weight: .semibold))
                .frame(width: controlSize, height: controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(themeStyle.secondaryText)
        .background {
            RoundedRectangle(
                cornerRadius: themeStyle.controlCornerRadius,
                style: .continuous
            )
            .fill(isHovered ? themeStyle.hoverColor : .clear)
        }
        .onHover { isHovered = $0 }
        .animation(
            .easeOut(duration: reduceMotion ? 0 : 0.12),
            value: isHovered
        )
        .help(Text(verbatim: title))
        .accessibilityLabel(Text(verbatim: title))
    }
}

struct HoverSurface<Content: View>: View {
    private let content: Content
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.quickCalThemeStyle) private var themeStyle
    @State private var isHovered = false

    init(
        horizontalPadding: CGFloat = 6,
        verticalPadding: CGFloat = 5,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(
                    cornerRadius: themeStyle.controlCornerRadius,
                    style: .continuous
                )
                .fill(isHovered ? themeStyle.hoverColor : .clear)
            }
            .onHover { isHovered = $0 }
            .animation(
                .easeOut(duration: reduceMotion ? 0 : 0.12),
                value: isHovered
            )
    }
}

struct HoverActionButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.quickCalThemeStyle) private var themeStyle
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(themeStyle.secondaryText)
        .background {
            RoundedRectangle(
                cornerRadius: themeStyle.controlCornerRadius,
                style: .continuous
            )
            .fill(isHovered ? themeStyle.hoverColor : .clear)
        }
        .onHover { isHovered = $0 }
        .animation(
            .easeOut(duration: reduceMotion ? 0 : 0.12),
            value: isHovered
        )
    }
}

struct HoverTextButton: View {
    let title: String
    let help: String
    let height: CGFloat
    let horizontalPadding: CGFloat
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.quickCalThemeStyle) private var themeStyle
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, horizontalPadding)
                .frame(height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(themeStyle.secondaryText)
        .background {
            RoundedRectangle(
                cornerRadius: themeStyle.controlCornerRadius,
                style: .continuous
            )
            .fill(isHovered ? themeStyle.hoverColor : .clear)
        }
        .onHover { isHovered = $0 }
        .animation(
            .easeOut(duration: reduceMotion ? 0 : 0.12),
            value: isHovered
        )
        .help(Text(verbatim: help))
        .accessibilityLabel(Text(verbatim: help))
    }
}

struct CompactCheckboxToggleStyle: ToggleStyle {
    @Environment(\.quickCalThemeStyle) private var themeStyle

    func makeBody(configuration: Configuration) -> some View {
        HoverSurface(horizontalPadding: 0, verticalPadding: 0) {
            Button {
                configuration.isOn.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: configuration.isOn
                        ? "checkmark.square.fill"
                        : "square"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 15, height: 15)

                    configuration.label
                }
                .foregroundStyle(themeStyle.secondaryText)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
