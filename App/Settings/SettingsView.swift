import SwiftUI

/// The content of the Settings window, opened with ⌘, from the app menu: the Folders and Search panes.
struct SettingsView: View {
  /// The configured folders, edited in the Folders pane.
  let folders: FolderLibrary
  /// The archive index, whose folder count the Folders pane shows.
  let archive: ArchiveLibrary
  /// The search settings, edited in the Search pane.
  @Bindable var search: SearchSettings

  var body: some View {
    TabView {
      Tab("Folders", systemImage: "folder") {
        FoldersSettingsPane(
          content: FoldersPaneContent(folders: folders, archive: archive),
          actions: FolderSettingsActions(folders: folders))
      }
      .accessibilityIdentifier("settings-folders-tab")
      Tab("Search", systemImage: "magnifyingglass") {
        SearchSettingsPane(ranking: $search.ranking)
      }
      .accessibilityIdentifier("settings-search-tab")
    }
    .folderSettingsAlert(for: folders)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("settings-window")
  }
}

#if DEBUG
  #Preview {
    let environment = AppEnvironment.inert(named: "previews")
    SettingsView(
      folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes),
      archive: ArchiveLibrary(),
      search: SearchSettings(defaults: environment.defaults))
  }
#endif
