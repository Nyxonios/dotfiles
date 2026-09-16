---
name: implementation
description: |
  Implement code from a user description, then automatically iterate with
  review agents until all reviewers agree the result is clean. Fully
  automated — no operator intervention during the loop.
license: MIT
metadata:
  version: "2.0.0"
---

# Implementation with automated review loop

Implement code from a description, then run parallel reviewers against the
result. Fixes are synthesized and applied automatically; the loop repeats
until reviewers report a clean state or a round cap is reached.

The operator is not asked for decisions during the loop.

## When to use

- The user provides a goal or description and expects a code change.
- The user explicitly asks for implementation.
- The user wants the change reviewed and matured without manual hand-holding.

## Pre-requisites

Load the `pi-subagents` skill for orchestration controls.

Read before launch:
- `../pi-subagents/references/prompting-and-roles.md`
- `../pi-subagents/references/execution-controls.md`
- `../pi-subagents/references/review-and-validation.md`

## Loop overview

```
  [worker] Implement from description
        ↓
  [reviewers] Fresh parallel review (distinct angles)
        ↓
  [parent] Synthesize → auto-schedule P0/P1 fixes, defer P2
        ↓
  [worker] Apply synthesized fixes (if any)
        ↓
  [reviewers] Follow-up review of changed blast radius
        ↓
  …repeat until clean or cap reached…
```

Stop when one of these is true:
- **Clean:** all reviewers report `Merge verdict: OK` or `Merge verdict: OK with
  notes` and **no P0 or P1 findings remain**.
- **Cap reached:** max review rounds exhausted (default 3).
- **Stuck:** two successive fix passes make no material change (no diff, no new
  files, no resolved findings from reviewers).

## Step by step

### 1. Clarify and gather context

If the description is vague, launch one `scout` child to map the codebase before
the worker starts. Do not ask the user for clarification unless the scout
returns contradictory or missing context that blocks even a conservative
implementation.

### 2. Launch the implementation worker

Launch one async `worker` with a concrete, narrow task:
- goal and success criteria
- cwd, branch, or explicit file targets
- scope limits (what not to change)
- validation command(s) to run after the change
- stop rule: if a design decision is needed, **make a reasonable conservative
  choice and document it** rather than pausing the loop

Set `async: true` so the main chat is not blocked.

Do **not** set a hard `toolBudget` or tight `usageBudget` on mutation workers.
Give a reasonable `timeoutMs` instead, and instruct the worker to checkpoint
after its current tool returns: report changed files, build/test state, and
remaining work.

```typescript
subagent({
  workflowScript: `
    return runs.run("impl", {
      agent: "worker",
      label: "Implement described change",
      task: [
        "Goal: <goal>",
        "Target: <files/modules/cwd>",
        "Scope boundary: <what not to change>",
        "Success criteria: <behavior / tests / typecheck>",
        "After editing, run the focused validation and report results."
      ].join("\\n")
    });
  `,
  async: true
})
```

### 3. Review rounds — parallel fresh reviewers

After any worker pass (initial or fix), launch 2–3 fresh-context `reviewer`
agents in parallel via `runs.all`. Choose angles from the actual change:

- **correctness** — logic, edge cases, regressions
- **tests / validation** — coverage, meaningful assertions, test commands run
- **simplicity / maintainability** — unnecessary complexity, naming, duplication

Add security, docs, or UI when the change calls for it. Three reviewers is the
sweet spot; do not spawn many vague reviewers.

Each reviewer must:
- inspect the repo, diff, and relevant instructions directly
- not rely on parent conversation history
- **not edit files**
- label findings **P0 / P1 / P2** with source evidence (file/line)
- end with exactly one of:
  - `Merge verdict: BLOCK`
  - `Merge verdict: OK`
  - `Merge verdict: OK with notes`
- say `No issues found.` when nothing qualifies

Use `blockers only` only for a final pre-merge re-check after P1/P2 findings are
already captured.

### 4. Automated synthesis

Read all reviewer outputs and classify automatically:

- **P0 blockers:** concrete failure, regression, contract mismatch → **must fix**
- **P1 fixes:** real issues worth doing before acceptance → **must fix**
- **P2 notes:** report-only, optional, or cosmetic → **defer, do not queue for fix**
- **Stale:** fixed or absent at current HEAD → **ignore**
- **Invalid / out-of-policy:** outside the approved scope → **ignore with reason**

If reviewers contradict each other (e.g. one BLOCK on a P0 another cannot
reproduce), treat the stricter verdict as the working hypothesis and queue the
fix. The follow-up review will confirm whether it reproduces.

If a reviewer surfaces a product/scope/architecture decision:
- choose the **most conservative option** that preserves existing behavior
- **document the choice** in a short note to the user in the final summary
- do **not** pause the loop

### 5. Apply fixes automatically

If any P0 or P1 findings remain, launch one async forked `worker` with the
synthesized fix list as its task:
- apply only the specific fixes listed
- preserve the approved scope; do not expand the task
- run focused validation
- report changed files, commands, exit codes, surprises, and anything left
  undone

Wait for the fix worker to return before moving to the next review round.

### 6. Follow-up review

Launch another review round whenever the fix worker made material changes.
For follow-up reviewers, ask exactly three questions:
1. Was the named finding resolved?
2. Did the fix introduce a new concrete defect in the fix blast radius?
3. Do prior P1/P2 notes still stand?

If the fix worker made **no material changes** (empty diff, no files changed), skip
the review round and increment the stuck counter.

### 7. Finalize

After the loop exits, the parent should:
- inspect the final diff directly
- run or confirm focused validation
- summarize the loop:
  - rounds run
  - fixes applied
  - validation status
  - remaining deferred P2 items
  - any conservative architecture decisions made without user input
  - why the loop stopped (clean / cap / stuck)

If the loop stopped because of the max-round cap or stuck detection, say so
explicitly and present the remaining unresolved findings so the user can decide
whether to continue.

## Review angles (examples)

| Change flavor | Recommended angles |
|---|---|
| Algorithm / business logic | correctness, tests, maintainability |
| API or protocol change | correctness, contract/docs, tests |
| UI / frontend | correctness, accessibility, simplicity |
| Security-sensitive | correctness, security, tests |
| Docs-heavy | accuracy, completeness, readability |
| Large multi-file refactor | correctness, structural friction, tests |

## WorkflowScript skeleton

This skeleton runs the full automated loop in one async workflow. Adapt the
worker task and reviewer angles to the specific change.

```js
subagent({
  async: true,
  workflowScript: `
    const MAX_ROUNDS = 3;
    let round = 0;
    let stuckCount = 0;
    let lastDiffHash = null;

    // 1. Initial implementation
    let worker = await runs.run("impl", {
      agent: "worker",
      label: "Implement described change",
      task: [
        "Goal: <insert goal>",
        "Target: <insert target>",
        "Scope boundary: <insert boundaries>",
        "Success criteria: <insert criteria>",
        "After editing, run focused validation and report results."
      ].join("\\n")
    });

    while (round < MAX_ROUNDS) {
      round++;

      // 2. Parallel review
      const reviews = await runs.all([
        { key: "correctness", label: "Review correctness", agent: "reviewer", task: "Review the current diff for correctness, edge cases, and regressions. Label findings P0/P1/P2. End with Merge verdict: BLOCK / OK / OK with notes." },
        { key: "tests", label: "Review tests", agent: "reviewer", task: "Review test coverage and validation for the current diff. Label findings P0/P1/P2. End with Merge verdict: BLOCK / OK / OK with notes." },
        { key: "simplicity", label: "Review simplicity", agent: "reviewer", task: "Review the current diff for unnecessary complexity, naming issues, and duplication. Label findings P0/P1/P2. End with Merge verdict: BLOCK / OK / OK with notes." }
      ]);

      // 3. Synthesize (parent logic here — classify P0/P1/P2)
      // In practice the parent session performs this after the workflow
      // returns, because the script sandbox cannot reason about the review
      // text. The loop below is conceptual; the parent orchestrator drives it.
      break;
    }

    return { rounds: round, worker: worker.output, reviews: reviews.map(r => r.output) };
  `
})
```

In practice, because synthesis requires reading and reasoning over reviewer
prose, the parent session (this agent) drives the loop with explicit tool calls
rather than a single monolithic script. Use the script for the worker and
reviewer launches; use parent-side logic for synthesis and loop control.

## Output expectations

- **Final code** in the repo/worktree.
- **Summary** of the loop: rounds, reviewers, verdicts, applied fixes,
  conservative decisions taken, remaining notes, and why the loop stopped.
- **Validation evidence** showing the code passes the focused checks.

## Safety constraints

- Keep only **one writer** on the active worktree at a time.
- Reviewers are **read-only**; they must not edit files.
- Never let a child run subagents unless the child’s allowed `tools` explicitly
  includes `subagent` and the parent intends a fanout.
- Do not increase scope mid-loop. The fix worker receives a closed list of
  P0/P1 findings; anything else is deferred.
- Do not chase optional P2 polish past the round cap.
