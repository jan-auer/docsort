import Foundation
import Testing

/// A `UserDefaults` suite with a unique name, whose persistent domain is removed when the value is deinitialised.
final class TemporaryDefaults {
  let suiteName: String
  let defaults: UserDefaults

  init() throws {
    suiteName = "DocsortCoreTests-\(UUID().uuidString)"
    defaults = try #require(UserDefaults(suiteName: suiteName))
  }

  deinit {
    defaults.removePersistentDomain(forName: suiteName)
  }
}
