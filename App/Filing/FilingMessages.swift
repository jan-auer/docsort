import DocsortCore
import Foundation

/// The sentences the window shows for filing errors and name problems. The services return values; this is where
/// they are worded.
enum FilingMessages {
  /// Why a filing operation failed, as a sentence for the user.
  static func text(for error: FilingError) -> String {
    switch error {
    case .historyUnreadable(let storeError):
      "The filing history can’t be read: \(storeError.description)"
    case .fileOperation(let operationError):
      text(for: operationError)
    case .undoRefused(let historyError):
      text(for: historyError)
    case .setAsideFailed(let url, let reason):
      "The filing history “\(url.lastPathComponent)” could not be set aside: \(reason)"
    case .noHistoryRecord(let url):
      "The filing history has no record of how “\(url.lastPathComponent)” got to \(path(of: url.deletingLastPathComponent()))."
    }
  }

  /// Why a file operation failed.
  static func text(for error: FileOperationError) -> String {
    switch error {
    case .nameConflict(let existing):
      "“\(existing.lastPathComponent)” already exists in this folder."
    case .replaceKindMismatch(let existing):
      "“\(existing.lastPathComponent)” can’t be replaced: one is a folder and the other a file."
    case .sourceMissing(let url):
      "“\(url.lastPathComponent)” is no longer there."
    case .invalidName(let name, let problem):
      "“\(name)” can’t be used: \(text(for: problem))"
    case .originalLocationTaken(let url):
      "Something else is now at \(path(of: url)), so the file can’t be put back."
    case .notInTrash(let url):
      "“\(url.lastPathComponent)” is no longer in the Trash."
    case .differentItem(let url):
      "The item at \(path(of: url)) is not the one docsort moved; it was replaced or changed since."
    case .originalChangedDuringCopy(let original, let copy, _):
      "The file changed while it was copied, so both were kept: \(path(of: original)) and \(path(of: copy))."
    case .failed(let operation, let url, let reason):
      "Could not \(operation) “\(url.lastPathComponent)”: \(reason)"
    }
  }

  /// Why the history refuses an undo.
  static func text(for error: FilingHistoryError) -> String {
    switch error {
    case .unknownEvent:
      "The filing history has no record of this action."
    case .alreadyUndone:
      "This action was already undone."
    case .laterEventActive:
      "This file was moved again later; undo that first."
    case .resultHeldByOtherDocument:
      "Another file is now where this one was moved to."
    case .undoneWithMove:
      "This file was replaced by a move; undo that move instead."
    }
  }

  /// Why a name can't be used, completing "… can't be used: ".
  static func text(for problem: NameProblem) -> String {
    switch problem {
    case .empty:
      "the name is empty."
    case .reservedName:
      "the name is reserved by the system."
    case .leadingDot:
      "a name starting with “.” would hide the file."
    case .forbiddenCharacter(let character):
      "names can’t contain “\(character)”."
    case .tooLong(let byteCount):
      "the name is \(byteCount - FileNaming.maximumNameByteCount) bytes too long."
    }
  }

  private static func path(of url: URL) -> String {
    DisplayPath.abbreviating(url.path(percentEncoded: false))
  }
}
