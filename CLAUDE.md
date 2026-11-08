# docsort-ui

@.claude/workflow.md

Default branch: `master`. Project memory lives in `docs/decisions.md` and `docs/landings.md`; the workflow above says
how to use them.

## Toolchain

- Xcode 27.2, Swift 6.4, macOS 27 only. No signing team: ad-hoc "Sign to Run Locally".
- `Docsort.xcodeproj` uses Xcode's JSON project format (`project.xcproj`); edit it directly when targets, settings or
  packages change, then run `xcrun xcprojformatter --update Docsort.xcodeproj`. `App/`, `AppTests/` and `UITests/` are
  synchronized folders: adding, renaming or removing files there needs no project change.
- `App/`: the SwiftUI app target `Docsort` (default actor isolation `MainActor`). `AppTests/`: the app's unit tests
  (`DocsortTests`, Swift Testing, `@testable import Docsort`), hosted by the app. `UITests/`: XCTest UI tests
  (`DocsortUITests`). `Packages/DocsortCore`: local Swift package for all non-UI logic (nonisolated by default), linked
  by the app.
- Unit tests: Swift Testing, in the package and in `DocsortTests` for the app's models. When the app hosts unit
  tests (`XCTestConfigurationFilePath` is set), `AppEnvironment.forCurrentProcess()` gives it an inert environment
  (an emptied `UserDefaults` suite of its own, no folders, a history file in the temporary directory), so tests never
  touch the user's settings, bookmarks or history; tests build their own environments with fake bookmarks.
- UI tests: XCTest with `XCUIApplication`; find views by `.accessibilityIdentifier` (kebab-case, e.g. `main-window`,
  `settings-window`).
- Formatter and linter: the swift-format bundled with Xcode (`swift format`), default config, no `.swift-format` file.
- Logging: `os.Logger` with subsystem `org.jauer.Docsort` (see `App/Loggers.swift`).
- App Sandbox is on (see `app-sandbox` in `docs/decisions.md`): read-write access to user-selected files via the
  `ENABLE_USER_SELECTED_FILES` build setting, app-scoped security bookmarks via `App/Docsort.entitlements`.

## Core package

- `Packages/DocsortCore` is organised by concern (`Settings`, `Inbox`, `Destinations`, `FileOperations`, `History`,
  `Recents`, `Preferences`, `FileSystem`); the module doc in `DocsortCore.swift` lists what each holds.
- Its one dependency is ordo-one/FuzzyMatch, pinned `exact: "1.4.0"` with `Package.resolved` committed (decision
  `fuzzy-matching-library`). Ranking changes must keep `DestinationRankingTests` passing.
- Test fixtures and examples follow `no-real-data-in-repo`: invented from scratch for a fictional household whose life
  differs from the user's, with every date in clearly different years (2031–2039), never derived from real names.
  Only generic category words (Rechnungen, Versicherungen) are shared. Sample data gets an independent privacy review
  before it lands. Tests build file trees with `TemporaryDirectory` and set dates explicitly instead of sleeping.

## Check Commands

Run before declaring work done:

```
swift format lint --strict --recursive --parallel App AppTests UITests Packages
swift test --package-path Packages/DocsortCore
xcodebuild -project Docsort.xcodeproj -scheme Docsort -destination 'platform=macOS' -derivedDataPath .build/xcode -quiet build
xcodebuild -project Docsort.xcodeproj -scheme Docsort -destination 'platform=macOS' -derivedDataPath .build/xcode -quiet test -only-testing:DocsortTests
```

The last command runs the app's unit tests. It launches the app briefly as their host (with the inert environment);
it captures nothing and takes over neither keyboard nor screen.

Fix formatting with `swift format --in-place --recursive --parallel App AppTests UITests Packages`. Keep `-derivedDataPath`
inside the worktree so parallel worktrees never share build state.

UI tests are not part of the default checks: they launch the app and take over keyboard and screen. Run them when
changing UI flows:

```
xcodebuild -project Docsort.xcodeproj -scheme Docsort -destination 'platform=macOS' -derivedDataPath .build/xcode -quiet test -only-testing:DocsortUITests
```

Every UI test launches the app with `-docsort-ui-test-fixture` (debug builds only, `AppLaunchMode.uiTestFixture`):
the app then builds an invented archive `Archiv` with the inboxes `_Neu/Web-Downloads` and `_Neu/Scanner` fresh in
its container's temporary directory (`App/Fixture/UITestFixture.swift`), configures them through real bookmarks in an
emptied `UserDefaults` suite, keeps its history there and "trashes" into a folder of the fixture. So no UI test
reads or changes the user's settings, history or Trash. Sidebar rows (`sidebar-row`, labelled with the inbox file
name) report `unfiled`, `filed`, `trashed` or `downloading` as their accessibility value.

They need a logged-in GUI session. If a run asks for a password to allow UI automation, the user can run
`sudo automationmodetool enable-automationmode-without-authentication` once to stop the prompt.

The scheme runs them through `Docsort.xctestplan`, which turns off automatic screen capture
(`uiTestingScreenshotsLifetime: keepNever`; since Xcode 15 UI tests record the screen by default) and keeps no
attachments. Keep it that way: nothing may capture the screen (`agent-tooling`). Tests assert on elements and
accessibility identifiers only. Send keystrokes to a window element (`mainWindow.typeKey(…)`), not to the
`XCUIApplication`: on macOS 27 a key event on the application element aborts the test runner.

## Running the App

```
open .build/xcode/Build/Products/Debug/Docsort.app
/usr/bin/log stream --predicate 'subsystem == "org.jauer.Docsort"'
```

Use `/usr/bin/log`: in zsh, `log` is a builtin. `log stream` shows `.info` and `.debug` messages only with
`--level info` or `--level debug`; `log show` needs `--info` or `--debug` for them.

## Xcode MCP (previews only)

The project's `.mcp.json` registers Xcode's MCP server (`xcrun mcpbridge`). Use it only for `RenderPreview`, to look
at a SwiftUI `#Preview` as a PNG without launching the app. Never use its `BuildProject` or test tools to verify
work: a build started within seconds of a file change on disk can miss the change and report success, so its results
can be silently stale. The check commands above stay the only way to verify.

Steps that work:

1. Call `XcodeOpenWorkspace` with the absolute path of this worktree's `Docsort.xcodeproj`. It returns a
   `workspaceIdentifier`. Other worktrees have their own path and identifier; never open another worktree's project.
2. Pass that `workspaceIdentifier` to every tool. The tool list advertises `tabIdentifier`, but the tools reject it.
3. Give `RenderPreview` navigator-relative file paths (`App/MainWindowView.swift`), not absolute paths.
4. When done, call `XcodeCloseWorkspace`. Rendering a preview of this macOS app launches the real `Docsort.app` from
   Xcode's own DerivedData and leaves it running. While it runs, `xcodebuild test` hangs before any test starts,
   because the test host has the same bundle identifier. Closing the workspace quits it.
5. Snapshots are static: content that loads asynchronously (PDF pages, Quick Look) does not appear in them.

Xcode asks the user to allow each agent and each folder (worktree) the first time, and the grant lasts 24 hours. The
user, not an agent, can grant the whole repository with
`sudo xcrun mcp-server allow-folder /Users/jauer/Coding/docsort-ui --always` (or `--for-24-hours`). Its help
describes this as permitting headless Xcode to serve workspaces from that folder and its subfolders; whether it also
removes the Allow dialog for a running Xcode is unverified.
