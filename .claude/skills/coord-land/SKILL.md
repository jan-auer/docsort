---
name: coord-land
description: Hub only. Final gate when a coordinator reports its branch done - checks, reviews, and merges into master on the user's yes.
argument-hint: <branch name>
---

# Land a branch (coordinator workflow)

Only the hub lands work; if you are not the hub, stop and say so.

Branch to land: $ARGUMENTS. Never land `master` itself. The hub's checkout is on `master`; the branch lives in its
coordinator's worktree.

1. **Clean state.** The branch has no uncommitted changes in its worktree. If `master` moved since it started, ask its
   coordinator to merge `master` into the branch and resolve conflicts there, not on `master`.
2. **Checks.** Run every check command listed in the project's CLAUDE.md in the branch's worktree. If the project
   lists none yet, say so. Any failure stops the landing: send the output back to the coordinator.
3. **Review.** Run the `coord-reviewer` subagent on `git diff master...<branch>` together with the branch's report.
   Blocking findings stop the landing; list them for the branch to fix.
4. **Divergence.** The branch's report states its divergence (or "None"). If it is missing, ask for it. If the
   divergence changes something in `docs/decisions.md`, update that entry on the branch.
5. **Confirm.** Show the user: branch, commits, check results, review summary, divergence. Merge only on their yes.
6. **Merge.** In the hub's checkout on `master`: `git merge --no-ff <branch>`, then rerun the checks there.
7. **Record.** Add an entry at the top of `docs/landings.md` and commit it on `master`:

   ```
   ## <YYYY-MM-DD> <branch>: <one-line outcome>
   - What landed: <one or two lines>
   - Divergence: <from the report, or "None">
   - Follow-ups: <or "None">
   ```

8. **Clean up** only on the user's yes: remove the worktree (`git worktree remove`), delete the branch, and mark the
   coordinator's session as done (archive it when the session tools allow it).
