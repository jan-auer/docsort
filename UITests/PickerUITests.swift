import XCTest

/// Drives the destination picker by keyboard in its debug-only test host (`App/Picker/PickerTestHost.swift`), which
/// the app shows when launched with `-docsort-picker-test-host`. The host builds a small sample archive from
/// `docs/design/sample-data/` and shows every event the picker sends in `picker-test-last-event`.
///
/// Tests assert on elements and accessibility identifiers only; nothing captures the screen (`agent-tooling`).
final class PickerUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// The launched app and the elements the tests use.
  private struct Host {
    let app: XCUIApplication
    let filter: XCUIElement
    let lastEvent: XCUIElement
  }

  /// Launches the app with the picker test host, waits for the sample archive to be indexed and focuses the filter.
  @MainActor
  private func launchHost() -> Host {
    let app = XCUIApplication()
    app.launchArguments.append("-docsort-picker-test-host")
    app.launch()

    let host = app.descendants(matching: .any)["picker-test-host"]
    XCTAssertTrue(host.waitForExistence(timeout: 10))
    // The top-level folders appear once the archive is indexed.
    let topLevelFolder = host.descendants(matching: .any).matching(identifier: "picker-row")
      .matching(NSPredicate(format: "label == %@", "Gesundheit")).firstMatch
    XCTAssertTrue(topLevelFolder.waitForExistence(timeout: 10))

    let filter = host.textFields["picker-filter"]
    filter.click()
    return Host(app: app, filter: filter, lastEvent: host.staticTexts["picker-test-last-event"])
  }

  /// Waits until the last-event line reads `text`. (A static text carries its text as its value on macOS.)
  @MainActor
  private func expectLastEvent(
    _ host: Host, _ text: String, file: StaticString = #filePath, line: UInt = #line
  ) {
    let reads = NSPredicate(format: "value == %@", text)
    let result = XCTWaiter().wait(
      for: [expectation(for: reads, evaluatedWith: host.lastEvent)], timeout: 5)
    let lastEvent = host.lastEvent.exists ? host.lastEvent.value as? String ?? "" : ""
    XCTAssertEqual(result, .completed, "last event is “\(lastEvent)”", file: file, line: line)
  }

  @MainActor
  func testRightArrowStepsInAndTabChoosesThisFolder() throws {
    let host = launchHost()

    host.filter.typeText("gesund")
    host.filter.typeKey(.rightArrow, modifierFlags: [])
    XCTAssertTrue(
      host.app.descendants(matching: .any)["picker-this-folder"].waitForExistence(timeout: 5))
    host.filter.typeKey(.tab, modifierFlags: [])

    expectLastEvent(host, "chose Gesundheit")
  }

  @MainActor
  func testCommandReturnRequestsMoveToTheHighlightedMatch() throws {
    let host = launchHost()

    host.filter.typeText("ilmnet rechnungen")
    host.filter.typeKey(.return, modifierFlags: .command)

    expectLastEvent(host, "moveRequested Kommunikation/Ilmnet Internet/Rechnungen")
  }

  @MainActor
  func testEscapeClearsTheFilterThenStepsBack() throws {
    let host = launchHost()

    host.filter.typeText("reisen")
    host.filter.typeKey(.escape, modifierFlags: [])
    XCTAssertEqual(host.filter.value as? String, "")
    host.filter.typeKey(.escape, modifierFlags: [])

    expectLastEvent(host, "steppedBack")
  }

  @MainActor
  func testNewFolderInsideTheHighlightedFolderIsChosenAsPending() throws {
    let host = launchHost()

    host.filter.typeText("reisen")
    host.filter.typeKey(.rightArrow, modifierFlags: [])
    host.filter.typeKey("n", modifierFlags: [.shift, .command])
    let name = host.app.textFields["picker-new-folder-name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.typeText("2033-11 Besuch Westerholm/Bahn")
    name.typeKey(.return, modifierFlags: [])

    expectLastEvent(host, "chose new Reisen/2033-11 Besuch Westerholm/Bahn")
  }

  @MainActor
  func testNewFolderWithAnExistingNameChoosesTheExistingFolder() throws {
    let host = launchHost()

    host.filter.typeText("reisen")
    host.filter.typeKey(.rightArrow, modifierFlags: [])
    host.filter.typeKey("n", modifierFlags: [.shift, .command])
    let name = host.app.textFields["picker-new-folder-name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.typeText("reiseplanung ideen")
    XCTAssertTrue(
      host.app.descendants(matching: .any)["picker-new-folder-notice"].waitForExistence(timeout: 5))
    name.typeKey(.return, modifierFlags: [])

    expectLastEvent(host, "chose Reisen/Reiseplanung Ideen")
  }

  @MainActor
  func testClickingAFileInFolderContentsTakesItsName() throws {
    let host = launchHost()

    host.filter.typeText("ilmnet rechnungen")
    let file = host.app.descendants(matching: .any).matching(identifier: "folder-contents-file")
      .matching(NSPredicate(format: "label CONTAINS %@", "2033-10-04 Rechnung Oktober.pdf"))
      .firstMatch
    XCTAssertTrue(file.waitForExistence(timeout: 5))
    file.click()

    expectLastEvent(host, "tookFileName 2033-10-04 Rechnung Oktober.pdf")
  }
}
