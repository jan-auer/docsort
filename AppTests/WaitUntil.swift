import Testing

/// Waits up to `timeout` for `condition`, which asynchronous work on the main actor (a model's action, an observation,
/// a watcher's update) makes true, and records an issue when it does not.
@MainActor
func waitUntil(
  timeout: Duration = .seconds(5), _ condition: () -> Bool,
  sourceLocation: SourceLocation = #_sourceLocation
) async throws {
  let deadline = ContinuousClock.now + timeout
  while !condition() {
    guard ContinuousClock.now < deadline else {
      Issue.record("Timed out waiting for the condition", sourceLocation: sourceLocation)
      return
    }
    try await Task.sleep(for: .milliseconds(10))
  }
}
