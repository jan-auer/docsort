import Foundation
import Testing

@testable import Docsort

@Suite("HandledTimeText")
struct HandledTimeTextTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }

  private func date(day: Int, hour: Int, minute: Int = 0) throws -> Date {
    try #require(
      calendar.date(
        from: DateComponents(year: 2033, month: 10, day: day, hour: hour, minute: minute)))
  }

  @Test("The same day reads “today” with the time, the day before “yesterday”, older ones the date")
  func wording() throws {
    let now = try date(day: 13, hour: 16)

    let today = HandledTimeText.text(
      for: try date(day: 13, hour: 9, minute: 41), relativeTo: now, calendar: calendar)
    let yesterday = HandledTimeText.text(
      for: try date(day: 12, hour: 17, minute: 2), relativeTo: now, calendar: calendar)
    let older = HandledTimeText.text(
      for: try date(day: 4, hour: 11), relativeTo: now, calendar: calendar)

    #expect(today.hasPrefix("today "))
    #expect(today.contains("41"))
    #expect(yesterday.hasPrefix("yesterday "))
    #expect(yesterday.contains("02"))
    #expect(!older.hasPrefix("today") && !older.hasPrefix("yesterday"))
    #expect(older.contains("2033"))
  }
}
