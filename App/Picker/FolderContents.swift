import DocsortCore
import Foundation

/// What Folder contents shows: the files in the chosen destination, else in the highlighted folder.
enum FolderContents: Equatable {
  /// No folder is chosen or highlighted (or the archive is still being indexed).
  case none
  /// The folder is a new one that does not exist on disk yet: "docsort creates the new folder when you move the
  /// file, so cancelling leaves nothing behind."
  case notOnDisk
  /// The files of the archive-relative `folder` are being listed.
  case loading(folder: String)
  /// The files directly in `folder`, alphabetically.
  case files(folder: String, [FolderFile])
  /// Listing `folder` failed; `message` says why, in words for the user.
  case failed(folder: String, message: String)

  /// The user-facing reason a folder could not be listed.
  static func message(for error: FolderAccessError) -> String {
    switch error {
    case .notFound: "The folder no longer exists."
    case .notAFolder: "This is not a folder."
    case .unreadable(_, let reason): "The folder could not be read: \(reason)"
    }
  }
}

extension FolderContents {
  /// The archive-relative folder the contents are about, if a folder on disk.
  var folder: String? {
    switch self {
    case .none, .notOnDisk: nil
    case .loading(let folder), .files(let folder, _), .failed(let folder, _): folder
    }
  }

  /// The folder whose files are listed; `nil` unless the contents are ``files(folder:_:)``.
  var listedFolder: String? {
    if case .files(let folder, _) = self { return folder }
    return nil
  }
}
