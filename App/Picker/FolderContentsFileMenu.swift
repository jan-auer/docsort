import AppKit
import DocsortCore
import SwiftUI

/// The context menu of a file in Folder contents: Use Name, Quick Look, Open, Open With ›, Reveal in Finder, Copy
/// Name, Copy Path, Rename… and Move to Trash. The last two change the archive and are disabled while
/// `canChangeFiles` is false.
struct FolderContentsFileMenu: View {
  let file: FolderFile
  let canChangeFiles: Bool
  let useName: () -> Void
  let quickLook: () -> Void
  let rename: () -> Void
  let trash: () -> Void

  var body: some View {
    Button("Use Name", action: useName)
    Button("Quick Look", action: quickLook)
    Divider()
    Button("Open") { FileActions.open(file.url) }
    openWithMenu
    Button("Reveal in Finder") { FileActions.revealInFinder(file.url) }
    Divider()
    Button("Copy Name") { FileActions.copy(file.name) }
    Button("Copy Path") { FileActions.copy(file.url.path(percentEncoded: false)) }
    Divider()
    Button("Rename…", action: rename)
      .disabled(!canChangeFiles)
    Button("Move to Trash", action: trash)
      .disabled(!canChangeFiles)
  }

  /// Open With ›: the default app first, then the others that open the file, as Finder lists them.
  private var openWithMenu: some View {
    Menu("Open With") {
      let applications = FileActions.applications(toOpen: file.url)
      if applications.isEmpty {
        Text("No Applications")
      }
      ForEach(applications) { application in
        Button {
          FileActions.open(file.url, with: application.url)
        } label: {
          Label {
            Text(application.isDefault ? "\(application.name) (default)" : application.name)
          } icon: {
            Image(nsImage: application.icon)
          }
        }
        if application.isDefault, applications.count > 1 {
          Divider()
        }
      }
    }
  }
}
