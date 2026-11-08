# Backlog

Non-blocking findings and deferred work, collected by the hub. Newest group first.

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

- Live folder watching wired into the sidebar (core work in progress on `claude/folder-watch-*`).
- (Done 2026-11-08: History window, status strips, Move Back / Put Back, revert name.)
- Date shortcuts in the name field (`deferred-and-wanted-features`).
- Ideas from the layout research (see `docs/open-questions.md`).

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
