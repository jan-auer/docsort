import XCTest

final class KeyboardShortcutsUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// ⌘/ opens the sheet over the main window with the search field focused, typing filters the rows, Esc clears the
  /// search and then closes the sheet, and ⌘/ closes it again after reopening.
  @MainActor
  func testCommandSlashOpensAndClosesTheShortcutsSheet() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-docsort-ui-test-fixture"]
    app.launch()
    let mainWindow = app.descendants(matching: .any)["main-window"]
    XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    let sheet = app.descendants(matching: .any)["keyboard-shortcuts-sheet"]

    mainWindow.typeKey("/", modifierFlags: .command)
    XCTAssertTrue(sheet.waitForExistence(timeout: 5))

    // The search field has focus: typing filters the list down to the matching rows.
    let search = sheet.descendants(matching: .any)["keyboard-shortcuts-search"]
    XCTAssertTrue(search.waitForExistence(timeout: 2))
    sheet.typeText("trash")
    let rows = sheet.descendants(matching: .any).matching(identifier: "keyboard-shortcuts-row")
    let trashRow = rows.matching(NSPredicate(format: "label == %@", "Move to Trash")).firstMatch
    XCTAssertTrue(trashRow.waitForExistence(timeout: 2))
    let historyRow = rows.matching(NSPredicate(format: "label == %@", "History")).firstMatch
    XCTAssertFalse(historyRow.exists)

    // The first Esc clears the search, the second closes the sheet.
    sheet.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(historyRow.waitForExistence(timeout: 2))
    XCTAssertTrue(sheet.exists)
    sheet.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))

    mainWindow.typeKey("/", modifierFlags: .command)
    XCTAssertTrue(sheet.waitForExistence(timeout: 5))
    sheet.typeKey("/", modifierFlags: .command)
    XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
  }

  /// ⌘⌫ in the sheet's search field deletes text there; it doesn't move the selected file to the Trash.
  @MainActor
  func testCommandDeleteInTheSheetLeavesTheSelectedFile() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-docsort-ui-test-fixture"]
    app.launch()
    let mainWindow = app.descendants(matching: .any)["main-window"]
    XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    let scan = app.descendants(matching: .any)
      .matching(
        NSPredicate(
          format: "identifier == 'sidebar-row' AND label == %@", "2033-10-11_Optik Klarblick.pdf")
      )
      .firstMatch
    XCTAssertTrue(scan.waitForExistence(timeout: 5))
    scan.click()
    XCTAssertEqual(scan.value as? String, "unfiled")

    mainWindow.typeKey("/", modifierFlags: .command)
    let sheet = app.descendants(matching: .any)["keyboard-shortcuts-sheet"]
    XCTAssertTrue(sheet.waitForExistence(timeout: 5))
    sheet.typeText("trash")
    sheet.typeKey(.delete, modifierFlags: .command)

    let search = sheet.descendants(matching: .any)["keyboard-shortcuts-search"]
    let cleared = XCTNSPredicateExpectation(
      predicate: NSPredicate(
        format: "value == '' OR value == nil OR value == %@", "Search shortcuts"),
      object: search)
    XCTAssertEqual(XCTWaiter().wait(for: [cleared], timeout: 3), .completed)
    sheet.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
    XCTAssertEqual(scan.value as? String, "unfiled")
  }
}
