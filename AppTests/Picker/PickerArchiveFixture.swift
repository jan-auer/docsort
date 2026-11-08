import DocsortCore
import Foundation

@testable import Docsort

/// A small archive on disk for picker tests, built in a fresh temporary directory that is removed with the value.
///
/// Folder and file names come from the fictional sample archive in `docs/design/sample-data/`.
final class PickerArchiveFixture {
  /// The folders the default archive has, parents before children.
  static let defaultFolders = [
    "Gesundheit",
    "Gesundheit/Impfpässe",
    "Gesundheit/Konrad",
    "Gesundheit/Konrad/Physiotherapie",
    "Gesundheit/Konrad/Zahnarzt",
    "Gesundheit/Margit",
    "Gesundheit/Margit/Physiotherapie",
    "Gesundheit/Patientenverfügung",
    "Kommunikation",
    "Kommunikation/Ilmnet Internet",
    "Kommunikation/Ilmnet Internet/Rechnungen",
    "Mobilität",
    "Mobilität/Jahreskarte Regio Plus",
    "Reisen",
    "Reisen/2032-05 Pfingsten Hochalm",
    "Reisen/2033-06 Wanderwoche Hochalm",
    "Reisen/2033-06 Wanderwoche Hochalm/Anreise",
    "Reisen/Reiseplanung Ideen",
  ]

  /// The files the default archive has, by archive-relative path.
  static let defaultFiles = [
    "Kommunikation/Ilmnet Internet/Rechnungen/2033-10-04 Rechnung Oktober.pdf",
    "Kommunikation/Ilmnet Internet/Rechnungen/2033-03-04 Rechnung März.pdf",
    "Kommunikation/Ilmnet Internet/Rechnungen/2033-07-19 Gutschrift Störung.pdf",
    "Mobilität/Jahreskarte Regio Plus/2031-10-18 Jahreskarte Konrad.pdf",
  ]

  /// The archive root.
  let root: URL

  /// An archive with `folders` and `files` (archive-relative paths).
  init(folders: [String] = defaultFolders, files: [String] = defaultFiles) throws {
    root = FileManager.default.temporaryDirectory
      .appending(path: "DocsortPickerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    for folder in folders {
      try createFolder(folder)
    }
    for file in files {
      let url = root.appending(path: file, directoryHint: .notDirectory)
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data("content".utf8).write(to: url)
    }
  }

  deinit {
    // Cleanup of a temporary directory; a leftover folder does not affect any test.
    try? FileManager.default.removeItem(at: root)
  }

  /// Creates the folder at `path` and its missing parents.
  func createFolder(_ path: String) throws {
    try FileManager.default.createDirectory(
      at: root.appending(path: path, directoryHint: .isDirectory), withIntermediateDirectories: true
    )
  }

  /// Removes the folder at `path` with everything inside it.
  func removeFolder(_ path: String) throws {
    try FileManager.default.removeItem(at: root.appending(path: path, directoryHint: .isDirectory))
  }

  /// A fresh index of the archive as it is on disk now.
  func index() throws -> DestinationIndex {
    try DestinationIndex.build(root: root)
  }
}

/// Collects the events a picker model emits.
@MainActor
final class PickerEventLog {
  private(set) var events: [PickerEvent] = []

  /// Starts recording `model`'s events.
  func record(_ model: DestinationPickerModel) {
    model.onEvent = { [weak self] event in self?.events.append(event) }
  }
}

extension DestinationPickerModel {
  /// The rows in order: folder rows by display path (`new:` for pending ones), "this folder" as `this:<path>`, the
  /// create row as `create:<name> in <parent>`, the new-folder row as `draft`.
  var rowSummaries: [String] {
    rows.map { row in
      switch row.kind {
      case .currentFolder(let path): "this:\(path)"
      case .folder(let folder): folder.isNew ? "new:\(folder.displayPath)" : folder.displayPath
      case .createFolder(let name, let parent, _): "create:\(name) in \(parent)"
      case .newFolderDraft: "draft"
      case .indexing: "indexing"
      case .nothingInScope(let scope): "nothing in:\(scope)"
      }
    }
  }

  /// The archive-relative path of the highlighted row, if it stands for a folder.
  var highlightedPath: String? { highlightedRow?.folderPath }

  /// Highlights the first folder row for `path`.
  func highlightFolder(_ path: String) {
    guard
      let row = rows.first(where: { row in
        if case .folder(let folder) = row.kind { return folder.path == path }
        return false
      })
    else { return }
    highlight(row.id)
  }
}
