import DocsortCore
import Foundation
import OSLog

/// Folder contents (``DestinationPickerModel/contents``): which folder it follows, listing it, and the file
/// selection with its intents.
extension DestinationPickerModel {
  /// The file selected in Folder contents, if it is listed.
  var selectedContentsFile: FolderFile? {
    guard let selectedContentsFileURL else { return nil }
    return contents.files.first { $0.url == selectedContentsFileURL }
  }

  /// A click on a file in Folder contents: selects it, as in Finder; its name is used only by
  /// ``useSelectedContentsFileName()`` or ``takeFileName(_:)``.
  func selectContentsFile(_ file: FolderFile) {
    selectedContentsFileURL = file.url
  }

  /// ↑ (`-1`) or ↓ (`1`) in Folder contents: moves the selection by `offset` files, stopping at the first and last.
  /// With nothing selected, ↓ selects the first file and ↑ the last (the newest of date-named files).
  func moveContentsSelection(by offset: Int) {
    let files = contents.files
    guard !files.isEmpty, offset != 0 else { return }
    let target: Int
    if let index = files.firstIndex(where: { $0.url == selectedContentsFileURL }) {
      target = (index + offset).clamped(to: 0...files.count - 1)
    } else {
      target = offset > 0 ? 0 : files.count - 1
    }
    selectedContentsFileURL = files[target].url
  }

  /// Return in Folder contents: uses the selected file's name (``PickerEvent/tookFileName(_:)``); nothing without a
  /// selection.
  func useSelectedContentsFileName() {
    guard let file = selectedContentsFile else { return }
    takeFileName(file)
  }

  /// A double-click on a file in Folder contents, or Use Name in its menu: selects it and emits
  /// ``PickerEvent/tookFileName(_:)`` with its full name.
  func takeFileName(_ file: FolderFile) {
    selectedContentsFileURL = file.url
    onEvent(.tookFileName(file.name))
  }

  /// Rename… in a file's menu, once the user entered `name` (without the extension the file keeps): emits
  /// ``PickerEvent/renameFileRequested(_:to:)``.
  func requestRename(of file: FolderFile, to name: String) {
    onEvent(.renameFileRequested(file, to: name))
  }

  /// Move to Trash in a file's menu: emits ``PickerEvent/trashFileRequested(_:)``.
  func requestTrash(of file: FolderFile) {
    onEvent(.trashFileRequested(file))
  }

  /// Lists the shown folder again after its files changed (a rename or a move to the Trash), selecting the file at
  /// `url`. The files stay listed meanwhile; a selection the new listing lacks is dropped.
  func reloadContents(selecting url: URL?) {
    selectedContentsFileURL = url
    contentsTarget = nil
    followContents()
  }

  /// The file that takes `file`'s place in the selection once it is gone: the next file, else the previous one.
  func contentsFile(replacing file: FolderFile) -> FolderFile? {
    let files = contents.files
    guard let index = files.firstIndex(where: { $0.url == file.url }) else { return nil }
    if index + 1 < files.count { return files[index + 1] }
    return index > 0 ? files[index - 1] : nil
  }

  /// What ``contents`` should show.
  enum ContentsTarget: Equatable {
    case none
    case notOnDisk
    case folder(String)
  }

  /// Updates ``contents`` when the folder it follows changed, cancelling a listing still running.
  func followContents() {
    let target = currentContentsTarget
    guard target != contentsTarget else { return }
    // Listing the same folder again keeps the selection while its file is still listed.
    if contents.folder.map(ContentsTarget.folder) != target {
      selectedContentsFileURL = nil
    }
    contentsTarget = target
    contentsTask?.cancel()
    contentsTask = nil
    switch target {
    case .none:
      contents = .none
    case .notOnDisk:
      contents = .notOnDisk
    case .folder(let folder):
      loadContents(of: folder)
    }
  }

  /// The folder Folder contents follows: the destination if chosen, else the highlighted folder row.
  private var currentContentsTarget: ContentsTarget {
    if newFolderDraft != nil { return .notOnDisk }
    let path: String
    if let destination {
      if case .newFolder = destination { return .notOnDisk }
      path = destination.path
    } else if let highlightedPath = highlightedRow?.folderPath {
      if pendingFolders.contains(highlightedPath) { return .notOnDisk }
      path = highlightedPath
    } else {
      return .none
    }
    return index == nil ? .none : .folder(path)
  }

  /// Lists `folder` through ``folderFiles`` and shows the result unless a newer listing started meanwhile.
  private func loadContents(of folder: String) {
    guard let index else {
      contents = .none
      return
    }
    contentsLoadNumber += 1
    let loadNumber = contentsLoadNumber
    let listing = folderFiles
    // Listing the folder shown again keeps its files until the new list is ready, so the list does not flash empty.
    if contents.listedFolder != folder {
      contents = .loading(folder: folder)
    }
    contentsTask = Task { [weak self] in
      let result: Result<[FolderFile], FolderAccessError>
      do throws(FolderAccessError) {
        result = .success(try await listing.files(in: folder, of: index))
      } catch {
        Logger.picker.error(
          "Could not list the files in archive folder \(folder) for Folder contents: \(String(describing: error))"
        )
        result = .failure(error)
      }
      guard let self, loadNumber == self.contentsLoadNumber else { return }
      switch result {
      case .success(let files):
        self.contents = .files(folder: folder, files)
        if let selected = self.selectedContentsFileURL,
          !files.contains(where: { $0.url == selected })
        {
          self.selectedContentsFileURL = nil
        }
      case .failure(let error):
        self.contents = .failed(folder: folder, message: FolderContents.message(for: error))
        self.selectedContentsFileURL = nil
      }
    }
  }
}
