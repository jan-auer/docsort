#if DEBUG
  import DocsortCore
  import Foundation

  /// Configured folders for SwiftUI previews, named as in the fictional sample archive (`docs/design/sample-data/`):
  /// the archive `~/Archiv` and the inboxes "Web-Downloads" and "Scanner" in `~/Archiv/_Neu`.
  ///
  /// The bookmarks are empty and nothing is resolved: previews only show these values.
  enum SampleFolders {
    /// The archive root `~/Archiv`, available.
    static let archiveRoot = folder(at: "Archiv", availability: .available)

    /// The archive root `~/Archiv`, not found.
    static let missingArchiveRoot = folder(at: "Archiv", availability: .missing)

    /// The inboxes "Web-Downloads" and "Scanner", both available.
    static let inboxes = [
      inbox(at: "Archiv/_Neu/Web-Downloads", availability: .available),
      inbox(at: "Archiv/_Neu/Scanner", availability: .available),
    ]

    /// The inbox "Web-Downloads" available, labelled "Downloads", and "Scanner" not found.
    static let inboxesWithProblems = [
      inbox(at: "Archiv/_Neu/Web-Downloads", label: "Downloads", availability: .available),
      inbox(at: "Archiv/_Neu/Scanner", availability: .missing),
    ]

    /// A resolved folder at `pathInHome` below the user's home folder.
    static func folder(at pathInHome: String, availability: FolderAvailability) -> ResolvedFolder {
      let path = DisplayPath.userHome + "/" + pathInHome
      return ResolvedFolder(
        reference: FolderReference(bookmark: Data(), lastKnownPath: path),
        url: availability == .available || availability == .stale
          ? URL(filePath: path, directoryHint: .isDirectory) : nil,
        availability: availability)
    }

    /// An inbox at `pathInHome` below the user's home folder, labelled `label`.
    static func inbox(
      at pathInHome: String, label: String? = nil, availability: FolderAvailability
    ) -> ConfiguredInbox {
      let folder = folder(at: pathInHome, availability: availability)
      return ConfiguredInbox(
        inbox: InboxFolder(label: label, folder: folder.reference), folder: folder)
    }
  }
#endif
