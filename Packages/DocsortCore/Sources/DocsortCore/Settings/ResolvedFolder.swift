import Foundation

/// Whether a configured folder can be used in this launch.
public enum FolderAvailability: Equatable, Sendable {
  /// The folder exists and its security scope is active.
  case available
  /// The folder exists and its security scope is active, but its bookmark is stale and could not be renewed; it may
  /// fail to resolve at a later launch.
  case stale
  /// The folder no longer exists.
  case missing
  /// The folder cannot be used: its volume is not mounted, access was refused or denied, it is not a folder, or
  /// resolution failed otherwise. `reason` is a sentence describing the cause.
  case unreachable(reason: String)
}

/// The outcome of resolving one configured folder at launch.
public struct ResolvedFolder: Equatable, Sendable {
  /// The folder's reference, with a renewed bookmark and an updated last known path where resolution produced them.
  public let reference: FolderReference
  /// The folder's location, with its security scope active; `nil` unless `availability` is `.available` or `.stale`.
  public let url: URL?
  /// Whether the folder can be used.
  public let availability: FolderAvailability

  /// A resolution outcome; `FolderResolver` produces these.
  public init(reference: FolderReference, url: URL?, availability: FolderAvailability) {
    self.reference = reference
    self.url = url
    self.availability = availability
  }
}

/// An inbox and the outcome of resolving its folder.
public struct ResolvedInbox: Equatable, Sendable {
  /// The inbox, whose folder is the resolved (possibly renewed) reference.
  public let inbox: InboxFolder
  /// The outcome of resolving the inbox's folder.
  public let folder: ResolvedFolder

  /// An inbox with its resolution outcome; `FolderResolver` produces these.
  public init(inbox: InboxFolder, folder: ResolvedFolder) {
    self.inbox = inbox
    self.folder = folder
  }
}
