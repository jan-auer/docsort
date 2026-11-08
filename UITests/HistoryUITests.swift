import XCTest

/// The History window, on the UI-test fixture (`-docsort-ui-test-fixture`).
///
/// Keystrokes go to window elements, never to the `XCUIApplication` (see `DocsortUITests`).
final class HistoryUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testFiledFileAppearsInHistoryAndMovesBack() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-docsort-ui-test-fixture"]
    app.launch()
    let mainWindow = app.descendants(matching: .any)["main-window"]
    XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))

    // File the invoice to the first "noten" destination from the keyboard.
    let invoice = app.descendants(matching: .any)
      .matching(
        NSPredicate(
          format: "identifier == 'sidebar-row' AND label == %@", "Rechnung_NA-33-08812.pdf")
      )
      .firstMatch
    XCTAssertTrue(invoice.waitForExistence(timeout: 5))
    invoice.click()
    mainWindow.typeText("noten")
    let firstDestination = app.descendants(matching: .any)
      .matching(identifier: "picker-row").firstMatch
    XCTAssertTrue(firstDestination.waitForExistence(timeout: 5))
    mainWindow.typeKey(.return, modifierFlags: .command)
    XCTAssertTrue(waitFor("value == 'filed'", invoice))

    mainWindow.typeKey("y", modifierFlags: .command)

    let historyWindow = app.descendants(matching: .any)["history-window"]
    XCTAssertTrue(historyWindow.waitForExistence(timeout: 5))
    let count = historyWindow.descendants(matching: .any)["history-count"]
    // Static texts carry their text as their value on macOS.
    XCTAssertTrue(waitFor("value == '1 entry'", count))
    let originalName = historyWindow.descendants(matching: .any)
      .matching(identifier: "history-original-name").firstMatch
    XCTAssertTrue(originalName.waitForExistence(timeout: 5))
    XCTAssertEqual(originalName.value as? String, "Rechnung_NA-33-08812.pdf")

    // The newest entry is selected; Move Back to Inbox returns the file and adds an entry.
    let moveBack = historyWindow.buttons["history-return"]
    XCTAssertTrue(moveBack.waitForExistence(timeout: 5))
    XCTAssertEqual(moveBack.label, "Move Back to Inbox")
    moveBack.click()

    XCTAssertTrue(waitFor("value == '2 entries'", count))
    XCTAssertTrue(waitFor("value == 'unfiled'", invoice))
  }

  /// Waits until `element` matches the predicate `format`.
  @MainActor
  private func waitFor(_ format: String, _ element: XCUIElement) -> Bool {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: format), object: element)
    return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
  }
}
