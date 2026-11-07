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

## hub-delegates-research

The hub does quick reads itself but hands research (stack, libraries, toolchain) to sessions or subagents.
Reason: the user corrected the hub for researching inline in the first session.
