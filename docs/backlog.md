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
- History window, filed/trashed status strips with Move Back / Put Back, revert name.
- Date shortcuts in the name field (`deferred-and-wanted-features`).
- Ideas from the layout research (see `docs/open-questions.md`).
