import DocsortCore
import Foundation

/// The inline row in which the user names a new folder (⇧⌘N or the New Folder button).
struct NewFolderDraft: Hashable {
  /// The archive-relative folder the new folder goes into, `""` for the root.
  let parent: String
  /// The typed name; a slash separates nested folders.
  var name: String
  /// What the row says about the name, `nil` for the default hint ("Return or Tab confirms · Esc cancels").
  var notice: NewFolderNotice?
}

/// What the new-folder row says about the typed name.
enum NewFolderNotice: Hashable {
  /// A component of the name cannot be a folder name; confirming does nothing.
  case invalid(NameProblem)
  /// The folder exists already (ignoring case): "“Reisen” already contains a folder named “…”. Return selects it."
  /// `parentTitle` is ``ArchivePath/rootTitle`` at the root; `existingName` is the existing spelling, relative to the
  /// parent.
  case existing(parentTitle: String, existingName: String)
  /// The name has several components, which become nested folders: "Creates A › B". The components are in the
  /// spelling the folders will have (existing ones as they are).
  case nested([String])
}

/// A typed folder name (`2033-11 Besuch Westerholm / Bahn`) as the components it creates, and how it resolves
/// against the folders that exist or are pending.
struct NewFolderPath {
  /// The typed components: split at `/`, each trimmed, empty ones dropped.
  let components: [String]

  init(typed text: String) {
    components = text.split(separator: "/", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  /// The tidied name: the components joined with `/`; empty when nothing but slashes and spaces was typed.
  var name: String { components.joined(separator: "/") }

  /// Why the first invalid component cannot be a folder name, `nil` when all can.
  var problem: NameProblem? {
    components.lazy.compactMap(FileNaming.validationProblem(for:)).first
  }

  /// The destination the name gives inside `parent`, `nil` when it has no components.
  ///
  /// Each component in turn is matched against the existing subfolders and the pending folders, ignoring case, and
  /// takes the existing spelling; the first component that matches nothing and everything below it are new. When
  /// every component is an indexed folder the result is that ``PickerDestination/folder(_:)``, otherwise a
  /// ``PickerDestination/newFolder(_:)``.
  func resolved(under parent: String, index: DestinationIndex?, pendingFolders: [String])
    -> PickerDestination?
  {
    guard !components.isEmpty else { return nil }
    var path = parent
    var existsInIndex = true
    var isMatching = true
    for component in components {
      if isMatching,
        let existing = Self.existingChild(
          named: component, of: path, index: index, pendingFolders: pendingFolders)
      {
        path = ArchivePath.joining(path, existing)
        existsInIndex = existsInIndex && index?.contains(path) == true
      } else {
        isMatching = false
        existsInIndex = false
        path = ArchivePath.joining(path, component)
      }
    }
    return existsInIndex ? .folder(path) : .newFolder(path)
  }

  /// The name of the indexed or pending child of `parent` named `name` ignoring case, in its own spelling.
  private static func existingChild(
    named name: String, of parent: String, index: DestinationIndex?, pendingFolders: [String]
  ) -> String? {
    let indexedNames = (index?.subfolders(of: parent) ?? []).map(ArchivePath.title(of:))
    let pendingNames = pendingFolders.compactMap { path in
      ArchivePath.relative(path, to: parent).flatMap { ArchivePath.segments(of: $0).first }
    }
    let folded = name.precomposedStringWithCanonicalMapping
    return (indexedNames + pendingNames).first { candidate in
      candidate.precomposedStringWithCanonicalMapping.caseInsensitiveCompare(folded) == .orderedSame
    }
  }
}
