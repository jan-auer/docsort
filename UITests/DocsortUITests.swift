import XCTest

final class DocsortUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// Launches the app with the UI-test fixture (an invented archive and inboxes built fresh in the app's temporary
  /// directory, never the user's settings) and waits for its main window.
  ///
  /// Keystrokes go to the returned window element, not to the `XCUIApplication`: on macOS 27, synthesizing a key
  /// event on the application element makes the test runner abort while it looks up the display of the
  /// application's frame (`SLSGetDisplaysWithRect` assertion).
  @MainActor
  private func launchMainWindow() -> (app: XCUIApplication, mainWindow: XCUIElement) {
    let app = XCUIApplication()
    app.launchArguments = ["-docsort-ui-test-fixture"]
    app.launch()
    let mainWindow = app.descendants(matching: .any)["main-window"]
    XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    return (app, mainWindow)
  }

  @MainActor
  func testMainWindowAppearsOnLaunch() throws {
    _ = launchMainWindow()
  }

  @MainActor
  func testCommandCommaOpensSettings() throws {
    let (app, mainWindow) = launchMainWindow()

    mainWindow.typeKey(",", modifierFlags: .command)

    let settingsWindow = app.descendants(matching: .any)["settings-window"]
    XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))
  }

  @MainActor
  func testCommandYOpensHistory() throws {
    let (app, mainWindow) = launchMainWindow()

    mainWindow.typeKey("y", modifierFlags: .command)

    let historyWindow = app.descendants(matching: .any)["history-window"]
    XCTAssertTrue(historyWindow.waitForExistence(timeout: 5))
  }

  @MainActor
  func testSidebarHistoryRowOpensHistory() throws {
    let (app, _) = launchMainWindow()

    let historyRow = app.descendants(matching: .any)["sidebar-history"]
    XCTAssertTrue(historyRow.waitForExistence(timeout: 5))
    historyRow.click()

    let historyWindow = app.descendants(matching: .any)["history-window"]
    XCTAssertTrue(historyWindow.waitForExistence(timeout: 5))
  }

  /// The sidebar row of the inbox file `name`.
  @MainActor
  private func sidebarRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier == 'sidebar-row' AND label == %@", name))
      .firstMatch
  }

  /// Waits until `element`'s accessibility value is `value`.
  @MainActor
  private func waitForValue(_ value: String, of element: XCUIElement) -> Bool {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", value), object: element)
    return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
  }

  @MainActor
  func testFilingFromTheKeyboardAndUndo() throws {
    let (app, mainWindow) = launchMainWindow()
    let invoice = sidebarRow("Rechnung_NA-33-08812.pdf", in: app)
    XCTAssertTrue(invoice.waitForExistence(timeout: 5))
    XCTAssertEqual(invoice.value as? String, "unfiled")
    invoice.click()

    // Typing in the sidebar starts the destination filter.
    mainWindow.typeText("noten")
    let filter = app.textFields["picker-filter"]
    XCTAssertTrue(waitForValue("noten", of: filter))
    let firstDestination = app.descendants(matching: .any)
      .matching(identifier: "picker-row").firstMatch
    XCTAssertTrue(firstDestination.waitForExistence(timeout: 5))
    XCTAssertTrue(firstDestination.label.contains("Noten & Bücher"))

    mainWindow.typeKey(.return, modifierFlags: .command)

    XCTAssertTrue(waitForValue("filed", of: invoice))
    let status = app.descendants(matching: .any)["status-message"]
    XCTAssertTrue(status.waitForExistence(timeout: 5))
    XCTAssertEqual(
      status.label, "Moved to Musik Margit/Noten & Bücher as Rechnung_NA-33-08812.pdf · Undo ⌘Z")
    let title = app.descendants(matching: .any)["toolbar-file-title"]
    XCTAssertTrue(
      waitForLabel("Web-Downloads › 2033-10-20 Verlängerung Jahreskarte Konrad.pdf", of: title))

    mainWindow.typeKey("z", modifierFlags: .command)

    XCTAssertTrue(waitForValue("unfiled", of: invoice))
    XCTAssertTrue(waitForLabel("Web-Downloads › Rechnung_NA-33-08812.pdf", of: title))
  }

  @MainActor
  func testTrashAndUndo() throws {
    let (app, mainWindow) = launchMainWindow()
    let scan = sidebarRow("2033-10-11_Optik Klarblick.pdf", in: app)
    XCTAssertTrue(scan.waitForExistence(timeout: 5))
    scan.click()

    let trash = app.descendants(matching: .any)["toolbar-trash"]
    XCTAssertTrue(trash.waitForExistence(timeout: 5))
    trash.click()
    XCTAssertTrue(waitForValue("trashed", of: scan))

    mainWindow.typeKey("z", modifierFlags: .command)
    XCTAssertTrue(waitForValue("unfiled", of: scan))
  }

  /// Waits until `element`'s accessibility label is `label`.
  @MainActor
  private func waitForLabel(_ label: String, of element: XCUIElement) -> Bool {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", label), object: element)
    return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
  }
}
