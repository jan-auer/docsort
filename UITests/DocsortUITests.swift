import XCTest

final class DocsortUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// Launches the app and waits for its main window.
  ///
  /// Keystrokes go to the returned window element, not to the `XCUIApplication`: on macOS 27, synthesizing a key
  /// event on the application element makes the test runner abort while it looks up the display of the
  /// application's frame (`SLSGetDisplaysWithRect` assertion).
  @MainActor
  private func launchMainWindow() -> (app: XCUIApplication, mainWindow: XCUIElement) {
    let app = XCUIApplication()
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
}
