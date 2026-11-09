# Decision log

How the choices in `docs/decisions.md` were reached: benchmarks, rejected alternatives, verifications and the incidents
behind them, under the same slug. Also lessons tied to one file, whose gist its code comments carry, and retired
decisions. Read an entry when revisiting its area; `decisions.md` holds the rules.

## Retired 2026-11-10

- `e2e-first` (get the thinnest end-to-end app first, with lighter reviews and tests): its goal is reached; replaced by
  `test-intent` and `coordinator-autonomy`.
- `autonomous-while-away`: void. It was a temporary mode while the user was away and never meant to persist; landing
  always needs the user's yes (`.claude/workflow.md`, Hard rules).
- `deferred-and-wanted-features`: renamed `date-shortcuts-deferred`; its live-watching half is built.
- `parallel-sessions` and `hub-delegates-research`: folded into `.claude/workflow.md` ("How the hub works").

## native-swift-app

The CLI's main limit was preview. Tauri with a web UI was considered and rejected: it would reuse docsort-cli's Rust
code but preview non-PDF files only as thumbnails.

## fuzzy-matching-library

The user's guidance was to prefer a mature library over writing a matcher, and their rule for choosing: "nucleo if it
is significantly better for my use, otherwise FuzzyMatch". On 66 CLI-style queries over the real archive (a private,
uncommitted benchmark), nucleo put the target first 41 times and FuzzyMatch 38, and both found it in the top 10 about
equally (49 vs 48). FuzzyMatch only misses low-scoring scattered-letter matches. The user accepts a Rust toolchain if
nucleo is ever needed.

## search-performance

On an M2, over the ~25,000-folder benchmark archive in Release: 16–60 ms per keystroke, worst 237 ms, before
`claude/search-lag-0bed3b`; 4–9 ms, worst 24 ms, after, with identical results. Lessons:
- Score through FuzzyMatch's `score(utf8:)` on contiguous strings; the index's paths are Foundation-bridged and slow
  to read otherwise.
- Spread scoring and highlighting over the cores with `ParallelChunks`, preparing the query per chunk: a shared
  prepared query makes every core update the same reference counts and halves the gain.
- Ask the index for exactly the rows shown (`DestinationIndex.search(_:in:outside:)` for Elsewhere) instead of
  over-fetching and filtering, since highlighting a match costs far more than scoring it.

## core-apple-frameworks

Decided by the hub on the architect's proposal, when the folder watcher needed CoreServices.

## filing-panel-redesign

Chosen by the user on 2026-11-08 from two design studies, now in git history: commit 89ca2be (destination search:
pattern research, three concepts, a clickable mockup) and f10cf0c (panel look: an assessment against the HIG and three
directions). The earlier approved mockup and the picker comparison are in 5097b2e, their reference screenshots in
f7a1538. The mockup's last version is in `bdff1c5^` (`docs/design/mockup.html`). The picker's drill-down list was chosen
over columns in design round 2 (ux.md, "Considered and rejected: columns with filter").

Destination search concepts:
- A, the path typed into the field Go-to-Folder style: the study recommended it; rejected by the user's choice. The
  chosen design keeps from A the default highlight on the first Elsewhere match and the New Folder offer.
- B, a path bar heading the list with the field holding only the query: rejected by the user's choice.
- C, soft scope: chosen.

Panel look concepts:
- A, a tidy pane (system type, spacing and controls in the same layout): its tidiness and contrast were kept.
- B, a grouped form in the System Settings idiom: rejected, because it borrows the settings idiom for a work surface
  (rows get taller, fewer folders fit, the list sits inside a box).
- C, list first, with the panel out of `.inspector`: its structure was kept.

## search-scoped-ranking

An earlier version of the entry said exact names always win from the archive root; that was the hub's misreading of one
example, not the user's decision.

## picker-inputs-arrive-late

`MainWindowModel` hands the index, recents and ranking to the picker through an `Observations` loop, which delivers them
on a later main-actor turn than the change that caused them. So after a move, the panel's `picker.reset()` runs before
the move's recents arrive. The picker therefore remembers where a reset placed the highlight and places it there again
on new inputs until the user changes the picker; otherwise it keeps the highlight by row id. Kept by id, the highlight
stayed on the previous top recent, one row below the folder just used. Code: `placementSinceReset` and
`reset(choosing:)` in `App/Picker/DestinationPickerModel.swift`.

## history-save-failure

Considered and not planned: write-ahead, recording a pending event before the move (in `docs/backlog.md`, should a
save failure ever bite).

## app-sandbox

Verified on 2026-11-07 in the real sandboxed app: a bookmark picked through the open panel and resolved in a new
process allowed listing, creating, renaming, moving between deep subfolders and trashing 3–5 levels deep; without
it, every operation failed.

## no-real-data-in-repo

Reviews caught leaks of real data five times: the core fixtures three times and the design mockups twice. The first
design brief allowed real names, and two transformations of real names kept real dates, items and listing details.
The first sample archive had to be rewritten from scratch and its branch squashed.

## screenshots-stay-private

On 2026-11-08 a real folder name relayed from one of the user's screenshots ended up in code, tests and a commit
message, and had to be removed from history before the repository was published.

## swiftui-focus-binding

Found in the click-to-focus bug in Folder contents (2026-11-09): with the binding on the drawer, a click focused the
header's chevron, and the list's keys never arrived.

## toolbar-glow-under-panel

The toolbar's blur over a scrolled PDF spans preview and filing panel because the PDF view runs under the panel
(Keynote's structure); the panel still starts below the toolbar. AppKit draws the scroll edge effect (`NSScrollPocket`)
only across a scroll view's width minus `contentInsets`, so the panel's share is reserved through PDFView's page margins
(`PartlyCoveredPDFView`), not content insets or safe-area insets. The system separator still stops at the panel; the
panel draws its own one-pixel line. Rejected on screen by the user (2026-11-09): a divider line through the toolbar, and
`.backgroundExtensionEffect()` (mirrored copies of the PDF everywhere). Content insets and safe-area insets were tried
first: AppKit's scroll edge effect stops at the content inset, so the blur ended at the panel.

## no-glass-in-panel-content

A glass search field was built as a spike and tried on screen; the user found the plain field cleaner (2026-11-09), and
the spike was not landed. It survives as 7cb1de8 on `claude/inspector-glass-6c32d3`. A full-height glass inspector,
where glass would fit, is parked on `claude/inspector-glass-6c32d3`.
