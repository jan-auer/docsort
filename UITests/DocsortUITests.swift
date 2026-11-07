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
}
