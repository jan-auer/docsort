import DocsortCore
import Foundation

/// A group of rows in the picker's list: "Recent" and "All folders" at the archive root, "In <folder>" and "Elsewhere"
/// for a search inside a folder, one untitled section otherwise.
struct PickerSection: Identifiable, Hashable {
  /// Unique among the list's sections; also the prefix of its rows' ids.
  let id: String
  /// The section header ("Recent", "All folders", "In Gesundheit", "Elsewhere"), or `nil` for no header.
  let title: String?
  /// The section's rows, in display order.
  let rows: [PickerRow]
}

/// One row of the picker's list.
struct PickerRow: Identifiable, Hashable {
  /// What a row stands for.
  enum Kind: Hashable {
    /// Inside a folder, the first row: the folder the picker is in ("this folder"), with its archive-relative path.
    case currentFolder(path: String)
    /// An indexed folder or a pending new one.
    case folder(PickerFolder)
    /// "New Folder “name” in parent", offered when a non-empty filter finds nothing. `name` is the tidied filter
    /// (see ``NewFolderPath``), `parent` the scope; `problem` is why the name cannot be used, and choosing the row
    /// then does nothing.
    case createFolder(name: String, parent: String, problem: NameProblem?)
    /// The inline row naming a new folder (see ``DestinationPickerModel/newFolderDraft``); not selectable.
    case newFolderDraft
    /// The info row "Indexing archive…", shown when the user filters before the index is built.
    case indexing
    /// The info row under "In <folder>" when a search finds nothing in the folder `scope` but matches elsewhere.
    case nothingInScope(scope: String)
  }

  /// Unique across all sections of the list, stable while the row stands for the same thing.
  let id: String
  /// What the row stands for.
  let kind: Kind

  /// Whether the highlight can rest on the row and choosing it means something.
  var isSelectable: Bool {
    switch kind {
    case .currentFolder, .folder, .createFolder: true
    case .newFolderDraft, .indexing, .nothingInScope: false
    }
  }

  /// The archive-relative folder path the row stands for, if it stands for a folder.
  var folderPath: String? {
    switch kind {
    case .currentFolder(let path): path
    case .folder(let folder): folder.path
    case .createFolder, .newFolderDraft, .indexing, .nothingInScope: nil
    }
  }
}

/// A folder as a row in the picker shows it.
struct PickerFolder: Hashable {
  /// The archive-relative path; the folder a file is filed into.
  let path: String
  /// The path relative to the picker's scope, as the row shows it (the full path in Recent).
  let displayPath: String
  /// The characters of ``displayPath`` the filter matched, for bold highlighting; empty while browsing.
  let matchedRanges: [Range<String.Index>]
  /// Whether the folder has subfolders in the index (the row shows a chevron).
  let hasSubfolders: Bool
  /// Whether the folder is a pending new folder that does not exist on disk yet (the row shows a New badge).
  let isNew: Bool
}

/// The folder a file would be filed into, as the destination line shows it: the chosen destination, else the
/// highlighted folder.
struct DestinationPath: Hashable {
  /// The archive-relative path, never the root.
  let path: String
  /// Whether the folder is chosen (Tab, Return), rather than only highlighted.
  let isChosen: Bool
  /// Whether the folder is a pending new folder.
  let isNew: Bool

  /// `Archive`, then each folder down to the destination, each with the path a click jumps to.
  var segments: [PathSegment] {
    var segments = [PathSegment(title: ArchivePath.rootTitle, path: "")]
    var prefix = ""
    for name in ArchivePath.segments(of: path) {
      prefix = ArchivePath.joining(prefix, name)
      segments.append(PathSegment(title: name, path: prefix))
    }
    return segments
  }
}

/// One segment of the destination line (`Archive › Gesundheit › Konrad`).
struct PathSegment: Identifiable, Hashable {
  /// The segment's label: ``ArchivePath/rootTitle`` for the root, else the folder's name.
  let title: String
  /// The archive-relative path to jump to, `""` for the root.
  let path: String

  var id: String { path }
}
