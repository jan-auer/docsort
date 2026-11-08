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
accepts a Rust toolchain) if ranking falls short in daily use. Test fixtures follow `no-real-data-in-repo`.

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

## layering

The core exposes small, clean service interfaces, each owning one concern (filing with its perform/record/save
orchestration, inbox listing with live updates, destination lookup and search, previews and caching). The UI only
calls those services; views and view models hold no file-system, history or orchestration logic. Until the app works
end to end, new code keeps UI-free services in their own files so they can move into the core. Once the app is
usable end to end, an architecture coordinator reviews the codebase and moves the core toward this, in parallel
with feature and UX work. Do it earlier only if the code gets too messy. Reason: the user found orchestration landing
in the UI layer and asked for clean separation, but wants a usable app first.

## core-apple-frameworks

The core package may import non-UI Apple frameworks (CoreServices for FSEvents now; PDFKit text extraction, Vision
and Spotlight metadata for suggestions later), but never SwiftUI or AppKit. Reason: the app is macOS-only
(`native-swift-app`), and these are what the core's services need; decided by the hub on the architect's proposal.

## one-xctest-at-a-time

Only one `xcodebuild test` runs on the machine at a time, across all sessions. Parallel runs share one testmanagerd
and the same bundle ID, and hang. Wrap every run in the shared lock:
`until mkdir /tmp/docsort-xctest.lock 2>/dev/null; do sleep 15; done; xcodebuild … test …; rc=$?; rmdir /tmp/docsort-xctest.lock`.
Plain builds and `swift test` don't need it. Also, RenderPreview (Xcode MCP) launches the real app and leaves it
running, and a running Docsort.app makes `xcodebuild test` hang. Call `XcodeCloseWorkspace` after rendering previews
and before testing, and check `ps` for a stray Docsort.app when tests hang. Reason: test runs hung on 2026-11-08.

## targeted-ui-tests

No UI-test runs except a single focused test, when it is essential to validate a fix that a unit test has already
confirmed. No full UI suites, and no UI tests used for diagnosis. Diagnose with unit tests or the log-based launch
check; list leftovers instead of hunting. Reason: the user found the UI-test runs wasteful and slow (2026-11-08).

## e2e-first

Get the thinnest usable end-to-end app first, then refine features, UX and architecture in parallel. While getting
there:
- one review before landing, with non-critical findings going to a backlog instead of another round;
- coordinators decide implementation details themselves and escalate only product questions;
- tests cover core logic and the main flow, not exhaustive suites;
- privacy reviews only when new sample data is added (all sample data comes from the one reviewed archive).
Reason: on 2026-11-08 the user found progress too slow: no usable prototype after many review, privacy and design
rounds.

## autonomous-while-away

Updated 2026-11-08 after the user returned: commits are signed again, and the hub keeps landing reviewed work without
asking. The user wants to be involved only for judgement calls (product behaviour, trade-offs) and when something is
ready to use.
While the user is away (from 2026-11-08), the hub lands work that passes the checks and one review without asking.
Commits are unsigned (`git -c commit.gpgsign=false`), because 1Password can't be unlocked. The goal is the approved
mockup's functionality; edge cases that resist stay out. Questions that need the user are collected in
`docs/open-questions.md`. Reason: the user's instruction when signing off.

## parallel-sessions

Sessions run in parallel wherever their files don't overlap, each owning one piece; avoid long-lived sessions that
carry many pieces. Reason: the user wants faster progress and found one UI session carrying too much.

## history-save-failure

One `FilingService` actor owns perform → record → save for every move and trash. If saving the filing history fails
after an operation, the change stays and a persistent warning offers Try Again; saves are retried before later
operations and at quit (with "Quit Anyway / Cancel" if it still fails). An unreadable history at launch is never
overwritten: moving and trashing are disabled until the user starts a new history (the old file is renamed aside).
Later idea, not planned: write-ahead, recording a pending event before the move. Reason: the user considers this an
edge case and chose the simple option.

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
covers keyboard flows (asserting on elements and accessibility identifiers), and `log stream` reads the app's
`os.Logger` output. Nothing may capture the screen or audio: no computer use, no `screencapture`, no
ScreenCaptureKit, no screenshots in UI tests. Each of these makes macOS ask the user for Screen & System Audio
Recording, which the user does not want to grant. Visual checks use Xcode's `RenderPreview`; when only a look at the
running app will do, ask the user. Xcode's own MCP server (`xcrun mcpbridge`) is used where it brings a significant
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
archive. How to write sample data so it stays clean:
- A fresh subagent writes it from an abstract spec: the shapes and situations needed, no concrete names, dates or
  examples. It never reads the real archive, the old sample data, or notes from sessions that have seen the archive.
  A session whose context holds real data drifts back to it even when it means to invent.
- The fictional household has a different life situation from the user's.
- Its dates sit in clearly different years (for example 2031–2033). The real archive has files on most days of recent
  years, so invented recent dates collide with real documents of the same kind.
Reason: the user asked for made-up names; reviews caught leaks five times (core fixtures three times, the design
mockups twice), and the first design brief allowed real names.

## search-scoped-ranking

The destination search ranks closer folders first by default: at comparable match quality, a folder fewer levels
below the current scope wins, even over a deeper folder whose name matches exactly (the user types a common prefix,
not scattered letters). The archive root is a scope like any other. It is a setting, so the user can switch to
"exact name first" later. Reason: user's choice in the core review. (An earlier version of this entry said exact
names always win from the root; that was the hub's misreading of one example, not the user's decision.)

## hub-delegates-research

The hub does quick reads itself but hands research (stack, libraries, toolchain) to sessions or subagents.
Reason: the user corrected the hub for researching inline in the first session.
