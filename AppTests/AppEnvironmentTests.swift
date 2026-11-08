import DocsortCore
import Foundation
import Testing

@testable import Docsort

@Suite("AppEnvironment")
struct AppEnvironmentTests {
  @Test("The launch mode is the unit-test host only when XCTest configured the process")
  func launchModeFollowsTheEnvironment() {
    #expect(AppLaunchMode.current(processEnvironment: [:]) == .standard)
    #expect(
      AppLaunchMode.current(processEnvironment: [
        "XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"
      ])
        == .unitTestHost)
    #expect(
      AppLaunchMode.current(processEnvironment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"])
        == .swiftUIPreviews)
  }

  @Test("The UI-test launch arguments pick the UI-test fixture and the picker test host")
  func launchModeFollowsTheUITestArguments() {
    #expect(
      AppLaunchMode.current(
        processEnvironment: [:], arguments: ["Docsort", AppLaunchMode.uiTestFixtureArgument])
        == .uiTestFixture)
    #expect(
      AppLaunchMode.current(
        processEnvironment: [:], arguments: ["Docsort", AppLaunchMode.pickerTestHostArgument])
        == .pickerTestHost)
  }

  @Test("This test run's host app uses the inert environment")
  func thisProcessIsTheUnitTestHost() {
    #expect(AppLaunchMode.current() == .unitTestHost)
  }

  @MainActor
  @Test(
    "The inert environment starts with no folder settings and keeps its history in the temporary directory"
  )
  func inertEnvironmentIsEmpty() throws {
    let environment = AppEnvironment.inert(named: "environment-test")
    #expect(try FolderSettings.preference(in: environment.defaults).load() == nil)
    #expect(environment.defaults !== UserDefaults.standard)
    #expect(environment.filingHistoryURL.path().hasPrefix(URL.temporaryDirectory.path()))
  }
}
