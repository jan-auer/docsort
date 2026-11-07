import Foundation

/// Somewhere items can be moved to so they can be restored later.
public protocol FileTrash: Sendable {
  /// Moves the item at `url` to the Trash and returns where it landed there.
  func moveToTrash(_ url: URL) throws -> URL
}

/// The user's Trash, through `FileManager.trashItem(at:resultingItemURL:)`.
public struct SystemTrash: FileTrash {
  /// The Trash cannot report where an item landed, so it cannot be put back.
  public struct LocationUnknown: LocalizedError {
    /// The item that was trashed.
    public let url: URL
    /// Says that the item may be in the Trash but cannot be put back by the app.
    public var errorDescription: String? {
      "the Trash did not report where \(url.path(percentEncoded: false)) landed, so it cannot be put back"
    }
  }

  /// Creates a handle to the user's Trash.
  public init() {}

  /// Moves the item at `url` to the Trash of its volume and returns where it landed.
  public func moveToTrash(_ url: URL) throws -> URL {
    var resultingURL: NSURL?
    try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
    guard let trashedURL = resultingURL as URL? else { throw LocationUnknown(url: url) }
    return trashedURL
  }
}
