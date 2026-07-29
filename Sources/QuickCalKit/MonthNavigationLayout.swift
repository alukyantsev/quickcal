import CoreGraphics

public enum MonthNavigationLayout {
    public static let navigationControlSize: CGFloat = 32
    public static let todayControlSize: CGFloat = 30
    public static let controlSpacing: CGFloat = 2
    public static let minimumTitleScale: CGFloat = 0.85

    public static var sideReservation: CGFloat {
        todayControlSize + controlSpacing + navigationControlSize
    }

    public static func titleFrame(in contentWidth: CGFloat) -> CGRect {
        let normalizedWidth = max(0, contentWidth)
        let reservation = min(sideReservation, normalizedWidth / 2)

        return CGRect(
            x: reservation,
            y: 0,
            width: normalizedWidth - (2 * reservation),
            height: navigationControlSize
        )
    }
}
