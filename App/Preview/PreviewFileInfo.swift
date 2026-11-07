import Foundation
import UniformTypeIdentifiers

/// The facts about a file that the preview footer and the "no preview" view show.
nonisolated struct PreviewFileInfo: Equatable, Sendable {
  /// The file's location.
  let url: URL
  /// The file name with its extension, as the archive stores it.
  let name: String
  /// The file's type; `.data` when the system cannot tell.
  let contentType: UTType
  /// The file's size in bytes, when the file system reports one.
  let byteCount: Int64?
  /// When the file was created, when the file system reports it.
  let creationDate: Date?
  /// When the file's content last changed, when the file system reports it.
  let modificationDate: Date?

  /// The type's name as Finder shows it in the Kind column, for example "PDF document".
  var kindDescription: String {
    contentType.localizedDescription ?? contentType.identifier
  }

  /// Reads the file's resource values off the main actor.
  ///
  /// Throws the file system's error, for example `CocoaError.fileReadNoSuchFile` when the file is gone.
  @concurrent static func load(from url: URL) async throws -> PreviewFileInfo {
    var freshURL = url
    // A URL caches resource values; a file that changed since the last read must not show stale facts.
    freshURL.removeAllCachedResourceValues()
    let values = try freshURL.resourceValues(forKeys: [
      .contentTypeKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey,
    ])
    return PreviewFileInfo(
      url: url,
      name: url.lastPathComponent,
      contentType: values.contentType ?? UTType(filenameExtension: url.pathExtension) ?? .data,
      byteCount: values.fileSize.map(Int64.init),
      creationDate: values.creationDate,
      modificationDate: values.contentModificationDate
    )
  }
}

extension Error {
  /// Whether the error says that the file does not exist (any more).
  nonisolated var isFileMissing: Bool {
    if let cocoaError = self as? CocoaError {
      return cocoaError.code == .fileReadNoSuchFile || cocoaError.code == .fileNoSuchFile
    }
    if let posixError = self as? POSIXError {
      return posixError.code == .ENOENT
    }
    return false
  }
}
