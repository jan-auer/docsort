import Foundation

/// Starts and stops access to the security scope of a URL resolved from a security-scoped bookmark.
public protocol SecurityScopeAccess: Sendable {
  /// Starts access to `url`'s security scope; returns false when access was refused. Each successful start must be
  /// balanced by one `stopAccessing(_:)`.
  func startAccessing(_ url: URL) -> Bool
  /// Ends one access to `url`'s security scope started by `startAccessing(_:)`.
  func stopAccessing(_ url: URL)
}

/// The system's security scope access, through `URL.startAccessingSecurityScopedResource()`.
public struct SystemSecurityScopeAccess: SecurityScopeAccess {
  /// The system's security scope access.
  public init() {}

  /// Starts access to `url`'s security scope; returns false when the system refused it.
  public func startAccessing(_ url: URL) -> Bool {
    url.startAccessingSecurityScopedResource()
  }

  /// Ends one access to `url`'s security scope.
  public func stopAccessing(_ url: URL) {
    url.stopAccessingSecurityScopedResource()
  }
}
