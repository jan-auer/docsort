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

  /// Waits until `element` has keyboard focus.
  @MainActor
  private func waitForKeyboardFocus(of element: XCUIElement) -> Bool {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: element)
    return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
  }

  /// Selects the invoice in the sidebar and types `noten`, which goes into the destination filter.
  @MainActor
  private func startFilingTheInvoice() -> (app: XCUIApplication, mainWindow: XCUIElement) {
    let (app, mainWindow) = launchMainWindow()
    let invoice = sidebarRow("Rechnung_NA-33-08812.pdf", in: app)
    XCTAssertTrue(invoice.waitForExistence(timeout: 5))
    invoice.click()
    mainWindow.typeText("noten")
    XCTAssertTrue(waitForValue("noten", of: app.textFields["picker-filter"]))
    return (app, mainWindow)
  }

  @MainActor
  func testNameFieldKeysAfterChoosingADestination() throws {
    let (app, mainWindow) = startFilingTheInvoice()
    let filter = app.textFields["picker-filter"]
    let nameField = app.textFields["name-field"]

    // Tab chooses the highlighted folder and moves to the name field.
    mainWindow.typeKey(.tab, modifierFlags: [])
    XCTAssertTrue(waitForKeyboardFocus(of: nameField))
    let token = app.descendants(matching: .any)["picker-chosen-token"]
    XCTAssertTrue(token.waitForExistence(timeout: 5))
    XCTAssertTrue(token.label.contains("Noten & Bücher"))

    // Return doesn't move; it shows the hint, and the picker keeps its choice.
    mainWindow.typeKey(.return, modifierFlags: [])
    let hint = app.descendants(matching: .any)["filing-hint"]
    XCTAssertTrue(hint.waitForExistence(timeout: 5))
    XCTAssertEqual(hint.label, "Press ⌘Return to move")
    XCTAssertTrue(waitForKeyboardFocus(of: nameField))
    XCTAssertTrue(token.exists)

    // → moves the caret (to the end of the selected name); it doesn't step the picker into a folder.
    mainWindow.typeKey(.rightArrow, modifierFlags: [])
    mainWindow.typeText(" Advent")
    XCTAssertTrue(waitForValue("Rechnung_NA-33-08812 Advent", of: nameField))
    XCTAssertTrue(token.label.contains("Noten & Bücher"))

    // ↓ in the name field leaves the chosen destination alone.
    mainWindow.typeKey(.downArrow, modifierFlags: [])
    XCTAssertTrue(token.label.contains("Noten & Bücher"))

    // Esc returns to the filter.
    mainWindow.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(waitForKeyboardFocus(of: filter))
  }

  @MainActor
  func testReturnInTheNewFolderRowFocusesTheNameField() throws {
    let (app, mainWindow) = startFilingTheInvoice()

    mainWindow.typeKey("n", modifierFlags: [.command, .shift])
    let newFolderName = app.textFields["picker-new-folder-name"]
    XCTAssertTrue(waitForKeyboardFocus(of: newFolderName))
    mainWindow.typeText("2033 Adventkonzert")
    mainWindow.typeKey(.return, modifierFlags: [])

    XCTAssertTrue(waitForKeyboardFocus(of: app.textFields["name-field"]))
    let token = app.descendants(matching: .any)["picker-chosen-token"]
    XCTAssertTrue(token.waitForExistence(timeout: 5))
    XCTAssertTrue(token.label.contains("2033 Adventkonzert"))
  }

  @MainActor
  func testCommandReturnWithoutADestinationMovesNothing() throws {
    let (app, mainWindow) = launchMainWindow()
    let invoice = sidebarRow("Rechnung_NA-33-08812.pdf", in: app)
    XCTAssertTrue(invoice.waitForExistence(timeout: 5))
    invoice.click()

    mainWindow.typeKey(.return, modifierFlags: .command)

    let hint = app.descendants(matching: .any)["filing-hint"]
    XCTAssertTrue(hint.waitForExistence(timeout: 5))
    XCTAssertEqual(hint.label, "Choose a destination first")
    XCTAssertTrue(waitForKeyboardFocus(of: app.textFields["picker-filter"]))
    XCTAssertEqual(invoice.value as? String, "unfiled")
  }

  /// Files the invoice to the first "noten" destination from the keyboard and waits until its row reads `filed`.
  @MainActor
  private func fileTheInvoice() -> (
    app: XCUIApplication, mainWindow: XCUIElement, invoice: XCUIElement
  ) {
    let (app, mainWindow) = startFilingTheInvoice()
    mainWindow.typeKey(.return, modifierFlags: .command)
    let invoice = sidebarRow("Rechnung_NA-33-08812.pdf", in: app)
    XCTAssertTrue(waitForValue("filed", of: invoice))
    return (app, mainWindow, invoice)
  }

  @MainActor
  func testMoveBackFromTheStatusStrip() throws {
    let (app, _, invoice) = fileTheInvoice()

    invoice.click()
    let strip = app.descendants(matching: .any)["filing-strip"]
    XCTAssertTrue(strip.waitForExistence(timeout: 5))
    let moveBack = app.buttons["filing-strip-move-back"]
    XCTAssertTrue(moveBack.waitForExistence(timeout: 5))
    moveBack.click()

    XCTAssertTrue(waitForValue("unfiled", of: invoice))
    XCTAssertTrue(waitForNonExistence(of: strip))
  }

  @MainActor
  func testRenamingAFiledFile() throws {
    let (app, mainWindow, invoice) = fileTheInvoice()

    invoice.click()
    let moveButton = app.buttons["move-button"]
    XCTAssertTrue(moveButton.waitForExistence(timeout: 5))
    XCTAssertFalse(moveButton.isEnabled)
    let nameField = app.textFields["name-field"]
    XCTAssertTrue(waitForValue("Rechnung_NA-33-08812", of: nameField))
    nameField.click()
    XCTAssertTrue(waitForKeyboardFocus(of: nameField))
    mainWindow.typeKey("a", modifierFlags: .command)
    mainWindow.typeText("2033-10-13 Notenhaus Allegretto")
    XCTAssertTrue(waitForLabel("Rename", of: moveButton))
    XCTAssertTrue(moveButton.isEnabled)

    mainWindow.typeKey(.return, modifierFlags: .command)

    let status = app.descendants(matching: .any)["status-message"]
    XCTAssertTrue(
      waitForLabel("Renamed to 2033-10-13 Notenhaus Allegretto.pdf · Undo ⌘Z", of: status))
    XCTAssertEqual(invoice.value as? String, "filed")
    let title = app.descendants(matching: .any)["toolbar-file-title"]
    XCTAssertTrue(waitForLabel("Web-Downloads › 2033-10-13 Notenhaus Allegretto.pdf", of: title))
  }

  @MainActor
  func testPutBackWithOptionCommandZ() throws {
    let (app, mainWindow) = launchMainWindow()
    let scan = sidebarRow("2033-10-11_Optik Klarblick.pdf", in: app)
    XCTAssertTrue(scan.waitForExistence(timeout: 5))
    scan.click()
    let trash = app.descendants(matching: .any)["toolbar-trash"]
    XCTAssertTrue(trash.waitForExistence(timeout: 5))
    trash.click()
    XCTAssertTrue(waitForValue("trashed", of: scan))

    scan.click()
    XCTAssertTrue(app.buttons["filing-strip-put-back"].waitForExistence(timeout: 5))
    mainWindow.typeKey("z", modifierFlags: [.option, .command])

    XCTAssertTrue(waitForValue("unfiled", of: scan))
  }

  @MainActor
  func testRevertNameRestoresTheInboxName() throws {
    let (app, mainWindow) = launchMainWindow()
    let invoice = sidebarRow("Rechnung_NA-33-08812.pdf", in: app)
    XCTAssertTrue(invoice.waitForExistence(timeout: 5))
    invoice.click()
    let nameField = app.textFields["name-field"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 5))
    let revert = app.buttons["name-revert"]
    XCTAssertFalse(revert.exists)

    nameField.click()
    XCTAssertTrue(waitForKeyboardFocus(of: nameField))
    mainWindow.typeKey("a", modifierFlags: .command)
    mainWindow.typeText("2033-10-13 Notenhaus Allegretto")
    XCTAssertTrue(revert.waitForExistence(timeout: 5))
    revert.click()

    XCTAssertTrue(waitForValue("Rechnung_NA-33-08812", of: nameField))
    XCTAssertTrue(waitForNonExistence(of: revert))
  }

  /// Waits until `element` no longer exists.
  @MainActor
  private func waitForNonExistence(of element: XCUIElement) -> Bool {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: element)
    return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
  }

  /// Waits until `element`'s accessibility label is `label`.
  @MainActor
  private func waitForLabel(_ label: String, of element: XCUIElement) -> Bool {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", label), object: element)
    return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
  }
}
