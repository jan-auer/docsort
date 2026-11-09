import XCTest

final class KeyboardShortcutsUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// ⌘/ opens the sheet over the main window with the search field focused, typing filters the rows, Esc closes it,
  /// and ⌘/ closes it again after reopening.
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
    let rows = sheet.descendants(matching: .any).matching(identifier: "keyboard-shortcut-row")
    let trashRow = rows.matching(NSPredicate(format: "label == %@", "Move to Trash")).firstMatch
    XCTAssertTrue(trashRow.waitForExistence(timeout: 2))
    let historyRow = rows.matching(NSPredicate(format: "label == %@", "History")).firstMatch
    XCTAssertFalse(historyRow.exists)

    sheet.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))

    mainWindow.typeKey("/", modifierFlags: .command)
    XCTAssertTrue(sheet.waitForExistence(timeout: 5))
    sheet.typeKey("/", modifierFlags: .command)
    XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
  }
}
