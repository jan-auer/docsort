import SwiftUI

extension View {
  /// Shows `folders`' current error (a folder that could not be remembered, settings that could not be saved) as an
  /// alert; dismissing it clears the error.
  ///
  /// Both the Settings window and the main window attach it, because folders are chosen in both (Choose… and
  /// Locate…).
  func folderSettingsAlert(for folders: FolderLibrary) -> some View {
    modifier(FolderSettingsAlertModifier(folders: folders))
  }
}

/// Presents a `FolderLibrary`'s `alert`.
private struct FolderSettingsAlertModifier: ViewModifier {
  let folders: FolderLibrary

  func body(content: Content) -> some View {
    content.alert(
      folders.alert?.title ?? "",
      isPresented: Binding(
        get: { folders.alert != nil },
        set: { isPresented in
          if !isPresented { folders.alert = nil }
        }),
      presenting: folders.alert
    ) { _ in
      Button("OK") {}
    } message: { alert in
      Text(alert.message)
    }
  }
}

#if DEBUG
  #Preview("Folder error") {
    let folders = FolderLibrary.preview(archiveRoot: nil, inboxes: [])
    folders.alert = FolderSettingsAlert(
      title: "Docsort could not remember the folder “Scanner”",
      message: "The file couldn’t be opened because you don’t have permission to view it.")
    return Text("Settings")
      .frame(width: 420, height: 240)
      .folderSettingsAlert(for: folders)
  }
#endif
