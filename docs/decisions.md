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

Chosen: ordo-one/FuzzyMatch 1.4.0 (Smith-Waterman mode), wrapped with query trimming, bonuses for whole and last
path segments, a recent-destinations boost and an ue/ae/oe/ss → ü/ä/ö/ß fallback. The user's rule was "nucleo if it
is significantly better for my use, otherwise FuzzyMatch". On 66 CLI-style queries over the real archive, nucleo put
the target first 41 times and FuzzyMatch 38, and both found it in the top 10 about equally (49 vs 48). FuzzyMatch
only misses low-scoring scattered-letter matches. Revisit with nucleo through a Rust static library (the user
accepts a Rust toolchain) if ranking falls short in daily use. Test fixtures use made-up names close to the real ones.

## inbox-and-history-behaviour

Settled from the user's first mockup review:
- Inbox files are listed oldest first, unlike the CLI.
- Filed files stay where they are in the list, checked off, so the list never shuffles. There is no "Filed" section.
- A filing history persists across restarts: every move records original path and name, destination, new name and
  time. A History view lists all filed files in chronological order.
- A filed file can still be renamed, and "revert name" restores the name it had before filing.
Reason: user's choice; files moving around in the sidebar is disorienting, and the history makes filing auditable.

## deferred-and-wanted-features

- Deferred: shortcuts that insert a date into the name field. Today's date is rarely the document's date; revisit
  together with inferring the document date from its content.
- Wanted: live watching of inbox folders. Files added or removed by something other than the app update the sidebar
  live. Files the app moved stay checked off in place; files moved or deleted elsewhere disappear (a layout shift is
  acceptable there). Built as its own core piece plus UI integration, after the UI shell.
Reason: user's feedback in design round 2.

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

## no-real-data-in-repo

Test fixtures, mockups and examples never contain names, dates or details from the user's real archive. Write them
from scratch in the archive's style. Don't derive them from real names by swapping parts out: twice such a
transformation kept real dates, items and listing details. The real tree may serve as a private, uncommitted
benchmark. Anything that may contain sample data gets an independent privacy review before it is published as an
artifact or landed. The author's own check is not enough. Briefs must not invite drawing sample names from the real
archive. Reason: the user asked for made-up names; reviews caught leaks three times (core fixtures twice, the design
mockups once), and the first design brief allowed real names.

## search-scoped-ranking

Inside a folder, the destination search ranks direct children first by default (the user types a common prefix,
not scattered letters). It is a setting, so the user can switch to "exact name first" later. From the archive root,
exact names win either way. Reason: user's choice in the core review.

## hub-delegates-research

The hub does quick reads itself but hands research (stack, libraries, toolchain) to sessions or subagents.
Reason: the user corrected the hub for researching inline in the first session.
