## Problem Statement

QuickCal currently shows only the boundary weeks of the selected month and does not turn selected vacation dates into an actionable countdown. Users need surrounding calendar context without navigating away from the chosen month and a compact indication of the nearest current or future vacation.

## Solution

Keep the chosen month as the primary month while always rendering one complete Monday-to-Sunday week before its current grid and one complete week after it. The extra dates behave exactly like all other dates, including selection, Russian production-calendar status and week numbers, but do not change the primary month when clicked.

Treat each contiguous set of selected civil dates as an individual vacation. Render a localized line directly below the calendar grid for the current vacation or the nearest future one, excluding today from any remaining-day count. Do not show a line when no current or future vacation exists.

## User Stories

1. As a QuickCal user, I want one whole Monday-to-Sunday week before the selected month so that I can see near-month context.
2. As a QuickCal user, I want one whole Monday-to-Sunday week after the selected month so that I can plan into the next month.
3. As a QuickCal user, I want the original boundary weeks to remain visible in addition to the extra weeks.
4. As a QuickCal user, I want dates outside the primary month to be selectable without navigating away from it.
5. As a QuickCal user, I want production-calendar marking and week numbers to cover every displayed date.
6. As a QuickCal user, I want consecutive selected dates to be interpreted as one vacation even across visible week and month boundaries.
7. As a QuickCal user, I want separate selected ranges to remain separate vacations.
8. As a QuickCal user, I want the closest future vacation displayed before it begins.
9. As a QuickCal user, I want the remaining duration displayed while a vacation is underway.
10. As a QuickCal user, I want a distinct message for a one-day vacation today and for the final day of a multi-day vacation.
11. As a QuickCal user, I want Russian and English phrases and date ranges formatted naturally.
12. As a QuickCal user, I want old selections preserved even after their vacations have passed.

## Implementation Decisions

- Displayed calendar weeks always use Monday as their first weekday and Sunday as their last, independently of the system regional first-weekday preference.
- The month title and navigation remain bound to the selected primary month; toggling an adjacent-month date changes only the selection.
- Calendar data exposes a contiguous display range containing the existing month boundary weeks plus one preceding and one following whole week.
- Production-calendar loading derives years from the full displayed range, including cross-year supplementary dates.
- Vacation grouping uses adjacent `CalendarDate` values in the system time zone. The current date is derived from the same time zone.
- For a future vacation, the line contains the number of full calendar days before its first date and its localized range. For a current multi-day vacation, it contains days after today and an inclusive end-date phrase. A one-day vacation today and the final day of a multi-day vacation use distinct phrases.
- A range inside one month uses a compact localized form; a range spanning months renders both months. The popover grows vertically with the added rows and never scrolls this content.

## Testing Decisions

- Test observable calendar ranges, date interactivity inputs, year loading inputs, vacation grouping, countdown states, and localizations rather than SwiftUI implementation details.
- Extend the existing Swift Testing suites around calendar-month construction, selection segments, work-calendar control, and localization.
- Test Monday-first ranges, month and year crossings, one-day and multi-day vacations, past-only selection, and English/Russian singular and plural forms.

## Out of Scope

- Notifications, reminders, calendar-event integration, an editable vacation name, separate vacation settings, and a separate toggle for supplementary weeks.
- Changing the stored selection format or removing expired selected dates.

## Further Notes

- Decisions confirmed by the user: Monday-to-Sunday weeks in every locale; system time zone defines today; a cross-month range displays both months; the popover grows without scrolling; “Отпуск сегодня” is only for a one-day vacation today.
