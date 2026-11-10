import DocsortCore

/// # Destination picker: the contract with the filing panel
///
/// The picker lets the user find, browse or create the folder a file is filed into, entirely by keyboard
/// (`docs/design/ux.md`, "Destination picker", "New folder", "Folder contents", "Keyboard map"). It is three pieces:
///
/// - ``DestinationPickerModel``: `@Observable`, main actor, one per filing panel. All picker state and every intent.
/// - ``DestinationPickerView``: the search field, the folder list and the New Folder button. Place it in the panel
///   where the spec puts "Destination picker".
/// - ``FolderContentsView``: the files in the chosen or highlighted folder. Place it below the picker, where the spec
///   puts "Folder contents". Both views read the same model.
///
/// ## Inputs (the panel sets them; the model never reads settings, preferences or the disk itself)
///
/// - ``DestinationPickerModel/index``: the archive's `DestinationIndex`, or `nil` while it is being built. While it
///   is `nil` the field reads "Indexing archive…", Recent stays usable, and typing finds nothing yet. Set a new index
///   after every rebuild (for example after a move created a pending folder); the highlight and the chosen
///   destination are kept where their folders still exist.
/// - ``DestinationPickerModel/isRebuildingIndex``: whether the index is being rebuilt while the current one stays in
///   use. The footer's refresh button shows progress meanwhile.
/// - ``DestinationPickerModel/recents``: the recent destinations, most recent first. At the root with an empty
///   filter they are listed first (up to 20); search boosts them.
/// - ``DestinationPickerModel/ranking``: the user's "Rank first" setting.
/// - The model's initialiser takes a ``FolderFileListing``, the service that lists a folder's files off the main
///   actor (inject a fake in tests).
/// - ``DestinationPickerModel/reset(choosing:)``: call it whenever the selected inbox file changes. It returns to the
///   archive root with an empty filter, drops pending new folders and cancels a new-folder row. Pass the folder a
///   filed file is in to show it as already chosen. The highlight starts on that folder, else on the first row (the
///   top of Recent), and stays there when new inputs arrive before the user changes the picker, so the folder a
///   move just used is highlighted however its recents and the reset are ordered.
///
/// ## Output
///
/// State the panel reads at any time:
/// - ``DestinationPickerModel/destination``: the chosen ``PickerDestination``, `nil` until the user chooses one.
///   Typing in the filter or moving the highlight un-chooses it again.
/// - ``DestinationPickerModel/destinationPath``: the chosen destination, else the highlighted folder, for the panel's
///   destination line; a click on one of its segments calls ``DestinationPickerModel/jump(to:)``.
/// - ``DestinationPickerModel/highlightedDestination``: the folder under the highlight, for ⌘Return from the picker.
/// - ``DestinationPickerModel/destinationFolderURL``: where the destination line's folder is on disk, `nil` for a
///   pending new folder, for File › Open Destination in Finder.
/// - ``DestinationPickerModel/contents``: the files listed in Folder contents, alphabetical, so the name field's
///   ⌥↑ / ⌥↓ can walk them.
///
/// Events, through ``DestinationPickerModel/onEvent`` (set it once, when the panel creates the model):
/// - ``PickerEvent/chose(_:)``: Tab or Return (or a double-click) chose a destination. Move focus to the name field.
/// - ``PickerEvent/moveRequested(_:)``: ⌘Return in the picker (or in its new-folder row). The destination is already
///   chosen; move the file now with the pre-filled name.
/// - ``PickerEvent/steppedBack``: ⇧Tab, or Esc with nothing left to clear. Move focus back to the sidebar.
/// - ``PickerEvent/tookFileName(_:)``: the user used a file's name in Folder contents (a double-click, Return on the
///   selected file, or Use Name in its menu). The payload is the file's full name as on disk
///   (`2033-10-04 Rechnung Oktober.pdf`); put its name without extension into the name field, selected, and focus it.
/// - ``PickerEvent/renameFileRequested(_:to:)``: Rename… in a Folder contents file's menu. The name is as entered,
///   without the extension the file keeps; rename the archive file, then call
///   ``DestinationPickerModel/reloadContents(selecting:)``.
/// - ``PickerEvent/trashFileRequested(_:)``: Move to Trash in a Folder contents file's menu; trash the archive file,
///   then reload the contents.
/// - ``PickerEvent/refreshRequested``: the user clicked the footer's refresh button. Rebuild the archive index and
///   set the new one when it is ready.
///
/// A ``PickerDestination/newFolder(_:)`` destination does not exist on disk. `FileOperations.move(_:into:named:...)`
/// creates every missing folder of `index.url(for: destination.path)` when the file is moved (and its undo removes
/// them again), so the panel needs nothing else; cancelling leaves nothing behind.
///
/// ## Focus
///
/// The picker has two text fields: the filter and, while a new folder is being named, the inline name row. The panel
/// owns focus: it passes its `@FocusState` binding and maps ``PickerField`` into its own focus enum, for example
/// `case picker(PickerField)`. The picker moves focus between its two fields itself; it never moves focus elsewhere,
/// it sends ``PickerEvent/chose(_:)``, ``PickerEvent/moveRequested(_:)`` or ``PickerEvent/steppedBack`` instead.
///
/// - Entry from the sidebar by typing: call ``DestinationPickerModel/enter(typing:)`` with the typed text, then focus
///   `.filter`. The field receives the typed text once it has focus, as if typed there. Entry with Tab, Return or
///   ⌘L: just focus `.filter`; it selects its text as text fields do.
/// - Entry back from the name field (⇧Tab, Esc): focus `.filter`. The chosen destination stays until the user types
///   or moves the highlight.
///
/// ## Keys the picker handles while one of its fields is focused
///
/// ↑ ↓ highlight · → into the highlighted folder (caret at the end) · ← or ⌫ out (empty filter) · ⌘↑ archive root ·
/// Tab / Return choose · ⇧Tab back · Esc clear, then back · ⇧⌘N new folder · ⌘Return choose and move. In the
/// new-folder row: Tab / Return confirm · Esc / ⇧Tab cancel · ⌘Return confirm and move.
///
/// If the app's menu binds ⌘Return (File › Move) or ⇧⌘N (File › New Folder…), the menu sees the key before the
/// picker does. Its action must then call ``DestinationPickerModel/requestMove()`` or
/// ``DestinationPickerModel/beginNewFolder()`` while the picker has focus.
enum PickerContract {}

/// Where the user chose to file: an archive-relative folder path, never the archive root itself.
enum PickerDestination: Hashable, Sendable {
  /// A folder that exists in the index.
  case folder(String)
  /// A folder the user named in the picker that does not exist yet; its missing folders are created by the move.
  /// The path may hold several new levels (`Reisen/2033-11 Besuch Westerholm/Bahn`).
  case newFolder(String)

  /// The archive-relative path to file into, for `DestinationIndex.url(for:)`.
  var path: String {
    switch self {
    case .folder(let path), .newFolder(let path): path
    }
  }

  /// Whether the folder does not exist yet.
  var isNew: Bool {
    if case .newFolder = self { return true }
    return false
  }
}

/// What the picker tells the filing panel; see ``PickerContract``.
enum PickerEvent: Hashable, Sendable {
  /// The user chose a destination with Tab, Return or a double-click; focus belongs in the name field now.
  case chose(PickerDestination)
  /// The user pressed ⌘Return in the picker: the destination is chosen, move the file now.
  case moveRequested(PickerDestination)
  /// The user stepped back out of the picker (⇧Tab, or Esc with an empty filter); focus belongs in the sidebar.
  case steppedBack
  /// The user used a file's name in Folder contents (double-click, Return, Use Name); the payload is its full name.
  case tookFileName(String)
  /// The user asked to rename the archive file `file` to `name` (entered without its extension).
  case renameFileRequested(FolderFile, to: String)
  /// The user asked to move the archive file `file` to the Trash.
  case trashFileRequested(FolderFile)
  /// The user clicked the refresh button: rebuild the archive index, for folders created outside docsort.
  case refreshRequested
}

/// The picker's focusable text fields, for the panel's focus state.
enum PickerField: Hashable, Sendable {
  /// The destination filter.
  case filter
  /// The inline name field of a new folder.
  case newFolderName
}
