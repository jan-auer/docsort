# Open questions for the user

Collected by the hub while the user is away. Each has the hub's recommendation; nothing here blocks work.

1. **Drop old commits holding real data.** Pre-rewrite commits of the design and core branches are unreachable but
   still in the local object store. Recommendation: run
   `git reflog expire --expire=now --all && git gc --prune=now` once all current branches have landed.
2. **Ranking from the archive root.** The root behaves like any folder: closer folders win over a deeper exact name
   match, unless Settings › Search says "Exact name matches". Recommendation: keep it; switch the setting if it feels
   wrong in use.
3. **Ideas from the layout research** (report on branch `claude/layout-research-068c21`): a ⌘K command palette, open
   Finder windows and pinned folders as destinations, a focus-preview toggle, suggestion chips with per-source
   defaults. None are planned. Recommendation: revisit after using the app for a while.
4. **Write-ahead filing history** (record before moving, so a crash can't lose an entry). Not planned; the simple
   "keep and warn" policy is in place. Recommendation: only if a save failure ever bites.
5. **Run the hosted tests once you're back.** The screen locked while you were away, so app unit tests and UI tests
   could not run after about 01:30; work since then landed on lint, builds, core `swift test`, launch logs and review.
   Recommendation: after unlocking (and item 6), have a session run the full app test suite and UI tests and fix
   whatever fails.
6. **Allow UI tests without a password prompt.** UI tests (keyboard flow, sandbox bookmark check) can't run while
   nobody is at the Mac: automation mode needs authentication. Recommendation: run once
   `sudo automationmodetool enable-automationmode-without-authentication`, then have the UI tests rerun.
7. **Research branch.** `claude/layout-research-068c21` holds the report and is not merged. Recommendation: keep
   until question 3 is settled, then delete.
