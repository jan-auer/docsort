# Landings

Work landed on `master`, newest first. Written by `/coord-land`.

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
