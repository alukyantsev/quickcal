import SwiftUI

struct HoverIconButton: View {
    let title: String
    let systemImage: String
    let symbolSize: CGFloat
    let controlSize: CGFloat
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.08) : .clear)
        }
        .scaleEffect(isHovered && !reduceMotion ? 1.05 : 1)
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : .clear)
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
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.08) : .clear)
        }
        .scaleEffect(isHovered && !reduceMotion ? 1.01 : 1)
        .onHover { isHovered = $0 }
        .animation(
            .easeOut(duration: reduceMotion ? 0 : 0.12),
            value: isHovered
        )
    }
}
