import DocsortCore
import Foundation

/// Lists the files directly inside an archive folder for the picker's Folder contents, off the main actor.
///
/// The picker model reads the disk only through this service, so tests can inject a fake.
nonisolated protocol FolderFileListing: Sendable {
  /// The visible files and packages directly in the folder at `folder` (archive-relative, `""` for the root) of
  /// `index`'s archive, in the order Folder contents shows them.
  ///
  /// - Throws: ``FolderAccessError`` when the folder is missing, is not a folder, or cannot be listed.
  func files(in folder: String, of index: DestinationIndex) async throws(FolderAccessError)
    -> [FolderFile]
}

/// Lists a folder's files from the archive on disk, in Finder name order (``DestinationIndex/files(in:)``).
nonisolated struct ArchiveFolderFileListing: FolderFileListing {
  /// Reads the folder on a background thread.
  @concurrent
  func files(in folder: String, of index: DestinationIndex) async throws(FolderAccessError)
    -> [FolderFile]
  {
    try index.files(in: folder)
  }
}
