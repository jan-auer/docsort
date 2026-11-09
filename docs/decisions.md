# Decisions

What every session must follow or know now: conventions, constraints, process and product rules, one `## <slug>`
each, as the rule and a short reason. How a choice was reached (benchmarks, rejected alternatives, verifications,
incidents) is in `docs/decision-log.md` under the same slug; read it when revisiting that area.

## native-swift-app

docsort-ui is a native macOS app in Swift/SwiftUI (AppKit where SwiftUI falls short), macOS-only. Reason: only a
native app can embed Quick Look (any file type) and PDFKit in the window, and reach PDF text, Vision OCR and
Spotlight metadata for later suggestions. Successor to `~/Coding/docsort-cli` (Rust TUI): its feature set is the
baseline, its exact keyboard shortcuts are not. Rejected alternative: in the log.

## config-in-settings

Inbox folders and the archive root are configured only in the app's Settings and stored in app preferences. No
`.docsort.toml` is read, not even as a first-launch import. Reason: user's choice; the app and the CLI do not
need to share configuration.

## fuzzy-matching-library

Destination search uses ordo-one/FuzzyMatch 1.4.0 (Smith-Waterman mode) behind our wrapper: query trimming, bonuses
for whole and last path segments, a recent-destinations boost and an ue/ae/oe/ss → ü/ä/ö/ß fallback. Revisit with
nucleo through a Rust static library if ranking falls short in daily use. Reason: matching quality is the CLI's
best-liked feature, and a mature library does it better than our own matcher would; the benchmark is in the log.

## search-performance

Destination search must stay fast on large archives. Measure in Release with the opt-in benchmark over the generated
~25,000-folder archive (`LargeArchiveCorpus.swift`):
`DOCSORT_SEARCH_BENCHMARK=1 swift test -c release -Xswiftc -enable-testing --filter DestinationSearchBenchmark`.
Debug runs FuzzyMatch unoptimised, 40–80× slower, so never judge speed there. Search stays synchronous on the main
actor; async search was declined for now (user's choice, 2026-11-10). Numbers and lessons: in the log.

## inbox-and-history-behaviour

- Inbox files are listed oldest first, unlike the CLI.
- Filed files stay where they are in the list, checked off, so the list never shuffles. There is no "Filed" section.
- A filing history persists across restarts: every move records original path and name, destination, new name and
  time. A History view lists all filed files in chronological order.
- A filed file can still be renamed, and "revert name" restores the name it had before filing.
Reason: user's choice in the first mockup review; files moving around in the sidebar is disorienting, and the
history makes filing auditable.

## date-shortcuts-deferred

No shortcuts that insert a date into the name field for now. Today's date is rarely the document's date; revisit
together with inferring the document date from its content. Reason: user's feedback in design round 2.

## archive-refresh

The archive index is rebuilt when the app becomes active, on ⌘R and with the picker's ↻ button. The archive is not
watched; the inboxes are. Reason: user's choice (2026-11-10); watching the archive is more complex than it's worth.

## layering

The core exposes small, clean service interfaces, each owning one concern (filing with its perform/record/save
orchestration, inbox listing with live updates, destination lookup and search, previews and caching). The UI only
calls those services; views and view models hold no file-system, history or orchestration logic. New code keeps
UI-free services in their own files so they can move into the core. Reason: the user found orchestration landing in
the UI layer and asked for clean separation, but wanted a usable app first. Its status and steps:
`docs/architecture.md`, "The cleanup, in order".

## core-apple-frameworks

The core package may import non-UI Apple frameworks (CoreServices for FSEvents now; PDFKit text extraction, Vision
and Spotlight metadata for suggestions later), but never SwiftUI or AppKit. Reason: the app is macOS-only
(`native-swift-app`), and these are what the core's services need.

## test-intent

Tests assert intentional behaviour and edge cases whose breakage would be a real bug, never implementation details
(internal ordering, log text, exact UI wording, call counts on fakes where only the outcome matters, layout numbers).
Each behaviour is tested once, at the lowest level that can see it: core logic in the package, model reactions in
`DocsortTests`, and only what needs the real UI (key routing, focus, menu wiring) in `DocsortUITests`. Status and
alert texts are free text: tests assert the facts (destination, name, Undo offered), not the sentence. When it's
unclear whether a behaviour is intentional, ask the user. Reason: the user wants tests that guard behaviour without
test-code bloat (2026-11-10).

## one-xctest-at-a-time

Only one `xcodebuild test` runs on the machine at a time, across all sessions (procedure: CLAUDE.md, "Hosted tests").
Reason: parallel runs, and runs beside another Docsort.app, share one testmanagerd and bundle ID and hang.

## targeted-ui-tests

UI tests run only as a single focused test that validates a fix a unit test has already confirmed (command: CLAUDE.md).
Reason: the user found UI-test runs wasteful and slow (2026-11-08).

## filing-panel-redesign

The filing panel, as the user chose it on 2026-11-08 (the studies and the rejected concepts are in the log):
- Destination search, soft scope: every search covers the whole archive; matches under the current folder come
  first ("In <folder>"), then "Elsewhere". When nothing in the folder matches, the first Elsewhere match is
  highlighted and "New Folder" is offered. No scope pill or chip in the field.
- Look: system text styles, consistent spacing, one row style, areas separated by contrast.
- Structure: an edge-to-edge folder list, a resizable folder-contents area, the full destination path shown once
  (the destination line), the New Folder button with the folder list, not at the bottom.
- The panel is a main-content pane, not an `.inspector`.

## coordinator-autonomy

Coordinators settle implementation details themselves and list every choice under Divergence (`.claude/workflow.md`).
Reason: the user's choice (2026-11-10).

## commit-signing

Sessions commit unsigned on their own branches (`git -c commit.gpgsign=false commit`). The hub's merge commits and
records on master are signed when 1Password allows; if it refuses, the hub may merge unsigned rather than block.
Reason: 1Password re-locks often and blocked sessions repeatedly (user's choice, 2026-11-08).

## screenshots-stay-private

The hub never copies names, paths or text from the user's own screenshots into briefs, messages or docs; it describes
what a screenshot shows in generic terms. Reason: a real folder name relayed from a screenshot once leaked into code,
tests and a commit message.

## history-save-failure

One `FilingService` actor owns perform → record → save for every move and trash. If saving the filing history fails
after an operation, the change stays and a persistent warning offers Try Again; saves are retried before later
operations and at quit (with "Quit Anyway / Cancel" if it still fails). An unreadable history at launch is never
overwritten: moving and trashing are disabled until the user starts a new history (the old file is renamed aside).
Reason: the user considers this an edge case and chose the simple option.

## app-sandbox

The app keeps the App Sandbox on. It has read-write access to user-selected files and stores a security-scoped
bookmark for each folder picked in Settings (archive root, each inbox), resolved once at launch. Reason: the app
can only touch folders the user granted, which guards an app that moves and trashes documents. This depends on one
condition the user set, verified in the sandboxed app on 2026-11-07: a bookmark to a folder gives read-write access
to its whole subtree. If it ever turns out false, turn the sandbox off. Apps built by `xcodebuild test` get extra
test-only read access to `/`, so sandbox read checks must use an app from a plain build. Folders reached through
symlinks outside a granted tree (for example an inbox `_Neu/Gemeinsam` that links to a shared folder elsewhere) are
not covered and need their own grant.

## agent-tooling

Nothing may capture the screen or audio: no computer use, no `screencapture`, no ScreenCaptureKit, no screenshots in
UI tests. Each makes macOS ask the user for Screen & System Audio Recording, which the user does not want to grant.
Visual checks use Xcode's `RenderPreview`; when only a look at the running app will do, ask the user. No third-party
automation tools (Peekaboo, MobileBuildMCP); built-in tools (`xcodebuild`, `swift test`, XCUITest, `log`) do the
work. Reason: user's choice after a tooling survey in the first session. How the Xcode MCP server is used: CLAUDE.md.

## no-real-data-in-repo

Test fixtures, mockups and examples never contain names, dates or details from the user's real archive. Write them
from scratch in the archive's style; never derive them from real names by swapping parts out. The real tree may serve
as a private, uncommitted benchmark. Anything that may contain sample data gets an independent privacy review before
it is published as an artifact or landed; the author's own check is not enough. Briefs must not invite drawing
sample names from the real archive. How to write sample data so it stays clean:
- A fresh subagent writes it from an abstract spec: the shapes and situations needed, no concrete names, dates or
  examples. It never reads the real archive, the old sample data, or notes from sessions that have seen the archive.
  A session whose context holds real data drifts back to it even when it means to invent.
- The fictional household has a different life situation from the user's.
- Its dates sit in clearly different years (2031–2039). The real archive has files on most days of recent
  years, so invented recent dates collide with real documents of the same kind.
Reason: the user asked for made-up names, and reviews caught leaks repeatedly (see the log).

## search-scoped-ranking

The destination search ranks closer folders first by default: at comparable match quality, a folder fewer levels
below the current scope wins, even over a deeper folder whose name matches exactly (the user types a common prefix,
not scattered letters). The archive root is a scope like any other. It is a setting, so the user can switch to
"exact name first" later. Reason: user's choice in the core review.

## swiftui-focus-binding

Put `.focused(_:equals:)` on the view that is `.focusable()` itself, never on a container around it: SwiftUI then
focuses the container's first focusable descendant, and with keyboard navigation on (System Settings › Keyboard, the
user's setting) plain buttons are focusable. Hosted unit tests can't check SwiftUI focus: the test host app is never
active, so focus writes and key events in its windows do nothing (even in a window that reports itself key); a focus
bug needs one targeted UI test (`targeted-ui-tests`). Reason: a click-to-focus bug (see the log).

## no-glass-in-panel-content

The filing panel's controls (search field, name field, lists) stay standard, without Liquid Glass. Liquid Glass belongs
to the navigation layer (toolbar, sidebars, inspectors) floating over content; the panel is content on an opaque
background, so glass there adds nothing and reads as an imitation. Reason: the user's choice after trying a glass
search field on screen (2026-11-09; see the log).
