import Foundation
import Testing

@testable import Docsort

@Suite("SidebarDateText")
struct SidebarDateTextTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }

  private let british = Locale(identifier: "en_GB")

  private func date(year: Int, month: Int, day: Int, hour: Int = 12) throws -> Date {
    try #require(
      calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
  }

  @Test("A date in the current year shows day and abbreviated month, without the year")
  func currentYear() throws {
    let now = try date(year: 2034, month: 11, day: 8)

    let text = SidebarDateText.text(
      for: try date(year: 2034, month: 10, day: 12), relativeTo: now, calendar: calendar,
      locale: british)

    #expect(text == "12 Oct")
  }

  @Test("Today and yesterday show the absolute date, not a relative word")
  func recentDatesAreAbsolute() throws {
    let now = try date(year: 2034, month: 11, day: 8, hour: 16)

    let today = SidebarDateText.text(
      for: try date(year: 2034, month: 11, day: 8, hour: 9), relativeTo: now, calendar: calendar,
      locale: british)
    let yesterday = SidebarDateText.text(
      for: try date(year: 2034, month: 11, day: 7), relativeTo: now, calendar: calendar,
      locale: british)

    #expect(today == "8 Nov")
    #expect(yesterday == "7 Nov")
  }

  @Test("A date in another year also shows the year")
  func otherYear() throws {
    let now = try date(year: 2034, month: 1, day: 3)

    let lastYear = SidebarDateText.text(
      for: try date(year: 2033, month: 10, day: 12), relativeTo: now, calendar: calendar,
      locale: british)
    let nextYear = SidebarDateText.text(
      for: try date(year: 2035, month: 2, day: 1), relativeTo: now, calendar: calendar,
      locale: british)

    #expect(lastYear == "12 Oct 2033")
    #expect(nextYear == "1 Feb 2035")
  }

  @Test("Order, month names and punctuation follow the locale")
  func localeOrder() throws {
    let now = try date(year: 2034, month: 11, day: 8)
    let thisYear = try date(year: 2034, month: 10, day: 12)
    let lastYear = try date(year: 2033, month: 10, day: 12)
    let austrian = Locale(identifier: "de_AT")
    let american = Locale(identifier: "en_US")

    func text(_ date: Date, _ locale: Locale) -> String {
      SidebarDateText.text(for: date, relativeTo: now, calendar: calendar, locale: locale)
    }

    #expect(text(thisYear, austrian) == "12. Okt.")
    #expect(text(lastYear, austrian) == "12. Okt. 2033")
    #expect(text(thisYear, american) == "Oct 12")
    #expect(text(lastYear, american) == "Oct 12, 2033")
  }

  @Test("The year is decided in the calendar's time zone")
  func yearBoundaryInTimeZone() throws {
    let now = try date(year: 2034, month: 1, day: 1, hour: 6)

    let newYearsEveLate = SidebarDateText.text(
      for: try date(year: 2033, month: 12, day: 31, hour: 23), relativeTo: now,
      calendar: calendar, locale: british)

    #expect(newYearsEveLate == "31 Dec 2033")
  }
}
