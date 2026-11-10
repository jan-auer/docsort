import DocsortCore
import Foundation

/// What a move does to the file.
nonisolated enum MoveKind: Hashable, Sendable {
  /// Files an inbox file into the archive.
  case filing
  /// Renames the filed file, the filing history's document `documentID`, in its folder.
  case renaming(documentID: UUID)
  /// Moves the filed file, the filing history's document `documentID`, on to another folder (and possibly renames
  /// it).
  case refiling(documentID: UUID)

  /// The filing history's document of the filed file that is renamed or moved on; `nil` when filing an inbox file.
  var filedDocumentID: UUID? {
    switch self {
    case .filing: nil
    case .renaming(let documentID), .refiling(let documentID): documentID
    }
  }

  /// Whether the move renames a filed file in its folder.
  var isRenaming: Bool {
    if case .renaming = self { true } else { false }
  }
}

/// A move the user asked for, with everything needed to retry or redo it.
nonisolated struct MoveRequest: Hashable, Sendable {
  /// The file's identity.
  let itemID: InboxItemID
  /// Where the file is now.
  let source: URL
  /// The destination folder.
  let folderURL: URL
  /// The destination's archive-relative path.
  let archivePath: String
  /// The name to file under, with its extension.
  let name: String
  /// The file's inbox name, for the Undo menu item.
  let originalName: String
  /// What the move does to the file.
  let kind: MoveKind
}

/// A Move Back of a filed file to its inbox the user asked for.
nonisolated struct MoveBackRequest: Hashable, Sendable {
  /// The file's identity.
  let itemID: InboxItemID
  /// The filing history's document the row filed; the Move Back refuses unless it is still the file at `url`.
  let documentID: UUID
  /// Where the file is now, in the archive.
  let url: URL
  /// The file's inbox name, for the Undo menu item.
  let originalName: String
  /// The display name of the file's inbox.
  let inboxName: String
}

/// A move to the Trash the user asked for.
nonisolated struct TrashRequest: Hashable, Sendable {
  /// The file's identity.
  let itemID: InboxItemID
  /// Where the file is now.
  let url: URL
  /// The file's inbox name, for the Undo menu item.
  let originalName: String
}

/// A Put Back of a trashed file the user asked for.
nonisolated struct PutBackRequest: Hashable, Sendable {
  /// The file's identity.
  let itemID: InboxItemID
  /// Where the file lies in the Trash.
  let trashedURL: URL
  /// The file's inbox name, for the Undo menu item.
  let originalName: String
}

/// A name conflict waiting for the user's choice between Keep Both, Replace and Cancel.
nonisolated struct FilingConflict: Identifiable, Sendable {
  /// Distinguishes this conflict from the previous one.
  let id = UUID()
  /// The name of the item already in the destination.
  let existingName: String
  /// The move that ran into it.
  let request: MoveRequest
}

/// A Move Back whose inbox name is taken, waiting for the user's choice between Keep Both and Cancel.
nonisolated struct MoveBackConflict: Identifiable, Sendable {
  /// Distinguishes this conflict from the previous one.
  let id = UUID()
  /// The item in the way, at the file's original inbox path.
  let blockingURL: URL
  /// The Move Back that ran into it.
  let request: MoveBackRequest
}

/// What ⌘Return does to the selected filed file, which the bottom button names.
nonisolated enum FiledFileChange: Hashable, Sendable {
  /// Only the name differs: rename it in its folder.
  case rename
  /// The folder differs (or none is chosen): move it on.
  case move
}

/// What returns a handled file to its inbox (File › Move Back to Inbox, ⌥⌘Z, the status strip, the row's menu).
nonisolated enum ReturnToInboxAction: Hashable, Sendable {
  /// A filed file: Move Back.
  case moveBack
  /// A trashed file: Put Back.
  case putBack
}

extension SelectedFile {
  /// What returns the file to its inbox; `nil` while it is unhandled.
  var returnToInboxAction: ReturnToInboxAction? {
    switch mark {
    case .filed: .moveBack
    case .trashed: .putBack
    case nil: nil
    }
  }
}

/// A row with the mark it had before an action that changed it (a Replace sent its filed file to the Trash, or its
/// filed file was renamed or trashed in Folder contents), which undoing the action restores.
nonisolated struct MarkedRow: Sendable {
  /// The row's identity.
  let id: InboxItemID
  /// The row's mark before the Replace.
  let markBefore: InboxItemMark
}

/// A rename of an archive file from Folder contents, with what is needed to redo it.
nonisolated struct ArchiveRenameRequest: Hashable, Sendable {
  /// Where the file was before the rename.
  let source: URL
  /// The new name, with its extension.
  let name: String
  /// The file's name before the rename, for the Undo menu item.
  let originalName: String
}

/// A move to the Trash of an archive file from Folder contents, with what is needed to redo it.
nonisolated struct ArchiveTrashRequest: Hashable, Sendable {
  /// Where the file was.
  let url: URL
  /// The file's name, for the Undo menu item.
  let originalName: String
  /// The file Folder contents selects once the file is gone: the next one, else the previous one.
  let selectionAfter: URL?
}
