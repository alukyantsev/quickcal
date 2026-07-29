import SwiftUI

@main
struct QuickCalApp: App {
    var body: some Scene {
        MenuBarExtra {
            CalendarPopoverView()
        } label: {
            Image(systemName: "calendar")
                .symbolRenderingMode(.monochrome)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 24)
                .accessibilityLabel("QuickCal")
        }
        .menuBarExtraStyle(.window)
    }
}
