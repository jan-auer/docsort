import Foundation

/// String operations on archive-relative folder paths (`Reisen/2033-06 Wanderwoche Hochalm`, `""` for the archive
/// root), for folders that may not be in the index yet, such as pending new folders.
enum ArchivePath {
  /// The title the picker shows for the archive root.
  static let rootTitle = "Archive"

  /// The segments of `path`; empty for the root.
  static func segments(of path: String) -> [String] {
    path.split(separator: "/").map(String.init)
  }

  /// The folder containing `path`: `""` for a top-level folder and for the root itself.
  static func parent(of path: String) -> String {
    guard let slash = path.lastIndex(of: "/") else { return "" }
    return String(path[..<slash])
  }

  /// The folder's own name, its last segment; ``rootTitle`` for the root.
  static func title(of path: String) -> String {
    segments(of: path).last ?? rootTitle
  }

  /// The folder's whole path as the picker shows it: `Gesundheit › Konrad`; ``rootTitle`` for the root.
  static func breadcrumb(of path: String) -> String {
    path.isEmpty ? rootTitle : segments(of: path).joined(separator: " › ")
  }

  /// `name` (one or more segments) inside `parent`.
  static func joining(_ parent: String, _ name: String) -> String {
    parent.isEmpty ? name : "\(parent)/\(name)"
  }

  /// `path` relative to `ancestor`, or `nil` when `path` does not lie strictly inside it. Every path lies inside the
  /// root.
  static func relative(_ path: String, to ancestor: String) -> String? {
    if ancestor.isEmpty { return path.isEmpty ? nil : path }
    let prefix = ancestor + "/"
    guard path.hasPrefix(prefix), path.count > prefix.count else { return nil }
    return String(path.dropFirst(prefix.count))
  }
}
