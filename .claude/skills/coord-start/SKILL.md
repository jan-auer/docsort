---
name: coord-start
description: Hub only. Starts a coordinator session (own worktree and branch) or a named agent session for an approved piece of work.
argument-hint: <coordinator|agent-name> <task>
---

# Start a session (coordinator workflow)

Only the hub starts sessions; if you are not the hub, stop and say so.

Request: $ARGUMENTS

1. **Role.** `coordinator` for work that changes code; an agent name from `.claude/agents/` (or `~/.claude/agents/`)
   for anything else (for example research that ends in a document).
2. **Overlap.** Check the files it will write do not overlap a session that is still running (your list of started
   sessions, `git worktree list`). If they overlap, wait or ask the user; do not start it.
3. **Committed baseline.** A new worktree only contains what is committed on `master`. If `master` has no commits, or
   CLAUDE.md or `docs/` have uncommitted changes, ask the user to commit them first.
4. **Branch.** A coordinator gets `branch/<slug>` (short kebab-case slug). An agent session that only reads or
   writes documents needs no branch unless it writes into the repository.
5. **Brief.** The new session's first message, in this shape:

   ```
   Role: <coordinator | agent-name>

   Task: <the task in your own words, and what done looks like>
   Context: <relevant docs/decisions.md entries by slug, landings it builds on, what is already ruled out>
   Owns: <files or areas it may write>
   Finish with the report from the coordinator workflow. Do not merge; the hub lands the work.
   ```

6. **Start.**
   - In the Claude desktop app, start it with the session tool (`start_session`): a fresh session with the brief as
     its prompt, with its own worktree and the branch name for a coordinator.
   - Without a session tool, run `git worktree add ../<project>-<slug> -b branch/<slug>`, then give the user the
     brief and the folder to open a session in.
7. **Track.** Record its name, role, branch and the files it owns, and tell the user in one line what started.
