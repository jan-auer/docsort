import Foundation

/// A file's date as the sidebar row shows it: compact and absolute, the way Finder and Mail do. Day and abbreviated
/// month ("12 Oct", "Oct 12" depending on the locale), with the year only when it isn't the current one
/// ("12 Oct 2033").
nonisolated enum SidebarDateText {
  /// The wording for `date`, with the current year taken from `now` in `calendar`.
  static func text(
    for date: Date, relativeTo now: Date, calendar: Calendar = .current, locale: Locale = .current
  ) -> String {
    var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
      .day()
      .month(.abbreviated)
    if calendar.component(.year, from: date) != calendar.component(.year, from: now) {
      style = style.year()
    }
    return date.formatted(style)
  }
}
