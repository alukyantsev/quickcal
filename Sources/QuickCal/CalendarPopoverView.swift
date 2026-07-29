import AppKit
import SwiftUI
import QuickCalKit

struct CalendarPopoverView: View {
    @AppStorage("showWeekNumbers") private var showWeekNumbers = true
    @State private var displayedMonth = Date()
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 12) {
                Text(context.date.formatted(
                    .dateTime.weekday(.wide).day().month(.wide).year()
                ))
                .font(.headline)
                .foregroundStyle(.secondary)

                Divider()

                monthNavigation

                if let month = CalendarMonth(
                    containing: displayedMonth,
                    calendar: calendar
                ) {
                    CalendarGridView(
                        month: month,
                        showWeekNumbers: showWeekNumbers,
                        today: context.date
                    )
                } else {
                    Button("Вернуться к текущему месяцу") {
                        displayedMonth = Date()
                    }
                }

                Divider()

                Toggle("Показывать номера недель", isOn: $showWeekNumbers)
                    .toggleStyle(.checkbox)

                Toggle(
                    "Запускать при входе",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                .toggleStyle(.checkbox)

                if let message = launchAtLogin.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                Button("Выйти из QuickCal") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .frame(width: 342)
        }
        .onAppear {
            launchAtLogin.refresh()
        }
    }

    private var monthNavigation: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .help("Предыдущий месяц")

            Spacer()

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title2.weight(.semibold))

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .help("Следующий месяц")
        }
    }

    private func moveMonth(by offset: Int) {
        guard
            let next = calendar.date(byAdding: .month, value: offset, to: displayedMonth),
            let interval = calendar.dateInterval(of: .month, for: next)
        else {
            displayedMonth = Date()
            return
        }
        displayedMonth = interval.start
    }
}
