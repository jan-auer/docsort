# Backlog

Non-blocking findings and deferred work, collected by the hub. Newest group first.

## From the keyboard shortcuts sheet review (2026-11-09)

- The sidebar's and Folder contents' keys come from `onKeyPress` handlers, so nothing forces a new key there into the
  shortcuts sheet; a key enum per handler with an exhaustive switch (as `PickerKey`) would.
- The sheet's column balancing puts Name Field in the other column from the picker sections.
- ⌘/ does nothing while the History or Settings window is key.
- The menu-command guard is per window sheet (`AttachedSheetTracker`), not per text field: ⌘⌫ in a text field
  outside a sheet (other than the filter and name field) would still trash. None exists today.
- The Rename alert in Folder contents is covered only if SwiftUI presents it as a window sheet, as it does for
  alerts on macOS; not checked with a test.

## From the Folder contents Quick Look review (2026-11-09)

- `FilingService.rename` and `trash` of archive files don't check the item's identity as `refile` does
  (`verifyFiledPlacement`).
- `remark(filedAs:)` in `MainWindowModel+ArchiveFiles.swift` repeats the loop in `applyMarks(of:for:)`, and
  `FilingService.rename` largely repeats `move`.
- Open With asks Launch Services for the apps in the menu's view body (`FolderContentsFileMenu`), which `layering`
  forbids: move it into a service or compute it only when the submenu opens.
- Quick Look doesn't switch lists when the other list is clicked while the panel is open; it moves to the other list
  only through Quick Look in a file's menu.
- The archive rename and trash orchestration in `MainWindowModel+ArchiveFiles.swift` is debt for the `layering` move.
- With Folder contents focused, ⌘O, ⌥⌘R and ⌘⌫ still act on the selected inbox file (the menu sees them first);
  Finder would act on the list's selection.

## From the e2e and picker reviews (2026-11-08)

- Redo doesn't check the item's identity; a failed redo clears the whole filing undo stack; undoing an unfinished redo
  isn't re-registered.
- An item replaced after `originalChangedDuringCopy` (cross-volume Replace) stays in the Trash unrecorded.
- System Trash, and undo of Trash/Replace, never exercised in the sandboxed app (`~/.Trash` access after relaunch).
- Picker: a vanished chosen `.folder` destination isn't dropped; stale focus requests can steal focus when the picker
  reappears; ⌘Return reaches the picker even when Move is disabled; typed new-folder names matching an inbox folder
  inside the archive resolve to that inbox.
- Tests: `FilingService` undo of a move, Replace and its undo, the redo rule, picker integration
  (`handlePickerEvent`, `moveSelectedFile` routing, `rebuild()`).
- Duplicate sample-archive builders (`PickerSampleArchive` in App, `PickerArchiveFixture` in AppTests).
- File order of folder contents: the core returns newest first, the spec wants alphabetical; decide in one place.
- Undo/redo orchestration lives in a view-model extension; move it into the core in the architecture cleanup.
- `.docsort-*.partial` leftovers from interrupted cross-volume copies aren't cleaned up.

## Deferred features

- (Done 2026-11-08: live folder watching in the app.)
- (Done 2026-11-08: History window, status strips, Move Back / Put Back, revert name.)
- Date shortcuts in the name field (`deferred-and-wanted-features`).
- Ideas from the layout research (report on local branch `claude/layout-research-068c21`): a ⌘K command palette,
  open Finder windows and pinned folders as destinations, a focus-preview toggle, suggestion chips with per-source
  defaults.
- Write-ahead filing history (record a pending event before moving), only if a save failure ever bites.

## From the filing-extras review (2026-11-08)

- Put Back into a taken inbox name only shows an error; the spec wants Keep Both / Cancel (needs core support in
  `undo(TrashRecord)`).
- Undo of Put Back and redo of Trash send whatever is at the inbox URL to the Trash without an identity check.
- Folder contents highlights a filed file's own name as a conflict when its folder is highlighted but not chosen.
- The status strip shows the time on a second line; the spec has one line ("Filed to … · today 09:41").
- Move Back of a file filed with Replace leaves the replaced item in the Trash (deliberate; ⌘Z on the filing restores it).
- A public "is this still the same item" check in the core would replace `FilingService.moveBack`'s synthetic
  `MoveRecord` workaround.
- Re-filing a filed file still records a recent destination.

## From the History review (2026-11-08)

- Put Back takes no document ID (main window and History); `.trashed` marks carry none. Add it, like the filed fix.
- `HistoryListing` marks an entry current when something exists at its path, without checking `document(at:)`.
- A replaced file's row shows a Put Back that always refuses; hide or disable it.
- Duplicated logic: `HistoryModel.returned` vs `MainWindowModel.perform(MoveBackRequest)`; standardized-path
  comparison in four places (`HistoryModel`, `HistoryListing`, `InboxLibrary`, `FilingHistory.locationKey`).
- Old History entries whose document moved on show the confusing `.noHistoryRecord` alert.
- After a Move Back from History, the selection can point at an entry the search hides.
- History actions aren't undoable from the main window; History doesn't update live.

## From the folder-watch review (2026-11-08)

- Test helpers `ManualClock` and `FakeFolderEventSource` ignore cancellation; a regression hangs instead of failing.
- The core's `testDate()` base is around May 2026; move it into 2031–2039 (`no-real-data-in-repo`).
- `ExpectedChanges` keeps recorded changes under paths no inbox covers for the whole session (harmless).
- Every filing operation discards in-flight scans of all inboxes, not only the touched one (costs time only).

## From the watcher-wiring review (2026-11-08)

- Arrivals above the visible sidebar area don't keep the scroll position (spec: rows on screen don't jump).
- `InboxItemID` (volume UUID + file ID): hard links in one inbox share an ID; UUID-less volumes (SMB, exFAT) can
  collide across inboxes. Document it, or disambiguate.
- `InboxRowView` sets the "New" accessibility hint even when the row is marked.
- Tests: `.replaced` moving selection; trash/undo/Move Back/Put Back not reported as external; an external arrival
  clearing a filed mark; ⌘R ignoring the superseded stream.
