# Landings

Work landed on `master`, newest first. Written by `/coord-land`.

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
