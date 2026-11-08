import Foundation

/// Why a name cannot be used for a file or folder in the archive.
public enum NameProblem: Hashable, Sendable {
  /// The name is empty or only whitespace.
  case empty
  /// The name is `.` or `..`, which the file system reserves.
  case reservedName
  /// The name starts with `.`, which would hide the item in Finder.
  case leadingDot
  /// The name contains a character macOS file names cannot hold (`/`, `:` or NUL).
  case forbiddenCharacter(Character)
  /// The name is longer than the 255 UTF-8 bytes a file name may have.
  case tooLong(byteCount: Int)
}

/// Rules for the names files get when they are filed: building the final name from what the user typed, validating
/// it, and choosing a free "Keep Both" name.
///
/// An extension is the text after the last `.` when that text is not empty, contains no whitespace and the part
/// before the dot is not empty. So `scan.pdf` has the extension `pdf`, while `v1.2 Rechnung`, `.hidden` and
/// `trailing.` have none.
public enum FileNaming {
  /// The most UTF-8 bytes a single file name may have on APFS and HFS+.
  public static let maximumNameByteCount = 255

  private static let forbiddenCharacters: Set<Character> = ["/", ":", "\u{0}"]

  /// Builds the name a file is filed under from the name the user entered.
  ///
  /// The entered text is trimmed; an empty result keeps `originalName` unchanged. Otherwise the original extension
  /// (with its original case) is appended, unless the entered text already ends with that extension in any case, in
  /// which case the typed extension is replaced by the original one. The result is not validated; pass it to
  /// ``validationProblem(for:)``.
  public static func finalName(entered: String, originalName: String) -> String {
    let trimmed = entered.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return originalName }
    guard let originalExtension = NameParts(originalName).fileExtension else { return trimmed }

    let enteredParts = NameParts(trimmed)
    if let enteredExtension = enteredParts.fileExtension,
      enteredExtension.caseInsensitiveCompare(originalExtension) == .orderedSame
    {
      return "\(enteredParts.stem).\(originalExtension)"
    }
    return "\(trimmed).\(originalExtension)"
  }

  /// The first reason `name` cannot be used as a file or folder name, or `nil` when it can.
  public static func validationProblem(for name: String) -> NameProblem? {
    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .empty }
    if name == "." || name == ".." { return .reservedName }
    if name.hasPrefix(".") { return .leadingDot }
    if let forbidden = name.first(where: forbiddenCharacters.contains) {
      return .forbiddenCharacter(forbidden)
    }
    let byteCount = name.utf8.count
    if byteCount > maximumNameByteCount { return .tooLong(byteCount: byteCount) }
    return nil
  }

  /// A name for keeping both items when `name` is taken: `name` itself when it is free, otherwise `Name 2.pdf`,
  /// `Name 3.pdf`, … (the number goes before the extension, or at the end when there is none).
  ///
  /// `isTaken` decides whether a candidate collides; pass a check that is case- and normalisation-insensitive when
  /// the target volume is.
  public static func keepBothName(for name: String, isTaken: (String) -> Bool) -> String {
    guard isTaken(name) else { return name }
    let parts = NameParts(name)
    var number = 2
    while true {
      let candidate =
        if let fileExtension = parts.fileExtension {
          "\(parts.stem) \(number).\(fileExtension)"
        } else {
          "\(parts.stem) \(number)"
        }
      if !isTaken(candidate) { return candidate }
      number += 1
    }
  }
}

/// A file name split into stem and extension, by the rule documented on ``FileNaming``.
struct NameParts {
  let stem: String
  let fileExtension: String?

  init(_ name: String) {
    guard let dot = name.lastIndex(of: "."), dot != name.startIndex else {
      stem = name
      fileExtension = nil
      return
    }
    let candidate = name[name.index(after: dot)...]
    if candidate.isEmpty || candidate.contains(where: \.isWhitespace) {
      stem = name
      fileExtension = nil
    } else {
      stem = String(name[..<dot])
      fileExtension = String(candidate)
    }
  }
}
