import SwiftUI

@main
struct QuickCalApp: App {
    var body: some Scene {
        MenuBarExtra("QuickCal", systemImage: "calendar") {
            CalendarPopoverView()
        }
        .menuBarExtraStyle(.window)
    }
}
