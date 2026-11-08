import Foundation

/// A file name split into the part the name field edits and the extension shown as a fixed label after it.
///
/// Follows the core's rule (`FileNaming`): the extension is the text after the last `.` when that text is not empty,
/// contains no whitespace and the part before the dot is not empty. So `scan.pdf` splits into `scan` and `pdf`, while
/// `v1.2 Rechnung` has no extension.
nonisolated struct FileNameParts: Hashable, Sendable {
  /// The name without its extension and the dot before it.
  let stem: String
  /// The extension without its dot; `nil` when the name has none.
  let fileExtension: String?

  /// The parts of `name`.
  init(_ name: String) {
    if let dot = name.lastIndex(of: "."), dot != name.startIndex {
      let candidate = name[name.index(after: dot)...]
      if !candidate.isEmpty, !candidate.contains(where: \.isWhitespace) {
        stem = String(name[..<dot])
        fileExtension = String(candidate)
        return
      }
    }
    stem = name
    fileExtension = nil
  }
}
