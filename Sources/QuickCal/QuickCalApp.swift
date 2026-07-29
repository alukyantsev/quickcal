import SwiftUI

@main
struct QuickCalApp: App {
    var body: some Scene {
        MenuBarExtra {
            CalendarPopoverView()
        } label: {
            Image(systemName: "calendar")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 22, height: 22)
                .accessibilityLabel("QuickCal")
        }
        .menuBarExtraStyle(.window)
    }
}
