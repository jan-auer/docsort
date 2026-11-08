# Landings

Work landed on `master`, newest first. Written by `/coord-land`.

## 2026-11-08 claude/nostalgic-jennings-7664e3: open destination folder in Finder
- What landed: Open / Reveal in Finder in the right-click menu of picker folder rows, and File › Open Destination in
  Finder (⇧⌘O) for the highlighted or chosen folder; existing folders only.
- Divergence: None. Not tried in the running app.
- Follow-ups: None.

## 2026-11-08 claude/panel-redesign-4b15b5: filing panel redesign
- What landed:
  - Soft-scope destination search: whole-archive search, "In <folder>" before "Elsewhere"; the first Elsewhere match
    is selected; a New Folder row when nothing in the folder matches; a match-quality cut-off against
    scattered-letter noise; no scope chip (fixes the empty pill).
  - Tidy look (system text styles, spacing, contrast); edge-to-edge folder list; a resizable folder-contents area
    with grab-bar cursor; the destination line under the search field; New Folder by the list.
  - The panel moved off `.inspector`: under the toolbar, animated show and hide.
  - PDF under the translucent toolbar; system titlebar separator, continued by a 1 px line above the panel.
- Divergence: the panel's top line is drawn (system separator colour), because the system line only covers content
  that scrolls under the toolbar. User-tested in the running app before landing; 318 core and 61 targeted app unit
  tests pass; no UI tests.
- Follow-ups: README with a screenshot; open the selected folder (context menu and shortcut).

## 2026-11-08 claude/archive-refresh-3fda5f: archive refresh, stable new-folder row
- What landed: ⌘R refreshes inboxes and the archive folder index; a subtle ↻ button in the picker footer; a debounced
  rebuild when the app becomes active. The new-folder row stays under its parent with focus kept while its name is
  typed, and keystrokes no longer reach the search.
- Divergence: None. Not tried in the running app.
- Follow-ups: None.

## 2026-11-08 claude/ui-toolbar-title-77f493: system window title
- What landed: the hand-built "docsort  Inbox › file" title is replaced by the system window title (file name) and
  subtitle (inbox), Finder-style; "docsort" shows when nothing is selected.
- Divergence: None. Not rendered or run by the session; the user checks in the running app.
- Follow-ups: None.

## 2026-11-08 claude/ui-tweaks-2-48cb2d: prev/next buttons, first-file selection
- What landed: a ‹ › Previous/Next File group left of the title, with menu items; the first file selected after the
  initial scan (empty state otherwise); the filing panel's file-name heading removed.
- Divergence: None.
- Follow-ups: None.

## 2026-11-08 claude/ui-history-600ca2 (32bcac9) + claude/app-icon-985d1b: History actions and app icon
- What landed: History inspector pattern B (an icon-only Reveal on the destination line; Open and Move Back side by
  side; Show in Main Window in the menus only). The app icon is concept C2: ink-blue tray with an amber check and a
  simplified 16/32 px drawing; source SVGs in `docs/design/icon/`.
- Divergence: None.
- Follow-ups: check the icon in the Dock and Finder.

## 2026-11-08 claude/ui-main-window, ui-filing-panel, ui-history: UI polish from the first review
- What landed:
  - Toolbar: the panel toggle at the far right, with Open, Reveal and Trash as their own group; a plain
    Finder-style title.
  - Preview: zooms out below fit-width, with page margins.
  - Filing panel: plain background, outlined picker and folder-contents boxes, key hints in the picker footer,
    Revert and the extension inside the name field, the Return toast below the field, a standard-size Move button.
  - History: table plus inspector without overlap, a preview filling the free height, equal-width actions with
    Open prominent.
- Divergence: the History overlap was fixed in the shared `PreviewView` (main-window branch). Landed after lint,
  build and rendered previews only; behaviour in the running app (pinch zoom, clicking ↺ inside the field) is
  unchecked.
- Follow-ups: the user's pick between the History action patterns; the app icon.

## 2026-11-08 claude/folder-watch-de5f8d (d347ce3): live inbox watching in the app
- What landed:
  - `InboxLibrary` subscribes to `InboxWatcher`; external arrivals get the new dot, external removals disappear and
    move the selection, Finder renames keep row and selection;
  - `FilingService` wraps every operation in `ExpectedChanges`; ⌘R restarts the subscription;
  - rows are pinned while their file is being filed, so a watcher update can't drop the mark (review blocker);
  - a finishing download keeps the typed name.
- Divergence: an external arrival of a handled file clears its mark; a new file under a filed name gets its own row.
- Follow-ups: scroll anchoring for arrivals above the viewport, ID collisions on hard links and UUID-less volumes,
  and further tests (`docs/backlog.md`).

## 2026-11-08 claude/test-fixes-824ce4: hosted test fixes
- What landed: the first passing run of the full app test suite (all `DocsortTests`, UI tests 20/20 in run 4). App
  fixes: stale SwiftUI focus values resigned the focused field; the selected file didn't follow its mark after a
  rename; the new-folder field focused too early. Plus test assertions, a picker test-host launch mode, and the
  sidebar row's filing state as its accessibility value.
- Divergence: landed without a separate review; the full suite had passed. The final rerun was interrupted at the
  user's request.
- Follow-ups: wire folder watching into the sidebar.

## 2026-11-08 claude/folder-watch-de5f8d: live inbox watching in the core
- What landed: `InboxWatcher.updates(for:)` (FSEvents source, 0.5 s coalescing, rescan and diff by identity, then
  path, then the download-name rule; unreachable inboxes retried every 5 s), `ExpectedChanges` so docsort's own
  operations are not reported as external, and `identity: FileIdentity` on scanned items. 316 core tests.
- Divergence: no manual rescan API (⌘R restarts the subscription); identity-less items are also dropped from
  `DestinationIndex`, with a `ScanProblem`; with inboxes sharing a folder, own changes are suppressed for the first
  only.
- Follow-ups: wire it into `InboxLibrary` and `FilingService` (after the test-fix branch lands); backlog items.

## 2026-11-08 claude/app-ui-b54b29 (9d757fc) + Move Back fix + History window (a113978)
- What landed:
  - filed and trashed status strips with Move Back and Put Back (⌥⌘Z);
  - renaming or moving a filed file again; Revert Name (⇧⌘R); menu and context-menu items, all undoable;
  - the History window (⌘Y): a day-grouped table with search, preview, Open, Reveal, Move Back, Put Back and Show in
    Main Window;
  - `FilingService.events()`, `moveBack(document:at:resolution:)`, `refile(...)` and `putBack(_:)`.
  Filed marks now carry the document ID, and Move Back, rename and move-on refuse when another file took the path.
- Divergence:
  - The Move Back fix and History were built by hub subagents (the session message cap and the no-new-sessions rule
    applied while the user was away).
  - History actions aren't undoable from the main window.
  - History has no live updates; it refreshes when its window becomes active.
  - "Replaced" is a History entry kind.
  - The time sits on its own line in the strips.
- Follow-ups: hosted tests unrun (screen locked); `docs/backlog.md`.

## 2026-11-08 claude/app-ui-b54b29 (fc94b93) + claude/picker-3b43e7: end-to-end app
- What landed, the first usable app:
  - Settings with security-scoped folders and the ranking option;
  - inbox sidebar (oldest first, groups) and preview (PDFKit / Quick Look);
  - the drill-down destination picker with scoped search, new folders and folder contents;
  - a name field, ⌘Return move with check-off and next file, Keep Both / Replace, ⌘⌫ Trash, ⌘Z/⇧⌘Z;
  - a persistent history with the save-failure policy and quit-time save;
  - `FilingService`, `InboxLibrary`, `ArchiveLibrary`.
  Landed while the user was away (`autonomous-while-away`), after two reviews: one blocker in the e2e flow and three
  in the picker integration were fixed.
- Divergence: the picker component was merged into the UI branch rather than landing on its own. The name field and
  filter use AppKit text fields. Hosted tests (app unit tests after 01:30, all UI tests) are written but unrun,
  because the screen was locked; verified by lint, builds, core tests, launch-log checks and review.
- Follow-ups: run the hosted tests (`docs/open-questions.md`); `docs/backlog.md`; History window, status strips with
  Move Back, revert name, and wiring in live folder watching.

## 2026-11-08 claude/architecture-60c7c1: target architecture
- What landed: `docs/architecture.md`: layers, core services (folder access, filing, inbox listing, destinations,
  folder contents) with intended signatures, the concurrency model, and per service what to set now and what to move
  during the cleanup.
- Divergence: None. It records non-UI Apple frameworks in the core, which `core-apple-frameworks` has since approved.
- Follow-ups: the architect keeps reviewing branches against it; the cleanup comes once the app works end to end.

## 2026-11-08 claude/core-engine-79f2d6: core engine
- What landed: `Packages/DocsortCore`, with 249 tests:
  - settings with security-scoped bookmarks and per-folder status;
  - the inbox scan (oldest first, groups placed by folder creation date, symlinks reported);
  - destination search on FuzzyMatch 1.4.0 with scoped search and the `ScopedRanking` setting;
  - file operations (Keep Both/Replace, new folders, Trash, identity-checked undo, verified cross-volume moves);
  - recents and a crash-safe, versioned filing history with `undoFirst` blockers.
- Divergence: on request, oldest-first order, persistent history, scoped search, the ranking setting and the review's
  safety fixes. The test corpus was rewritten three times for privacy; it is now a fictional household dated
  2031–2039, and the branch history holds only that version.
- Follow-ups (for the UI piece):
  - sandboxed-app verification of bookmarks;
  - undo of Trash and Replace after a relaunch (`~/.Trash` access);
  - one actor for perform/record/save;
  - running the core off the main actor;
  - cleaning up leftover `.partial` files.

  Later: live folder watching as its own core piece. Cross-volume moves are tested only through a seam.

## 2026-11-08 claude/ux-design-78f5ba: approved UX design
- What landed: `docs/design/ux.md` (spec approved by the user after four rounds), the interactive mockup and the
  picker A/B prototype with their build sources, and an invented sample archive (`docs/design/sample-data/`: a
  fictional retired household in "Wettelau", dated 2031–2033).
- Divergence: the first sample data was derived from the user's real archive. Reviews caught it twice; it was
  rewritten from scratch by a fresh writer, the branch squashed to one commit, and the two old published mockups
  deleted. That led to the stricter `no-real-data-in-repo` rule.
- Follow-ups: publish the clean mockup as a new artifact and add its link to `ux.md`; the user may run
  `git reflog expire --expire=now --all && git gc --prune=now` to drop old unreachable commits holding real data.

## 2026-11-07 claude/app-skeleton-1992fb: app skeleton and Swift toolchain
- What landed: macOS 27 SwiftUI app (`Docsort.xcodeproj`, JSON project format) with empty main and Settings
  windows, empty `Packages/DocsortCore` with Swift Testing, UI smoke tests, swift-format, App Sandbox with
  user-selected read-write and app-scoped bookmarks, `os.Logger`, `.mcp.json` for Xcode previews; toolchain and
  check commands in `CLAUDE.md`.
- Divergence: added on hub request: sandbox entitlements and the subtree-access check, Xcode MCP evaluation and
  `.mcp.json` (previews only), accessibility ids and the logger; Assets.xcassets from the template.
- Follow-ups: verify Release builds; handle stale bookmarks after a folder move or rename; check whether the
  repo-root `allow-folder` grant covers worktrees; replace the placeholder core test with real ones.
