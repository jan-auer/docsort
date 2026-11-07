# Coordinator workflow

How work is organised in this project. CLAUDE.md imports this file, so every session loads it.

## Which role you have

Every session in this project loads these rules, so the role comes from how the session started:

- **The first message starts with `Role: coordinator`** → you are a coordinator for the task in that brief.
- **The first message starts with `Role: <agent-name>`** → you are that agent: follow `.claude/agents/<agent-name>.md`
  (or `~/.claude/agents/<agent-name>.md`) as your instructions, for the task in the brief.
- **Anything else** → you are **the hub**: the session the user talks to.
- **Subagents** (started with the Agent tool) follow their own agent definition; of these rules only "Reports" and
  "Hard rules" apply to them.

## Roles

- **The hub** is the user's standing session. It talks with the user, plans, starts and steers the other sessions,
  and lands their work. It does not write project code itself.
- **A coordinator** is a session in its own git worktree and branch, owning one feature, fix or experiment. It
  plans the details, delegates to subagents, verifies and reports. It writes code itself only for small glue changes.
- **An agent session** is a session running one named agent definition (for example a researcher), for work that
  outlives a single subagent call or needs the user's attention on its own.
- **Subagents** do bounded jobs inside a session: reconnaissance, one well-defined implementation step, tests for one
  module, a review. A subagent never plans the feature and never decides architecture.

## Project memory

Two files in the project carry what sessions learn. Read both before planning; keep them short.

- `docs/decisions.md`: lasting decisions, facts and lessons, one `## <slug>` heading each, with the reason. Add an
  entry when the user settles a design question or a lesson would save the next session time. Edit or remove entries
  that turn out wrong instead of appending contradictions.
- `docs/landings.md`: one entry per landed piece of work, newest first, written by the `coord-land` skill.

## How the hub works

1. Read `docs/decisions.md` and the latest entries of `docs/landings.md`.
2. Turn what the user asks for into work. Answer questions and do quick reads yourself; plan anything with more than
   one step with the `coord-plan` skill, and get the user's go on the plan.
3. Start the approved work with the `coord-start` skill: a coordinator session for each piece that changes code, an
   agent session for research or other work that ends in a document rather than a branch. The user's go on the plan
   is the go for starting its sessions. Start pieces one after another unless their files are disjoint.
4. Keep track of every session you started (its name, role, branch and state). When one finishes a turn, read its
   report: answer its question, forward it to the user, or, when its work is done and verified, land it with the
   `coord-land` skill.
5. Bring decisions to the user as one question at a time, with your recommendation. Record settled ones in
   `docs/decisions.md`.

## How a coordinator works

1. Read `docs/decisions.md` and the latest entries of `docs/landings.md`. On a resumed session, also read landings
   made since it started and check for overlap with your files.
2. Work on your own branch in your own worktree; never on `master`.
3. Bring design decisions to the hub (or, without a hub, the user) as questions; do not make architectural
   assumptions.
4. Delegate each step to a subagent with a brief naming the goal, the files, what is already ruled out and what done
   looks like.
5. Run subagents one after another. Run them in parallel only for read-only work or when their files are disjoint.
6. Verify each result yourself (read the diff, run the relevant tests) before starting the next step. A subagent's
   report is a claim, not proof.
7. Commit often on your branch: each independent change separately, each verified step as soon as it passes, and
   any work in progress (as a `WIP:` commit) before you end a turn or wait on the hub. Never leave a turn with
   uncommitted work; squash or reword before reporting if the history needs tidying.
8. Finish with a report (below). Do not merge; the hub lands your branch.

## Model and effort

Choose both for every subagent and every session you start, matched to the task: cheap and fast for mechanical or
reconnaissance work, stronger for implementation, the strongest at high effort for architecture and verification.
Coordinator sessions and the reviewer always run on the strongest model with high effort.

## Reports

Every handoff (subagent to session, session to hub, hub to user) ends with:

```
Done: <what is now true>
Not done / not verified: <or "Nothing">
Divergence: <how the result differs from the task as given: new agreements, a different approach, changed scope; or "None">
```

## Hard rules

- Nothing reaches `master` except through the `coord-land` skill, and only on the user's yes.
- Only the hub starts sessions. Coordinators and agent sessions use subagents.
- No two running sessions write to the same files.
- A subagent never starts sessions and never merges.
