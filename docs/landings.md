# Landings

Work landed on `master`, newest first. Written by `/coord-land`.

## 2026-11-07 claude/app-skeleton-1992fb: app skeleton and Swift toolchain
- What landed: macOS 27 SwiftUI app (`Docsort.xcodeproj`, JSON project format) with empty main and Settings
  windows, empty `Packages/DocsortCore` with Swift Testing, UI smoke tests, swift-format, App Sandbox with
  user-selected read-write and app-scoped bookmarks, `os.Logger`, `.mcp.json` for Xcode previews; toolchain and
  check commands in `CLAUDE.md`.
- Divergence: added on hub request: sandbox entitlements and the subtree-access check, Xcode MCP evaluation and
  `.mcp.json` (previews only), accessibility ids and the logger; Assets.xcassets from the template.
- Follow-ups: verify Release builds; handle stale bookmarks after a folder move or rename; check whether the
  repo-root `allow-folder` grant covers worktrees; replace the placeholder core test with real ones.
