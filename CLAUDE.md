# docsort-ui

@.claude/workflow.md

Default branch: `master`. Project memory lives in `docs/decisions.md` and `docs/landings.md`; the workflow above says
how to use them.

## Toolchain

- Xcode 27.2, Swift 6.4, macOS 27 only. No signing team: ad-hoc "Sign to Run Locally".
- `Docsort.xcodeproj` uses Xcode's JSON project format (`project.xcproj`); edit it directly when targets, settings or
  packages change, then run `xcrun xcprojformatter --update Docsort.xcodeproj`. `App/` and `UITests/` are synchronized
  folders: adding, renaming or removing files there needs no project change.
- `App/`: the SwiftUI app target `Docsort` (default actor isolation `MainActor`). `UITests/`: XCTest UI tests
  (`DocsortUITests`). `Packages/DocsortCore`: local Swift package for all non-UI logic (nonisolated by default), linked
  by the app.
- Unit tests: Swift Testing, in the package. UI tests: XCTest with `XCUIApplication`; find views by
  `.accessibilityIdentifier` (kebab-case, e.g. `main-window`, `settings-window`).
- Formatter and linter: the swift-format bundled with Xcode (`swift format`), default config, no `.swift-format` file.
- Logging: `os.Logger` with subsystem `org.jauer.Docsort` (see `App/Loggers.swift`).
- App Sandbox is on (see `app-sandbox` in `docs/decisions.md`): read-write access to user-selected files via the
  `ENABLE_USER_SELECTED_FILES` build setting, app-scoped security bookmarks via `App/Docsort.entitlements`.

## Core package

- `Packages/DocsortCore` is organised by concern (`Settings`, `Inbox`, `Destinations`, `FileOperations`, `History`,
  `Recents`, `Preferences`, `FileSystem`); the module doc in `DocsortCore.swift` lists what each holds.
- Its one dependency is ordo-one/FuzzyMatch, pinned `exact: "1.4.0"` with `Package.resolved` committed (decision
  `fuzzy-matching-library`). Ranking changes must keep `DestinationRankingTests` passing.
- Test fixtures use invented names modelled on the real archive, never real folder or file names; generic category
  words (Rechnungen, Versicherungen) may stay. Tests build file trees with `TemporaryDirectory` and set dates
  explicitly instead of sleeping.

## Check Commands

Run before declaring work done:

```
swift format lint --strict --recursive --parallel App UITests Packages
swift test --package-path Packages/DocsortCore
xcodebuild -project Docsort.xcodeproj -scheme Docsort -destination 'platform=macOS' -derivedDataPath .build/xcode -quiet build
```

Fix formatting with `swift format --in-place --recursive --parallel App UITests Packages`. Keep `-derivedDataPath`
inside the worktree so parallel worktrees never share build state.

UI tests are not part of the default checks: they launch the app and take over keyboard and screen. Run them when
changing UI flows:

```
xcodebuild -project Docsort.xcodeproj -scheme Docsort -destination 'platform=macOS' -derivedDataPath .build/xcode -quiet test -only-testing:DocsortUITests
```

They need a logged-in GUI session. If a run asks for a password to allow UI automation, the user can run
`sudo automationmodetool enable-automationmode-without-authentication` once to stop the prompt.

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

Xcode asks the user to allow each agent and each folder (worktree) the first time, and the grant lasts 24 hours. The
user, not an agent, can grant the whole repository with
`sudo xcrun mcp-server allow-folder /Users/jauer/Coding/docsort-ui --always` (or `--for-24-hours`). Its help
describes this as permitting headless Xcode to serve workspaces from that folder and its subfolders; whether it also
removes the Allow dialog for a running Xcode is unverified.
