import DocsortCore

extension FolderAvailability {
  /// The folder's status as the Settings window words it: "OK", "Not found", "Stale – choose again" or
  /// "Not reachable: <reason>".
  var settingsStatusText: String {
    switch self {
    case .available: "OK"
    case .stale: "Stale – choose again"
    case .missing: "Not found"
    case .unreachable(let reason): "Not reachable: \(reason)"
    }
  }

  /// Whether the user should choose the folder again: anything but available.
  var needsAttention: Bool {
    self != .available
  }
}
