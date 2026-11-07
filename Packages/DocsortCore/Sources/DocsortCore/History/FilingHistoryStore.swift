import Foundation

/// Reads and writes the ``FilingHistory`` as a JSON file.
///
/// Guarantees:
/// - A missing file is an empty history; a file that exists but cannot be read or decoded is an error, never an empty
///   history, so the app cannot overwrite a history it failed to read.
/// - Saving writes a new file and replaces the old one in a single step, so the file on disk is always either the
///   old or the new history, never a partial one.
public struct FilingHistoryStore: Sendable {
  /// The JSON file the history is stored in.
  public let fileURL: URL

  /// A store for the history in the file at `fileURL`.
  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  /// `Docsort/FilingHistory.json` in the user's Application Support folder (inside the app's sandbox container when
  /// sandboxed). The folder is not created here; ``save(_:)`` creates it.
  public static func defaultFileURL() -> URL {
    URL.applicationSupportDirectory
      .appending(path: "Docsort", directoryHint: .isDirectory)
      .appending(path: "FilingHistory.json", directoryHint: .notDirectory)
  }

  /// The stored history, or an empty history when the file does not exist.
  ///
  /// Fails with ``FilingHistoryStoreError/readFailed(url:reason:)`` when the file exists but cannot be read,
  /// ``FilingHistoryStoreError/unsupportedVersion(_:url:)`` when it was written in another format version, and
  /// ``FilingHistoryStoreError/corrupt(url:reason:)`` when it is not a filing history.
  public func load() throws(FilingHistoryStoreError) -> FilingHistory {
    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
      return FilingHistory()
    } catch {
      throw .readFailed(url: fileURL, reason: error.localizedDescription)
    }

    let decoder = JSONDecoder()
    let header: FormatHeader
    do {
      header = try decoder.decode(FormatHeader.self, from: data)
    } catch {
      throw .corrupt(url: fileURL, reason: String(describing: error))
    }
    guard header.version == FilingHistory.formatVersion else {
      throw .unsupportedVersion(header.version, url: fileURL)
    }
    do {
      return try decoder.decode(FilingHistory.self, from: data)
    } catch {
      throw .corrupt(url: fileURL, reason: String(describing: error))
    }
  }

  /// Writes `history` to the file, creating its folder when missing, and replaces the previous file atomically.
  ///
  /// When encoding or writing fails, the previously saved file is left unchanged.
  public func save(_ history: FilingHistory) throws(FilingHistoryStoreError) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data: Data
    do {
      data = try encoder.encode(history)
    } catch {
      throw .encodingFailed(url: fileURL, reason: String(describing: error))
    }

    let folder = fileURL.deletingLastPathComponent()
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    } catch {
      throw .writeFailed(
        url: fileURL,
        reason:
          "the folder \(folder.path(percentEncoded: false)) could not be created: \(error.localizedDescription)"
      )
    }
    do {
      try data.write(to: fileURL, options: .atomic)
    } catch {
      throw .writeFailed(url: fileURL, reason: error.localizedDescription)
    }
  }

  /// The part of the stored JSON read before anything else, to tell another format version from a corrupt file.
  private struct FormatHeader: Decodable {
    let version: Int
  }
}

/// Why a ``FilingHistoryStore`` could not load or save the history. Every case names the history file.
public enum FilingHistoryStoreError: Error, Equatable, Sendable, CustomStringConvertible {
  /// The file exists but could not be read.
  case readFailed(url: URL, reason: String)
  /// The file is not a filing history: not JSON, or not of the expected shape.
  case corrupt(url: URL, reason: String)
  /// The file was written in format `version`, which this version of Docsort cannot read.
  case unsupportedVersion(Int, url: URL)
  /// The history could not be encoded; nothing was written.
  case encodingFailed(url: URL, reason: String)
  /// The folder or the file could not be written; the previously saved file is unchanged.
  case writeFailed(url: URL, reason: String)

  /// The history file the failing operation used.
  public var url: URL {
    switch self {
    case .readFailed(let url, _), .corrupt(let url, _), .unsupportedVersion(_, let url),
      .encodingFailed(let url, _), .writeFailed(let url, _):
      url
    }
  }

  /// A message naming the file and the cause, for logs.
  public var description: String {
    let path = url.path(percentEncoded: false)
    return switch self {
    case .readFailed(_, let reason):
      "The filing history \(path) could not be read: \(reason)"
    case .corrupt(_, let reason):
      "The filing history \(path) is corrupt: \(reason)"
    case .unsupportedVersion(let version, _):
      "The filing history \(path) has format version \(version), which this version of Docsort cannot read."
    case .encodingFailed(_, let reason):
      "The filing history for \(path) could not be encoded: \(reason)"
    case .writeFailed(_, let reason):
      "The filing history \(path) could not be written: \(reason)"
    }
  }
}
