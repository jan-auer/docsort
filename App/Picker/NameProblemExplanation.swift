import DocsortCore

extension NameProblem {
  /// Why a typed folder name cannot be used, in plain words for the picker's create row and new-folder row.
  var folderNameExplanation: String {
    switch self {
    case .empty:
      "Type a folder name."
    case .reservedName:
      "“.” and “..” cannot be folder names."
    case .leadingDot:
      "A folder name cannot start with “.”, which would hide the folder in Finder."
    case .forbiddenCharacter(let character):
      "A folder name cannot contain “\(character)”."
    case .tooLong(let byteCount):
      "The name is too long (\(byteCount) bytes; at most \(FileNaming.maximumNameByteCount))."
    }
  }
}
