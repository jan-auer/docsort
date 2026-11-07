# Decisions

Lasting decisions, facts and lessons. One `## <slug>` heading each, with the reason.

## native-swift-app

docsort-ui is a native macOS app in Swift/SwiftUI (AppKit where SwiftUI falls short), macOS-only. Reason: the
CLI's main limit was preview; only a native app can embed Quick Look (any file type) and PDFKit in the window, and it
gives later suggestion work direct access to PDF text, Vision OCR and Spotlight metadata (for example download
source). Tauri + web UI was considered and rejected: it would reuse docsort-cli's Rust code but preview non-PDF files
only as thumbnails. Successor to `~/Coding/docsort-cli` (Rust TUI); its feature set is the baseline, its exact
keyboard shortcuts are not.

## config-in-settings

Inbox folders and the archive root are configured only in the app's Settings and stored in app preferences. No
`.docsort.toml` is read, not even as a first-launch import. Reason: user's choice; the app and the CLI do not
need to share configuration.

## fuzzy-matching-library

Prefer a mature fuzzy-matching library over writing one; whoever implements destination search researches the
options and proposes one. Reason: user's guidance; matching quality is the CLI's best-liked feature.

## app-sandbox

The app keeps the App Sandbox on. It has read-write access to user-selected files and stores a security-scoped
bookmark for each folder picked in Settings (archive root, each inbox), resolved once at launch. Reason: the app
can only touch folders the user granted, which guards an app that moves and trashes documents. This depends on one
condition the user set: a bookmark to a folder must give read-write access to its whole subtree. Verified on
2026-11-07 in the real sandboxed app: a bookmark picked through the open panel, resolved in a new process, allowed
listing, creating, renaming, moving between deep subfolders and trashing 3–5 levels deep; without it, every operation
failed. Apps built by `xcodebuild test` get extra test-only read access to `/`, so sandbox read checks must use an app
from a plain build. If the condition ever turns out false, turn the sandbox off. Folders
reached through symlinks outside a granted tree (for example `~/Inbox/Linked`, which points into Google
Drive) are not covered and need their own grant.

## agent-tooling

Agents use built-in tools wherever they work: `xcodebuild` and `swift test` stay the check commands, XCUITest
covers keyboard flows, `log stream` reads the app's `os.Logger` output, and the Claude app's computer use handles
visual checks of the running app. Xcode's own MCP server (`xcrun mcpbridge`) is used where it brings a significant
benefit and works. Tested with worktrees, it qualifies only for rendering SwiftUI previews (`RenderPreview`). Its
build and test tools are not used: a build started right after a file changed reported success on the old code, and
otherwise they add nothing over `xcodebuild`. No third-party automation tools (Peekaboo, MobileBuildMCP). Reason:
user's choice after a tooling survey in the first session.

## hub-delegates-research

The hub does quick reads itself but hands research (stack, libraries, toolchain) to sessions or subagents.
Reason: the user corrected the hub for researching inline in the first session.
