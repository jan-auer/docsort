import XCTest

final class DocsortUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testMainWindowAppearsOnLaunch() throws {
    let app = XCUIApplication()
    app.launch()

    let mainWindow = app.descendants(matching: .any)["main-window"]
    XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
  }

  @MainActor
  func testCommandCommaOpensSettings() throws {
    let app = XCUIApplication()
    app.launch()

    app.typeKey(",", modifierFlags: .command)

    let settingsWindow = app.descendants(matching: .any)["settings-window"]
    XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))
  }

  @MainActor
  func testCommandYOpensHistory() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.descendants(matching: .any)["main-window"].waitForExistence(timeout: 5))

    app.typeKey("y", modifierFlags: .command)

    let historyWindow = app.descendants(matching: .any)["history-window"]
    XCTAssertTrue(historyWindow.waitForExistence(timeout: 5))
  }

  @MainActor
  func testSidebarHistoryRowOpensHistory() throws {
    let app = XCUIApplication()
    app.launch()

    let historyRow = app.descendants(matching: .any)["sidebar-history"]
    XCTAssertTrue(historyRow.waitForExistence(timeout: 5))
    historyRow.click()

    let historyWindow = app.descendants(matching: .any)["history-window"]
    XCTAssertTrue(historyWindow.waitForExistence(timeout: 5))
  }
}
