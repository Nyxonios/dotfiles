---
name: code-review
description: >
  Platform-agnostic thorough multi-pass code review of diffs, commit ranges, or
  file sets. Delegates each review pass to parallel fresh-context sub-agents,
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

The review is organised as **six focused passes**, each delegated to a
independent fresh-context sub-agent running in parallel. The parent
orchestrator controls the workflow, accepts findings, and synthesises a
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
| **Depth** | `quick` → Passes 1-3 only (blast radius, correctness, security).<br>`standard` (default) → Passes 1-5.<br>`deep` → All 6 passes + architecture deep-dive. |
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
  `No issues found in this pass.`
- Skip cosmetics (whitespace, import order, formatting) — assume a linter
  handles those.
- Label every finding with severity: **P0** (blocking), **P1** (high), **P2** (medium).

**Launch all reviewers in parallel as async subagents.** Use `async: true`.

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
- Duplication: logic that already exists elsewhere and should be reused
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

#### Reviewer 6 — Completeness & Documentation (deep mode only)

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
[PASS-6] <Severity> — <one-line title>
  Category: <env | api-docs | migration | changelog | runbook | monitoring>
  Missing: <what should exist>
  Action: <who should do what, <= 30 words>
```

**Depth filtering** — launch only the relevant reviewers:

| Depth | Reviewers launched |
|-------|-------------------|
| `quick` | 1, 2, 3 (Correctness, Security, Performance) |
| `standard` (default) | 1, 2, 3, 4, 5 (all above) |
| `deep` | 1, 2, 3, 4, 5, 6 (all) |

### Step 2: Await Sub-Agent Results

Wait for all async reviewer sub-agents to complete. Collect their outputs.

Use `bg_wait` with `all: true` if running in a context where blocking is
appropriate, or simply handle incoming completion events as they arrive.

### Step 3: Synthesis & Deduplication

After all reviewers return:

1. **Merge duplicates**: The same bug may surface in Pass 1 and Pass 2. Keep
   it once with the highest severity.
2. **Reclassify severity**: If a correctness finding (Pass 1) is also an
   injection vector (Pass 2), promote to the higher severity level.
3. **Filter existing comments**: If an existing comment already covers the same
   `file:line` issue with the same recommendation, drop it or mark
   `already raised`.
4. **Verify evidence**: Every surviving finding MUST have a `file:line`. Any
   without evidence is discarded as likely hallucinated.
5. **Count**: Tally by severity.

### Step 4: Structured Output

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
call:

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
- If no substantive findings, respond with exactly: "No issues found in this pass."
- Skip cosmetics (whitespace, import order, formatting).
- Label severity for each finding: P0 (blocking), P1 (high), or P2 (medium).

Output all findings in the format specified for your pass.
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
- No Reviewers 5–6
- Limit output to P0 and P1

### Standard Mode (default)
- Launch all Reviewers 1–5
- Output P0–P3

### Deep Mode (`--deep` or user asks for "deep review")
- Launch all Reviewers 1–6
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
  Reviewer 6 (Completeness) only.
- **Documentation-only changes**: Launch Reviewer 5 (maintainability focused on
  clarity and accuracy) and Reviewer 6. Skip correctness, security, performance.
- **No diff / no changes**: Report "Nothing to review" and stop.

## Notes

- **Read-only**: This skill never edits files, posts comments, or modifies
  state. It produces a console report only. There are no "fix workers" in this
  workflow — that belongs to the `review-loop` or `implementation` skills.
- **Fresh context per reviewer**: Each reviewer starts with no parent
  conversation history. They must derive everything from the input material
  alone. This prevents finding fatigue and cross-contamination between passes.
- **Parallel by default**: All reviewers launch simultaneously. The parent does
  not review code itself — it orchestrates, synthesises, and reports.
- **Escape hatches are essential**: If a reviewer finds nothing, they must say
  so. Manufactured findings destroy trust.
- **file:line discipline**: Every finding must cite a location. This makes the
  review actionable and helps humans verify.
- **Concrete fixes**: Vague advice like "consider refactoring" is noise. Every
  P0–P2 must have a specific fix.
- **Context over raw diff**: The diff shows what changed; full files show why it
  matters. Use both.
- **Human is the final gate**: Automated review augments, never replaces,
  human judgment, especially for architecture and product decisions.
