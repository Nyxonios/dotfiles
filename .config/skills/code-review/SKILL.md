---
name: code-review
description: >
  Platform-agnostic thorough multi-pass code review of diffs, commit ranges, or
  file sets. Delegates each review pass to parallel fresh-context sub-agents,
  verifies every finding through a second-pass gate that drops false positives,
  synthesises findings into a structured severity-ranked report, provides
  file:line evidence, and concrete fixes. Read-only — never modifies code.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: review
---

# Skill: code-review

## Overview

This skill performs thorough, multi-pass code review on any set of code
changes. It is platform-agnostic — it does not talk to GitLab, GitHub, or any
remote system. It reviews code that is provided to it as input.

The review is organised as **seven focused passes**, each delegated to an
independent fresh-context sub-agent running in parallel. The parent
orchestrator controls the workflow, collects findings, runs every candidate
through a verification gate that drops false positives, and synthesises a
severity-ranked actionable report. This mirrors the review-loop pattern used
for implementation-fix cycles, but is kept strictly read-only (no fix
workers).

**Companion skills**:
- `gitlab-review-mr` — GitLab orchestrator that fetches MR data and delegates
  the review to this skill.
- `gitlab-analyze-review-comments` — Fetches existing review comments to avoid
  duplicating feedback.

**Key principle**: Read-only. This skill never edits files, posts comments, or
modifies any state.

## Input Specification

When this skill is used, it expects one of the following inputs to be assembled
and passed to it by the calling context (another skill, a pi command, or the
user).

### Required Input

| Field | Description |
|-------|-------------|
| **Diff** | The unified diff (`git diff`) or patch representing the changes. If the caller has a commit range, produce the diff first. |
| **Context** | What this change is trying to accomplish. A PR/MR description, ticket summary, or 1-3 sentence goal statement. |

### Optional Input

| Field | Description |
|-------|-------------|
| **Full files** | Current content of changed files. Strongly recommended for context outside the diff hunk. |
| **Commit messages** | List of commit messages in the change set. Helps understand intent and incremental thinking. |
| **Target branch** | The branch this change targets. Helps understand conventions and baseline. |
| **Depth** | `quick` → Passes 1-3 only (blast radius, correctness, security).<br>`standard` (default) → Passes 1-6.<br>`deep` → All 7 passes + architecture deep-dive. |
| **Focus** | Prioritise a specific angle: `security`, `performance`, `correctness`. Other passes still run but the focused pass is expanded. |
| **Existing comments** | Prior review comments on the same change. Filter out findings that duplicate these. |
| **Tech stack / conventions** | Language, framework, linter rules, known patterns. Helps avoid false positives. |
| **Review scope** | Files or directories to focus on, or patterns to ignore (e.g. generated files, `vendor/`). |

## Step-by-Step Review Methodology

### Step 0: Assemble Review Material

Ensure all input fields above are available. If the caller only provided a
commit range or number of commits, materialise the diff first:

```bash
# Last N commits
git diff HEAD~N..HEAD

# Specific range
git diff <base>..HEAD

# Full file contents after changes
git show HEAD:<file> # or read local files
```

If the diff exceeds ~500 changed lines, note this in the report and consider
recommending that the change be split.

Produce a **Blast Radius summary** yourself (this stays in the orchestrator,
not delegated):

```
BLAST RADIUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Touching: <subsystem list>
Risk surfaces: <auth | payments | schema | public API | deploy | none>
Reversible: <yes / no / unknown>
Dependency impact: <files importing changed surfaces>
Skipped in review: <generated / vendored / lockfiles>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

> **Escape hatch**: If this is a trivial change (e.g. typo fix, one-line logging
> improvement) and touches no risk surfaces, produce a brief blast radius
> summary and reduce remaining passes to a lighter scan.

### Step 1: Parallel Review Pass Sub-Agents

**DO NOT perform the review passes yourself.** Instead, launch parallel
fresh-context reviewers via the `subagent` tool.

Each reviewer receives:
- The diff
- Full file contents
- Commit messages
- The change context/goal
- Tech stack hints
- Existing comments (if any)
- Their specific pass mandate and output format
- The blast radius summary

**Reviewer rules** (must be included in each sub-agent task):
- Focus ONLY on the diff (changed lines and their immediate context).
- Use full files for context only — do not critique unchanged code unless it
  directly explains a bug in the diff.
- Demand `file:line` evidence for every finding. No evidence = discard.
- Provide a concrete fix or next step, not vague advice.
- If there are no substantive findings, respond with exactly:
  `No issues found in this pass.` — then still close with your
  Declined-to-judge list (below).
- Skip cosmetics (whitespace, import order, formatting) — assume a linter
  handles those.
- Label every finding with severity: **P0** (blocking), **P1** (high), **P2** (medium).
- Close every report with a **Declined to judge** list: anything you noticed
  but deliberately set aside as outside your pass's mandate, one line each
  (`<observation> — <reason>`). It is a coverage record, not a findings
  list — never smuggle a finding into it. If nothing was set aside, respond
  with exactly: `Declined: none.`

**Launch all reviewers in parallel as async subagents.** Use `async: true`.

**Thinking mode — MANDATORY**: Every reviewer sub-agent MUST run with
thinking set to **high**. In each `subagent` call, pass the model with the
`:high` suffix (e.g. `model: "anthropic/claude-sonnet-4:high"`); the suffix
overrides the agent's thinking default while keeping the model. Never launch
a reviewer at a lower thinking level — review quality depends on deeper
reasoning. If the environment rejects model IDs with thinking suffixes, set
`subagents.agentOverrides.<name>.thinking: "high"` in user or project settings
instead so reviewers still resolve to high thinking.

#### Reviewer 1 — Correctness & Logic

Role: Senior engineer hunting real bugs.

Checks (to include in task):
- Logic errors in conditions, loops, arithmetic, state transitions
- Null / undefined / zero-length safety on all new code paths
- Error handling: are new error paths properly handled? Are existing handlers
  bypassed or weakened?
- Edge cases: empty input, max values, boundary conditions, race conditions
- Concurrency: async/await, locks, goroutines, channels — are new async paths
  safe?
- Type safety: new type assertions, casts, any/unknown usage
- Resource leaks: files, connections, subscriptions, timers not cleaned up
- State management: initialization order, mutation side effects, global state

Output format per finding:
```
[PASS-1] <Severity> — <one-line title>
  File: <path>:<line>
  Problem: <one sentence>
  Fix: <concrete change, <= 30 words>
```

#### Reviewer 2 — Security

Role: Security auditor. OWASP-aware.

Checks:
- Injection: SQL, NoSQL, command, template, LDAP, XPath
- New user input that reaches any interpreter without validation/sanitisation
- Hardcoded secrets, tokens, credentials, private keys
- Authentication/authorisation checks removed, weakened, or bypassed
- Unvalidated redirects, SSRF, path traversal via new file handling
- Logging that now leaks PII, tokens, or sensitive data
- Unsafe deserialization or unvalidated input to `eval` / `exec`
- Insecure crypto: weak algorithms, predictable IVs, missing MAC
- Secrets in error messages returned to clients
- New dependencies — are they trustworthy and actively maintained?

Output format per finding:
```
[PASS-2] <Severity> — <one-line title>
  File: <path>:<line>
  Category: <OWASP category or risk type>
  Exploit scenario: <one sentence>
  Fix: <concrete mitigation, <= 30 words>
```

#### Reviewer 3 — Performance

Role: SRE / performance engineer.

Checks:
- New synchronous I/O in hot paths (loops, request handlers)
- N+1 query patterns introduced (loop + DB/API call inside)
- Algorithmic complexity regressions (e.g. nested loops on unbounded data)
- Memory: large allocations, unbounded caches, leaks, closure captures
- New heavy imports eagerly loaded on startup
- Unnecessary re-renders, context providers wrapping too much (UI)
- Missing batching or pagination on unbounded collections
- Blocking the event loop / main thread (Node, browser)
- Expensive operations in constructors or render paths
- Inefficient string concatenation in loops

Output format per finding:
```
[PASS-3] <Severity> — <one-line title>
  File: <path>:<line>
  Impact: <throughput / latency / memory / startup>
  Fix: <concrete optimisation, <= 30 words>
```

#### Reviewer 4 — Testing & Validation

Role: QA engineer looking for gaps.

Checks:
- New branches without tests (conditions, error paths)
- Modified branches whose existing test still passes against BOTH old and new
  behaviour (the test proves nothing)
- New error paths without corresponding test assertions
- Missing boundary / edge case tests for new logic
- Flaky tests introduced (timing-dependent, non-deterministic data)
- Tests that assert on implementation rather than behaviour
- Mock/stub misuse that hides real integration issues
- Test names that do not describe the scenario under test

Output format per finding:
```
[PASS-4] <Severity> — <one-line title>
  File: <path>:<line>
  Gap: <what is missing or wrong>
  Suggested test: <what should be asserted, <= 30 words>
```

#### Reviewer 5 — Architecture & Maintainability

Role: Staff engineer reviewing structural health.

Checks:
- Single Responsibility Principle violations (functions/classes doing too much)
- Coupling: new dependencies on unstable or distant modules
- Duplication & reuse: owned by Reviewer 6 (Simplification & Reuse) — do not
  raise here
- Naming: misleading names, abbreviations, inconsistent casing
- Comments: explain WHY not WHAT; remove obsolete comments
- Magic numbers / strings that should be constants
- Deep nesting that hinders readability
- API surface changes: backwards compatibility, deprecation path
- Configuration drift: new env vars without `.env.example` updates
- Feature flags: should risky changes be behind a flag?

Output format per finding:
```
[PASS-5] <Severity> — <one-line title>
  File: <path>:<line>
  Problem: <why this hurts maintainability>
  Fix: <concrete refactor, <= 30 words>
```

#### Reviewer 6 — Simplification & Reuse

Role: Refactoring specialist hunting needless complexity and missed reuse.

Checks (to include in task):
- Repeated code: blocks duplicated 2+ times within the diff or the same
  file that should be extracted into a function, method, helper, or loop
- Near-duplicates: copy-paste with small variations that should become one
  parametrised function (parallel branches, similar handlers, repeated
  setup/teardown)
- Reinvented wheels: hand-rolled logic that the standard library, framework,
  or an existing internal helper already provides — reuse it, and cite the
  existing helper's file:line
- Simplifiable logic: conditionals that a guard clause or early return would
  flatten; double negatives; unnecessary `else` after `return`; redundant
  null/zero checks; collapsible nested ifs
- Dead code introduced by this change: unreachable branches, unused
  variables, parameters, or imports; assignments always overwritten
- Over-engineering (YAGNI): speculative abstraction, single-implementation
  interfaces, unused knobs/config, wrappers that add nothing — code should
  solve today's problem, not imagined future ones
- Overly clever code: surprising tricks, golfed one-liners where a plain
  construct achieves the same result more clearly
- Long new functions mixing abstraction levels — extract well-named steps
  so each level of detail is glanceable
- Named code smells, when they fit: Duplicated Code, Speculative Generality,
  Middle Man, Feature Envy, Data Clumps, Primitive Obsession, Repeated
  Switches, Shotgun Surgery, Divergent Change — label them as judgement
  calls ("possible Feature Envy"), never hard violations

Special permissions (this reviewer only):
- May search the repository (grep / ripgrep) to locate existing helpers,
  utilities, and near-duplicate logic outside the changed files — other
  passes must not do this. Still focus findings on the diff: point at
  existing code to *reuse*, never critique it.
- Simplifications must be behaviour-preserving. If the simpler version would
  change semantics, it is a correctness issue — do not report it here.

Severity guidance: most findings here are P2. Only escalate to P1 when the
duplication or complexity actively risks hiding a real bug (e.g. the same
fix must now be made in N places). P0 is almost never appropriate for a
simplification finding.

Output format per finding:
```
[PASS-6] <Severity> — <one-line title>
  File: <path>:<line>
  Simplification: <what is duplicated or more complex than needed>
  Reuse target: <path>:<line of existing helper to call, or "none">
  Fix: <concrete refactor, <= 30 words>
```

#### Reviewer 7 — Completeness & Documentation (deep mode only)

Role: Release captain.

Checks:
- Changed env vars? → `.env.example` and docs updated?
- Changed API route / schema? → OpenAPI / client SDK / protobuf docs?
- New migration? → rollback plan, seed data, idempotency on retry?
- New feature? → changelog, README, runbook update?
- Changed a type / interface? → all consumers updated?
- New error? → user-facing messaging and support docs?
- New metric / log? → dashboard / alert update?
- Public API change? → versioning and deprecation notice?

Output format per finding:
```
[PASS-7] <Severity> — <one-line title>
  Category: <env | api-docs | migration | changelog | runbook | monitoring>
  Missing: <what should exist>
  Action: <who should do what, <= 30 words>
```

**Depth filtering** — launch only the relevant reviewers:

| Depth | Reviewers launched |
|-------|-------------------|
| `quick` | 1, 2, 3 (Correctness, Security, Performance) |
| `standard` (default) | 1, 2, 3, 4, 5, 6 (all above) |
| `deep` | 1, 2, 3, 4, 5, 6, 7 (all) |
### Step 2: Await Sub-Agent Results

Wait for all async reviewer sub-agents to complete. Collect their outputs:
findings and each reviewer's `Declined to judge` list.

Use `bg_wait` with `all: true` if running in a context where blocking is
appropriate, or simply handle incoming completion events as they arrive.

### Step 3: Verification Gate (False-Positive Filter)

Nothing is reported until it survives this gate. This mirrors the find →
verify → report pipeline of production AI review systems: parallel finders
are deliberately sensitive (one false beat is cheaper than one missed real
bug), so a second, fresh-context verifier adjudicates every candidate for
precision. The gate runs at **every depth** and is never skipped to save
cost — reduce depth instead if economy is needed.

1. **Pre-merge candidates**: Merge identical candidates from different
   passes (same `file:line`, same claim) into one entry tagged with every
   pass that raised it, so the verifier judges it once. Set the
   `Declined to judge` lists aside — they are coverage records, not
   candidates.
2. **Launch a verifier sub-agent** (fresh context, `async: true`, `:high`
   thinking, same model policy as the reviewers) with the candidates, the
   diff, the full files, and the change context. If there are no candidates,
   skip the verifier and go straight to synthesis. If there are more than
   ~30 candidates, launch several verifiers in parallel, each on a disjoint
   subset.
3. **Collect verdicts**: Only VERIFIED and VERIFIED-RELOCATED (issue real,
   citation corrected) findings continue to synthesis. DROPPED candidates
   go to a one-line ledger (claim — reason) carried into the report's
   verification ledger. A finding that never passed through the gate is
   never reported.

The verifier's mandate and launch template are in the Orchestrator Prompt
Template section below.

### Step 4: Synthesis & Deduplication

Working from the VERIFIED findings and the declined lists:

1. **Merge duplicates**: The same bug may surface in Pass 1 and Pass 2
   (identical candidates were pre-merged at the gate). Keep it once with the
   highest severity.
2. **Reclassify severity**: If a correctness finding (Pass 1) is also an
   injection vector (Pass 2), promote to the higher severity level.
3. **Filter existing comments**: If an existing comment already covers the same
   `file:line` issue with the same recommendation, drop it or mark
   `already raised`.
4. **Handle declined items**: Declined-to-judge entries are NOT findings —
   never promote one into the report body. If a declined observation falls
   under a pass that was not launched at this depth (e.g. a Security
   reviewer declined a test-gap observation during `quick`), surface it in
   the verification ledger so the human sees it was noticed and consciously
   set aside.
5. **Count**: Tally by severity. Also record candidate, verified, and
   dropped counts for the verification ledger.

### Step 5: Structured Output

Produce the final report in this exact format:

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  CODE REVIEW REPORT                                                          ║
║  <change description>                                                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

📋 CHANGE SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scope: <files touched>
Lines: +<additions> / -<deletions>
Depth: <quick | standard | deep>
Focus: <general | security | performance | correctness>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 P0 — BLOCKING (Must Fix Before Merge)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[P0-1] <title>
  File: <path>:<line>
  Raised in: <Pass N>
  Problem: <one sentence>
  Fix: <concrete change>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟠 P1 — HIGH (Strongly Recommended)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[P1-1] <title>
  ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟡 P2 — MEDIUM (Consider Addressing)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[P2-1] <title>
  ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 P3 — LOW (Nice to Have)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[P3-1] <title>
  ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✏️  NITS (Minor, Skip if Time-Constrained)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[NIT-1] <title>
  ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧪 VERIFICATION LEDGER (Transparency)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Candidates: <M> raised → <K> verified, <D> dropped
  (or: "Verification skipped — no candidates")
Declined to judge (reviewers saw it and set it aside — NOT findings):
- [Pass N] <observation> — <reason>        (or "none")
Dropped candidates (false positives, factually wrong, no evidence):
- <claim, one line> — <reason>              (or "none")

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 BLAST RADIUS SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<blast radius output from Step 0>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ POSITIVE FEEDBACK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- <specific good practice observed, linked to file:line>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 METRICS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
P0:     <N>
P1:     <N>
P2:     <N>
P3:     <N>
Nits:   <N>
Total:  <N>

Overall: <BLOCKED / APPROVE_WITH_NOTES / APPROVE>

⚠️  This is an automated review. Apply human judgment.
    P0 findings are blockers; everything else is advisory.
```

## Orchestrator Prompt Template

When launching reviewers, use a concrete task like this in each `subagent`
call. Every launch must set `async: true` and **high thinking mode** via the
`:high` model suffix:

```
subagent({
  agent: "reviewer",            // or the reviewer agent available in this harness
  async: true,
  model: "<provider/model-id>:high",  // ":high" suffix = high thinking mode
  task: "<task text from the template below>",
})
```

Task text:

```
You are a senior <role> performing code review. You have NO access to the
parent conversation. Use only the material provided below.

MANDATE: Perform ONLY the checks described in this message. Do NOT perform
other review passes. Do NOT edit files.

INPUT:
--- Context ---
<change context>

--- Diff ---
<diff text>

--- Full files ---
<file contents for context>

--- Blast Radius ---
<summary from Step 0>

--- Existing Comments ---
<if any, otherwise "none">

CHECKS (select the relevant list from the pass descriptions above):
<copy the checklist for the assigned pass>

RULES:
- Focus ONLY on changed lines and their immediate context.
- Use full files for context only; do not critique unchanged code.
- Every finding MUST cite file:line evidence. No evidence = discard.
- Provide a concrete fix or next step, not vague advice.
- If no substantive findings, respond with exactly: "No issues found in this pass." — then still close with your Declined to judge list.
- Skip cosmetics (whitespace, import order, formatting).
- Label severity for each finding: P0 (blocking), P1 (high), or P2 (medium).
- Close with a Declined to judge list: anything you noticed but set aside as
  outside your pass, one line each (<observation> — <reason>). If nothing,
  respond with exactly: "Declined: none."

Output all findings in the format specified for your pass, then your
Declined to judge list.
```

### Verifier launch (Step 3)

Once all reviewers have returned and candidates are pre-merged, launch the
verification sub-agent with the same discipline (`async: true`, `:high`
thinking mode):

```
subagent({
  agent: "reviewer",            // or any general-purpose agent available
  async: true,
  model: "<provider/model-id>:high",
  task: "<verifier task text below>",
})
```

Verifier task text:

```
You are a verification engineer adjudicating candidate findings from a code
review. You have NO access to the parent conversation. You are NOT reviewing
the change — the reviewers already did. Your only job is to decide, for each
candidate, whether it is TRUE of this code.

For each candidate:
1. Open the cited file:line in the full files. Confirm the cited code exists
   and matches the claim made about it.
2. Confirm the described problem is genuinely present in the code as
   written — not already handled elsewhere in the same change, file, or an
   imported helper.
3. Confirm the proposed fix would address the claimed problem.

Verdicts (exactly one per candidate):
- VERIFIED — the claim holds as stated.
- VERIFIED-RELOCATED — the issue is real but the citation was off; supply
  the corrected file:line.
- DROPPED — the claim does not hold in this code; one-line reason required.

Rules:
- A candidate with no file:line, or one citing a nonexistent line, is
  DROPPED ("no evidence" / "citation not found").
- Do NOT add new findings, re-review the diff, or change severities.
- Do not drop a finding merely because you would fix it differently; drop it
  only if the claimed problem does not hold in the code as written.
- Adjudicate every candidate you were given — no skips.
- Close with a one-line ledger of every DROPPED candidate and its reason.

INPUT:
--- Candidates ---
<numbered list: [C1] pass origin, severity, file:line, claim, proposed fix>

--- Context ---
<change context>

--- Diff ---
<diff text>

--- Full files ---
<file contents needed to check the citations>

OUTPUT per candidate:
[C1] VERIFIED | VERIFIED-RELOCATED <path:line> | DROPPED
  Reason: <one line — required for VERIFIED-RELOCATED and DROPPED>
```

## Severity Classification

| Level | Criteria | Action Required |
|-------|----------|-----------------|
| **P0 — Blocking** | Security vulnerability, data loss/corruption risk, production crash, logic bug with user impact, missing auth check | Must fix before merge |
| **P1 — High** | Likely bug in edge case, significant performance regression, missing critical error handling, breaking API change without migration | Strongly recommended |
| **P2 — Medium** | Maintainability concern, missing test for moderately complex logic, inefficient but not hot-path algorithm | Consider addressing |
| **P3 — Low** | Style inconsistency, missing internal comments, minor refactor opportunity | Nice to have |
| **Nit** | Typo in comment, whitespace preference, purely subjective naming | Skip if time-constrained |

## Review Depth Modes

### Quick Mode (`--quick` or user asks for "quick review")
- Launch only Reviewers 1–3 (Correctness, Security, Performance)
- No Reviewers 4–7 (Testing, Architecture, Simplification, Completeness)
- Limit output to P0 and P1

### Standard Mode (default)
- Launch all Reviewers 1–6
- Output P0–P3

### Deep Mode (`--deep` or user asks for "deep review")
- Launch all Reviewers 1–7
- Output P0–P3 and Nits
- Include architecture deep-dive and coupling analysis
- If >20 files changed or >500 LOC, recommend splitting the change

## Standalone Usage

When using this skill directly without an orchestrator:

**"Review the last 3 commits"**:
```
1. Run `git diff HEAD~3..HEAD` to get the diff.
2. Run `git log --oneline HEAD~3..HEAD` for commit messages.
3. Read each changed file in full.
4. Assemble input and execute the review methodology above.
5. Launch parallel reviewer sub-agents for the configured depth.
```

**"Review this diff"** (user pastes a diff):
```
1. Accept the diff as input.
2. If available, read relevant files from disk for context.
3. Launch parallel reviewer sub-agents for the configured depth.
```

**"Review files X, Y, Z"** (no diff, just files):
```
1. Read the specified files.
2. If in a git repo, run `git diff HEAD` to see unstaged changes, or `git diff --cached` for staged.
3. Otherwise, review the files as-is (static analysis mode).
4. Launch parallel reviewer sub-agents for the configured depth.
```

**"Security review of my changes"**:
```
1. Default depth = standard, Focus = security.
2. Expand Reviewer 2 (Security) with extra scrutiny.
3. Launch all reviewers but weight Security findings higher in synthesis.
```

## Edge Cases

- **Very large diff (>500 LOC or >20 files)**: Note in blast radius.
  Recommend splitting. If user insists, run quick mode only and offer file-level
  drill-down on request.
- **Generated code (protobuf, GraphQL, OpenAPI, bindata)**: Skip all reviewers.
  Review only the generator configuration or template.
- **Lockfile-only changes**: Do blast radius only. Verify the dependency delta is
  intentional.
- **Binary files**: Skip content reviewers. Note in blast radius.
- **Config-only changes** (YAML, JSON, `.env`): Launch Reviewer 2 (Security) and
  Reviewer 7 (Completeness) only.
- **Documentation-only changes**: Launch Reviewer 5 (maintainability focused on
  clarity and accuracy) and Reviewer 7. Skip correctness, security, performance,
  simplification.
- **No diff / no changes**: Report "Nothing to review" and stop.

## Notes

- **Read-only**: This skill never edits files, posts comments, or modifies
  state. It produces a console report only. There are no "fix workers" in this
  workflow — that belongs to the `review-loop` or `implementation` skills.
- **High thinking on every reviewer**: All reviewer sub-agents launch at
  high thinking mode (via the `:high` model suffix or a `thinking: "high"`
  agent override). Do not downgrade a reviewer to a lower thinking level to
  save cost or time — reduce the depth (number of passes) instead.
- **Fresh context per reviewer**: Each reviewer starts with no parent
  conversation history. They must derive everything from the input material
  alone. This prevents finding fatigue and cross-contamination between passes.
- **Parallel by default**: All reviewers launch simultaneously. The parent does
  not review code itself — it orchestrates, synthesises, and reports.
- **Escape hatches are essential**: If a reviewer finds nothing, they must say
  so. Manufactured findings destroy trust.
- **file:line discipline**: Every finding must cite a location. This makes the
  review actionable and helps humans verify.
- **Find → verify → report**: Reviewers are tuned for sensitivity; the
  verifier is tuned for precision. Every reported finding is individually
  re-checked against the code by a fresh verification sub-agent before it
  reaches the report. Never short-circuit the gate to save cost — reduce
  the depth instead. One obviously false finding in a report costs more
  trust than the whole review earns back.
- **Declined-to-judge lists**: Reviewers record what they saw but
  deliberately set aside, instead of silently dropping it. The lists are a
  coverage record surfaced in the verification ledger; they let a human
  overrule a reviewer's scoping decision, and they flag issues belonging to
  passes not launched at the current depth.
- **Concrete fixes**: Vague advice like "consider refactoring" is noise. Every
  P0–P2 must have a specific fix.
- **Context over raw diff**: The diff shows what changed; full files show why it
  matters. Use both.
- **Human is the final gate**: Automated review augments, never replaces,
  human judgment, especially for architecture and product decisions.
