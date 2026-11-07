---
name: coord-plan
description: Hub or coordinator. Breaks a feature or task into delegable steps and gets the user's go.
argument-hint: <feature or task>
---

# Plan a feature (coordinator workflow)

Task to plan: $ARGUMENTS

1. Read `docs/decisions.md` and the latest entries of `docs/landings.md`.
2. Run a cheap, read-only reconnaissance subagent if you do not yet know which files the task touches.
   Ask it for file paths and the relevant facts, not file dumps.
3. List the open design decisions. Ask the user about each one, with your recommendation, before planning around it.
4. Write the plan as numbered pieces. For each give:
   - **Goal**: one sentence, what is true when it is done.
   - **Files**: the files or areas it touches.
   - **Runs as**:
     - as the hub: `coordinator session`, `<agent-name> session`, or `here` (a quick read or answer only);
     - as a coordinator: `subagent` or `here` (small glue only);
     - for every session or subagent, the model and effort it runs at (see "Model and effort" in the workflow).
   - **Depends on**: earlier piece numbers, or "none".
   - **Check**: the test or command that shows it works. For new behaviour, the failing test comes first.
5. Mark the pieces that could run in parallel, and say why their files do not overlap.
6. Show the plan to the user and wait for their go. As the hub, start the approved pieces with the `coord-start`
   skill in dependency order.
