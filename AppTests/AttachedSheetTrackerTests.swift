import AppKit
import Testing

@testable import Docsort

@Suite("Attached sheet tracker")
@MainActor
struct AttachedSheetTrackerTests {
  private func window() -> NSWindow {
    NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled],
      backing: .buffered, defer: true)
  }

  @Test("Reports a sheet attached to its window until it ends")
  func beginAndEnd() {
    let window = window()
    var reports: [Bool] = []
    let tracker = AttachedSheetTracker { reports.append($0) }
    tracker.window = window

    NotificationCenter.default.post(name: NSWindow.willBeginSheetNotification, object: window)
    NotificationCenter.default.post(name: NSWindow.didEndSheetNotification, object: window)

    #expect(reports == [true, false])
  }

  @Test("Ignores sheets of other windows and stops when its window goes away")
  func otherWindows() {
    let window = window()
    let otherWindow = self.window()
    var reports: [Bool] = []
    let tracker = AttachedSheetTracker { reports.append($0) }
    tracker.window = window

    NotificationCenter.default.post(name: NSWindow.willBeginSheetNotification, object: otherWindow)
    tracker.window = nil
    NotificationCenter.default.post(name: NSWindow.willBeginSheetNotification, object: window)

    #expect(reports == [false])
  }
}
