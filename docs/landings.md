# Landings

Work landed on `master`, newest first. Written by `/coord-land`. Older entries are compressed to one line; the full
entries, with their divergences and follow-ups, are in `git show 84de681:docs/landings.md`.

## 2026-11-10 claude/code-cleanup-2-bc5e2c: code cleanup round 2 (picker, paths, core)
- What landed: one core `FileLocation.path(of:)` instead of ~8 copies; Folder contents sorted once, in name order, by
  the core; `DestinationPickerModel` split into `+FolderContents` / `+NewFolder` (893 → ~570 lines); `ScanProblem`
  carries its kind from the walker; the shortcuts sheet and the picker share one `SearchField`; picker tests and
  UI tests trimmed to one test per behaviour (`test-intent`). 331 core and 185+ app unit tests pass.
- Divergence: History now matches locations with a trailing slash (finds moved-back packages' inbox rows). The
  shortcuts sheet's search field looks like the picker's, its clear button refocuses the field and reads "Clear" to
  VoiceOver; not seen on screen. The picker model's state setters are module-internal (set only by the model and its
  extensions). `createFolders` deleted (its behaviours tested through `move`). Done without delegating to cheaper
  subagents (the rule landed mid-way).
- Follow-ups: None.

## 2026-11-10 claude/first-keystroke-db11d7: first letter after launch no longer replaced
- What landed (squashed, b392731): text typed in the sidebar waits until the destination filter has focus and goes
  in as typed; the picker's key monitor hands it over before any key reaches the field, so fast typing keeps its
  order; waiting text is dropped when focus goes elsewhere or the panel hides. The keyboard UI test passes again.
- Divergence: the filter no longer puts its caret at the end on every focus (a click keeps its position; Tab, Esc
  back or coming back from the name field selects all, so the first → collapses the selection). Sidebar-typed text
  filters the list once the field has focus. No automated test fails without the fix (hosted tests can't drive
  SwiftUI focus); checked by the user in a Release build. More diagnostic UI-test runs than first agreed.
- Follow-ups: which 2026-11-09 commit exposed the race is unknown (bisect if it matters); add the UI steps lost in
  code cleanup round 1 (⌥⌘Z from the sidebar, ⌘Return from the name field, Rename label, Move Back button).

## 2026-11-10 claude/friendly-jemison-55046b: code cleanup round 1 (filing plumbing and tests)
- What landed: one status-mirroring helper (`FilingStatusModel`), one recorded-move path in `FilingService`,
  `MainWindowModel+Filing` split (835 → 486 lines), one shared `TestWindow` fixture; tests follow `test-intent`
  (disk outcomes asserted once, status texts as facts, three UI tests that repeated model tests dropped). Net −211
  lines; 332 core and 181 app unit tests pass.
- Divergence: `FilingModel` renamed `FilingStatusModel`; undo types live in `MainWindowModel+Undo.swift`; six step
  helpers are module-internal (documented as skipping the filing guard). HistoryModelTests keep their
  History-specific disk checks. UI tests not run.
- Follow-ups: UI coverage now gone at every level: ⌥⌘Z with the sidebar focused, ⌘Return from the name field, the
  Rename button's label, the status strip's Move Back button; add as steps once the first-keystroke fix lets the UI
  suite run.

## 2026-11-10 claude/loving-dijkstra-01ce93: docs cleaned up, decision history split out
- What landed (squashed, 003179d): old design studies, mockups and screens deleted (~9 MB); decisions.md cut to
  standing rules (231 → 180 lines) with history in the new `docs/decision-log.md`; new decisions `test-intent`,
  `coordinator-autonomy`, `archive-refresh`, `search-performance`; older landings compressed; ux.md, architecture.md,
  backlog, README and CLAUDE.md brought in line with the app.
- Divergence: squashed at the user's request. ux.md "Decisions" list kept, shortened; `layering`'s status ("due, not
  started") is the coordinator's reading. ux.md's planned markings are checked against code, not the running app.
- Follow-ups: architecture.md's `FilingService` sketch no longer matches the real API (noted there).

## 2026-11-10 claude/search-lag-0bed3b: destination search 3–10× faster on large archives
- What landed: parallel scoring and highlighting over UTF-8 paths, and an index search outside a folder for the
  picker's Elsewhere; ~25,000 invented folders went from 16–60 ms per keystroke (worst 237 ms) to 4–9 ms (worst 24 ms)
  in Release, results identical. Opt-in benchmark `DestinationSearchBenchmark`.
- Divergence: "This folder" is offered whenever the folder matches (a weak match no longer drops out in large
  archives). Search stays synchronous (user's choice). Pushed before its privacy review, which was clean. Typing not
  watched in the running app; Debug builds stay slow (300–500 ms per keystroke at 25k folders).
- Follow-ups: decision `search-performance` lands with the docs cleanup.

## 2026-11-09 claude/toolbar-glass-under-panel: toolbar blur spans preview and filing panel
- What landed: the PDF view runs under the filing panel, so the toolbar's blur over a scrolled PDF runs across the
  whole toolbar; `PartlyCoveredPDFView` keeps pages fitted and centred left of the panel through page margins
  (decision `toolbar-glow-under-panel`), and the pages follow the panel's slide. The panel keeps its own line under the
  toolbar. 3 new hosted tests; 319 core and 179 app unit tests pass.
- Divergence: the panel now lies over the PDF view's trailing edge instead of beside it. Two rejected spikes (a line
  through the toolbar, mirrored PDF copies) are not in the branch; a removed-and-restored panel line is. The derived
  covered width (no jump at launch) is unseen on screen; UI tests not run.
- Follow-ups: cursor over the panel while a zoomed page lies under it; "Show scroll bars: Always" fit; the
  Shortcuts-style glass inspector is still being compared (`claude/inspector-glass-6c32d3`).

## 2026-11-09 install-script: scripts/install.sh builds Release and installs it
- What landed: `scripts/install.sh` builds the Release configuration into `.build/xcode` (incremental, next to
  Debug), replaces `/Applications/Docsort.app` and opens it (`--no-open` skips that); it stops if the installed app
  is running.
- Divergence: done by the hub on a branch in the main checkout, without a coordinator; reviewed by the hub (small
  diff), without the reviewer subagent. The README's "Install a Release build" section is unchanged at the user's
  request and still shows `.build/xcode-release`. The build step was run; the install step was not run by an agent.
- Follow-ups: None.

## 2026-11-09 claude/folder-focus-fix-6fe6ad: Folder contents keeps focus after a click
- What landed: the focus binding moved from the Folder contents drawer to its file list, so a click focuses the
  list (↓ and Space work) instead of the header's chevron when keyboard navigation is on. One targeted UI test;
  decision `swiftui-focus-binding`.
- Divergence: a UI test rather than a unit test (hosted unit tests can't check SwiftUI focus). Reviewed by the hub
  (small diff), without the reviewer subagent. Not tried in the user's running app; Space opening Quick Look is
  not covered by the test.
- Follow-ups: None.

## 2026-11-09 claude/shortcuts-sheet-bf85be: keyboard shortcuts sheet
- What landed: a read-only sheet over the main window (⌘/, Help › Keyboard Shortcuts), grouped by context with
  keycaps and search; Esc clears the search, then closes. Menu commands, tooltips and the sheet read one catalog
  (`App/Shortcuts/`); tests keep the menus, picker keys and Quick Look panel keys in sync with it. While any sheet
  or alert is attached to the main window, its file commands are off (`AttachedSheetTracker`), so ⌘⌫ in a sheet's
  text field never trashes the selected file. Prior art and design: `docs/design/keyboard-shortcuts-sheet.md`.
- Divergence: an extra "New Folder Name" section; a custom capsule search field, a fixed 760 × 640 sheet with Done
  and a footer; planned but unbuilt keys (⌘L, ⌘1…⌘9, PgUp/PgDn, ⌥↑/⌥↓) are marked as such in `ux.md` and left
  out. One review round with two blockers fixed; 319 core and 176 app unit tests pass. The look in light and dark
  mode and the Rename alert's guard are unchecked.
- Follow-ups: `docs/backlog.md` (sidebar and Folder contents keys not enforced by tests, column balancing, ⌘/ while
  History or Settings is key).

## 2026-11-09 claude/folder-quicklook-c8e80a: Quick Look and file actions in Folder contents
- What landed: Folder contents is Finder-style. A click selects, ↑/↓ move, Space opens the Quick Look panel (it
  follows ↑/↓), and double-click or Return uses the name. A file menu has Use Name, Quick Look, Open, Open With ›,
  Reveal, Copy Name/Path, Rename… and Move to Trash. Space opens Quick Look in the inbox sidebar too, through one
  shared panel controller. Archive rename and trash go through `FilingService`: recorded in the history, undoable,
  and the filed row follows them.
- Divergence: Put Back of an archive-trashed file returns it to its archive folder (the row stays filed, dated by
  the Put Back). History offers Revert Name / Put Back, never an inbox return, for archive-origin entries. No Quick
  Look menu item. ⌘O, ⌥⌘R and ⌘⌫ still act on the inbox file while Folder contents has focus. ↑/↓ in the panel onto
  a trashed row closes it. Two review rounds; 319 core and 155 app unit tests pass. The Quick Look panel, the menus
  and the row-state previews are untried on screen.
- Follow-ups: the shortcuts sheet lists the new keys; `docs/backlog.md` (identity check on archive rename and
  trash, Open With work out of the view, menu commands following the focused list).

## 2026-11-08 claude/picker-after-filing-62da19 + claude/sidebar-numeric-dates: picker highlight after filing
- What landed: after filing, the next file's picker highlights the folder just used at the top of Recent, whichever
  order the panel reset and the recents update arrive in (`picker-inputs-arrive-late`). A test pins the sidebar date
  format for de_AT and en_US (the landed format was already locale-aware).
- Divergence: the reset placement also re-applies when a new index or ranking arrives right after a reset.
- Follow-ups: None.

## 2026-11-08 claude/sidebar-dates-5eef76: absolute dates in the sidebar
- What landed: sidebar rows show a compact absolute date ("12 Oct", with the year when it isn't the current one)
  instead of a relative one; group ranges are absolute too.
- Divergence: None.
- Follow-ups: None.

## 2026-11-08 Published: jan-auer/docsort (public)
- What happened: history rewritten after the first three commits to replace a real folder name and a real path
  (`screenshots-stay-private`); private links, a machine path and the open-questions file removed; old unreachable
  objects purged. GitHub `jan-auer/docsort` renamed to `docsort-llm` (old LLM-based attempt; checkout now
  `~/Coding/docsort-llm`). `jan-auer/docsort-ui` renamed to `docsort`, given a description and made public; this
  checkout moved to `~/Coding/docsort`.
- Divergence: commits after `d1cf540` lost their signatures in the rewrite.
- Follow-ups: the user disables password-free automation mode and clears the Xcode MCP permissions.

## 2026-11-08 claude/hopeful-hamilton-b85e63: README with a screenshot in sample-data mode (merge cb3aea3)
## 2026-11-08 claude/nostalgic-jennings-7664e3: Open / Reveal in Finder for destination folders, ⇧⌘O (merge 1fcca2c)
## 2026-11-08 claude/panel-redesign-4b15b5: filing panel redesign, soft-scope search, panel off `.inspector` (merge 52fc4fd)
## 2026-11-08 claude/archive-refresh-3fda5f: ⌘R and app activation refresh the archive index; stable new-folder row (merge 7def186)
## 2026-11-08 claude/ui-toolbar-title-77f493: system window title and subtitle (merge c1934cf)
## 2026-11-08 claude/ui-tweaks-2-48cb2d: Previous / Next File buttons, first file selected at launch (merge 5b724ff)
## 2026-11-08 claude/ui-history-600ca2 + claude/app-icon-985d1b: History inspector actions, app icon (merges 2202c09, 06da5e6)
## 2026-11-08 claude/ui-main-window, ui-filing-panel, ui-history: UI polish from the first review (merges 57abcaa, 0100ac8, 0e640af)
## 2026-11-08 claude/folder-watch-de5f8d: live inbox watching in the app (merge 2fb8f80)
## 2026-11-08 claude/test-fixes-824ce4: first passing run of the full app test suite (merge 8ddfde1)
## 2026-11-08 claude/folder-watch-de5f8d: live inbox watching in the core, `InboxWatcher` and `ExpectedChanges` (merge 7887fc5)
## 2026-11-08 claude/app-ui-b54b29 + Move Back fix: status strips, Move Back / Put Back, Revert Name, History window (merge 46068c0)
## 2026-11-08 claude/app-ui-b54b29 + claude/picker-3b43e7: the first usable end-to-end app (merge 69e1271)
## 2026-11-08 claude/architecture-60c7c1: target architecture in `docs/architecture.md` (merge 4ad365f)
## 2026-11-08 claude/core-engine-79f2d6: core engine, `Packages/DocsortCore` (merge 3d51324)
## 2026-11-08 claude/ux-design-78f5ba: approved UX spec, mockups and the invented sample archive (merge 53e5222)
## 2026-11-07 claude/app-skeleton-1992fb: app skeleton and Swift toolchain (merge 35e0f7d)
