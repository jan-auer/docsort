import DocsortCore
import SwiftUI

/// What the Folders pane shows, as plain values.
enum FoldersPaneContent {
  /// The folders can be edited: the archive root (`nil` until chosen), its index status, and the inboxes.
  case editable(
    archiveRoot: ResolvedFolder?, indexStatus: ArchiveIndexStatus, inboxes: [ConfiguredInbox])
  /// The stored folder settings could not be read; `message` says why.
  case unreadable(message: String)

  /// The content for the app's folder and archive libraries.
  init(folders: FolderLibrary, archive: ArchiveLibrary) {
    if let error = folders.settingsReadError {
      self = .unreadable(message: error.description)
    } else {
      self = .editable(
        archiveRoot: folders.archiveRoot, indexStatus: archive.status, inboxes: folders.inboxes)
    }
  }
}

/// The Folders pane of the Settings window: the archive folder and the inbox table, or, when the folder settings
/// cannot be read, the error and **Reset Folder Settings…**. Changes apply immediately.
struct FoldersSettingsPane: View {
  /// What to show.
  let content: FoldersPaneContent
  /// What the controls do.
  let actions: FolderSettingsActions

  var body: some View {
    Group {
      switch content {
      case .editable(let archiveRoot, let indexStatus, let inboxes):
        VStack(alignment: .leading, spacing: 20) {
          ArchiveFolderSection(
            archiveRoot: archiveRoot, indexStatus: indexStatus,
            chooseArchiveRoot: actions.chooseArchiveRoot)
          InboxesSection(inboxes: inboxes, actions: actions)
        }
      case .unreadable(let message):
        UnreadableFolderSettingsView(message: message, reset: actions.resetFolderSettings)
      }
    }
    .padding(20)
    .frame(width: 640, alignment: .topLeading)
  }
}

/// The archive folder's path, status and folder count, with **Choose…**.
private struct ArchiveFolderSection: View {
  let archiveRoot: ResolvedFolder?
  let indexStatus: ArchiveIndexStatus
  let chooseArchiveRoot: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Archive folder")
        .font(.headline)
      HStack(spacing: 8) {
        Image(systemName: "folder")
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        Text(archiveRoot?.displayPath ?? "Not chosen")
          .foregroundStyle(archiveRoot == nil ? .secondary : .primary)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(archiveRoot?.reference.lastKnownPath ?? "")
          .accessibilityIdentifier("settings-archive-path")
        Spacer(minLength: 12)
        Button("Choose…", action: chooseArchiveRoot)
          .accessibilityIdentifier("settings-archive-choose")
      }
      if let archiveRoot, archiveRoot.availability.needsAttention {
        Label(
          archiveRoot.availability.settingsStatusText, systemImage: "exclamationmark.triangle.fill"
        )
        .symbolRenderingMode(.multicolor)
        .accessibilityIdentifier("settings-archive-status")
      }
      indexLine
    }
  }

  @ViewBuilder private var indexLine: some View {
    switch indexStatus {
    case .unavailable:
      EmptyView()
    case .indexing:
      Text("Indexing archive…")
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("settings-archive-count")
    case .ready(let folderCount, let problems):
      Text("^[\(folderCount) folder](inflect: true)")
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("settings-archive-count")
      let linkCount = problems.count { $0.kind == .symbolicLink }
      if linkCount > 0 {
        Text(
          "Symbolic links are not followed (^[\(linkCount) link](inflect: true) in the archive folder)."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("settings-archive-links")
      }
    case .failed(let reason):
      Text("The archive could not be indexed: \(reason)")
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("settings-archive-count")
    }
  }
}

/// The inbox table with **+** and **−** below it, and the footnote.
private struct InboxesSection: View {
  let inboxes: [ConfiguredInbox]
  let actions: FolderSettingsActions

  @State private var selection: InboxFolder.ID?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Inboxes")
        .font(.headline)
      InboxTable(inboxes: inboxes, selection: $selection, actions: actions)
        .frame(height: 170)
      HStack(spacing: 0) {
        Button {
          actions.addInbox()
        } label: {
          Image(systemName: "plus")
            .frame(width: 22, height: 18)
        }
        .help("Add an inbox folder")
        .accessibilityLabel("Add Inbox")
        .accessibilityIdentifier("settings-inbox-add")
        Button {
          if let selection {
            actions.removeInbox(selection)
            self.selection = nil
          }
        } label: {
          Image(systemName: "minus")
            .frame(width: 22, height: 18)
        }
        .help("Remove the selected inbox; its files are not touched")
        .accessibilityLabel("Remove Inbox")
        .accessibilityIdentifier("settings-inbox-remove")
        .disabled(selection == nil)
      }
      .buttonStyle(.borderless)
      Text("Inbox folders inside the archive folder are left out of destination search.")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }
}

/// Shown instead of the folder controls when the stored folder settings cannot be read.
private struct UnreadableFolderSettingsView: View {
  let message: String
  let reset: () -> Void

  @State private var isConfirmingReset = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(
        "Docsort could not read its folder settings.", systemImage: "exclamationmark.triangle.fill"
      )
      .symbolRenderingMode(.multicolor)
      .font(.headline)
      Text(message)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
      Text("They are left as they are. Reset them to choose the archive and inbox folders again.")
      Button("Reset Folder Settings…") {
        isConfirmingReset = true
      }
      .accessibilityIdentifier("settings-reset-folders")
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("settings-folders-unreadable")
    .alert("Reset the folder settings?", isPresented: $isConfirmingReset) {
      Button("Reset", role: .destructive, action: reset)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Docsort forgets the archive folder and the inboxes. No files are changed.")
    }
  }
}

#if DEBUG
  #Preview("Configured") {
    FoldersSettingsPane(
      content: .editable(
        archiveRoot: SampleFolders.archiveRoot,
        indexStatus: .ready(folderCount: 576, problems: []),
        inboxes: SampleFolders.inboxes),
      actions: .none)
  }

  #Preview("Indexing, inbox not found") {
    FoldersSettingsPane(
      content: .editable(
        archiveRoot: SampleFolders.archiveRoot, indexStatus: .indexing,
        inboxes: SampleFolders.inboxesWithProblems),
      actions: .none)
  }

  #Preview("Archive not found") {
    FoldersSettingsPane(
      content: .editable(
        archiveRoot: SampleFolders.missingArchiveRoot, indexStatus: .unavailable,
        inboxes: SampleFolders.inboxes),
      actions: .none)
  }

  #Preview("First launch") {
    FoldersSettingsPane(
      content: .editable(archiveRoot: nil, indexStatus: .unavailable, inboxes: []),
      actions: .none)
  }

  #Preview("Unreadable settings") {
    FoldersSettingsPane(
      content: .unreadable(
        message:
          "The preference \"folderSettings\" could not be decoded: The given data was not valid JSON."
      ),
      actions: .none)
  }
#endif
