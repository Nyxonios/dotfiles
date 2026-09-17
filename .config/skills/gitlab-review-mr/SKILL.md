---
name: gitlab-review-mr
description: >
  GitLab Merge Request review orchestrator. Identifies the MR from the current
  branch or a provided MR ID, fetches metadata, diff, commits, changed files,
  and existing review comments, then delegates the thorough multi-pass code
  review to the `code-review` skill.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: gitlab
  companions: [code-review, gitlab-analyze-review-comments]
---

# Skill: gitlab-review-mr

# GitLab MR Review Orchestrator

## Overview

This skill is a **thin orchestrator** for GitLab Merge Request code reviews. It
does not contain review methodology. Its job is:

1. Identify the MR (from current branch or provided MR ID)
2. Fetch MR metadata, description, and diff
3. Fetch commit messages and change statistics
4. Read the full contents of changed files on disk
5. Optionally fetch existing review comments (via `gitlab-analyze-review-comments`)
6. Assemble all review material into a structured package
7. **Delegate the actual code review** to the `code-review` skill
8. Present the final report with GitLab-specific context (MR title, branch,
   existing comments, author, etc.)

**Companion skill dependency**: Load the `code-review` skill alongside this one.
The `code-review` skill provides the multi-pass review methodology
(blast-radius, correctness, security, performance, tests, architecture, and
completeness passes).

**Optional companion**: Load `gitlab-analyze-review-comments` to fetch and
incorporate existing unresolved review comments into the review material.

**Key principle**: Read-only. This skill never posts, edits, or modifies the MR.

## Prerequisites

- `glab` CLI installed (`brew install glab` or https://gitlab.com/gitlab-org/cli)
- Authenticated with `gitlab.evroc.dev` (run `glab auth login` and select `gitlab.evroc.dev`)
- Must be run from inside a git repository with a GitLab remote on `gitlab.evroc.dev`,
  OR an MR ID must be provided
- The `code-review` skill should be available (loaded alongside this one)

## Step-by-Step Workflow

### Step 1: Identify the MR

Determine which MR to review:

```bash
# Current branch name
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Attempt auto-detection from current branch (only if not on main/master/mainline)
if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ] && [ "$CURRENT_BRANCH" != "mainline" ]; then
  GLAB_HOST=gitlab.evroc.dev glab mr view --json 2>/dev/null | head -1
fi
```

**Auto-detection logic**:
- If on a feature branch (not `main`/`master`/`mainline`), try to find the MR
- If on `main`/`master`/`mainline`, or auto-detection fails, ask the user:
  - "Which MR would you like to review? Provide the MR number (e.g. 123) or branch name:"

**Store**: `MR_ID` for all subsequent queries.

### Step 2: Fetch MR Metadata

Retrieve comprehensive MR information:

```bash
GLAB_HOST=gitlab.evroc.dev glab mr view "${MR_ID}" --json > /tmp/mr_meta.json
```

**Extract and store**:
- `title`, `description` — the "why"
- `source_branch`, `target_branch`
- `author` (username, name)
- `state` (open/merged/closed/draft)
- `labels`, `assignees`
- `created_at`, `updated_at`
- `squash_on_merge` preference

**Edge case handling**:
- **MR is draft / WIP**: Note this in the report header. The review should proceed
  but mention that some incompleteness may be intentional.
- **MR already merged/closed**: Proceed with the review but label it as
  "post-merge review for learning".

### Step 3: Fetch Diff and Change Statistics

```bash
# Full diff
GLAB_HOST=gitlab.evroc.dev glab mr diff "${MR_ID}" > /tmp/mr_diff.patch

# Per-file change stats
GLAB_HOST=gitlab.evroc.dev glab mr view "${MR_ID}" --json | jq -r '
  .diff_stats[] | "\(.path): +\(.additions)/-\(.deletions)"
' > /tmp/mr_stats.txt

# Total additions / deletions
TOTAL_ADD=$(GLAB_HOST=gitlab.evroc.dev glab mr view "${MR_ID}" --json | jq '.diff_stats | map(.additions) | add')
TOTAL_DEL=$(GLAB_HOST=gitlab.evroc.dev glab mr view "${MR_ID}" --json | jq '.diff_stats | map(.deletions) | add')
FILE_COUNT=$(GLAB_HOST=gitlab.evroc.dev glab mr view "${MR_ID}" --json | jq '.diff_stats | length')
```

**Store**: `DIFF`, `STATS`, `TOTAL_ADD`, `TOTAL_DEL`, `FILE_COUNT`.

### Step 4: Fetch Commit Messages

```bash
GLAB_HOST=gitlab.evroc.dev glab mr view "${MR_ID}" --json | jq -r '.commits[] | "\(.short_id) \(.title)"'
```

**Store**: `COMMITS` as structured text.

### Step 5: Read Changed Files on Disk

Read the **full current content** of every changed file (not just the diff hunk)
to give the review pass full context:

```bash
CHANGED_FILES=$(GLAB_HOST=gitlab.evroc.dev glab mr view "${MR_ID}" --json | jq -r '.diff_stats[].path')

for file in $CHANGED_FILES; do
  if [ -f "$file" ]; then
    echo "=== $file ==="
    cat "$file"
    echo ""
  else
    echo "=== $file === [DELETED or UNTRACKED LOCALLY]"
  fi
done > /tmp/mr_files.txt
```

**Store**: `FULL_FILES` from `/tmp/mr_files.txt`.

If a file is deleted, fetch its old content from the target branch for
reference:

```bash
git show "origin/$(jq -r '.target_branch' /tmp/mr_meta.json):$file" 2>/dev/null || true
```

### Step 6: Gather Existing Review Comments (Optional)

If `gitlab-analyze-review-comments` is available and the user asked to include
existing comments, or if the user explicitly requests it, run:

```bash
gitlab-comment-extractor --mr "${MR_ID}" > /tmp/mr_comments.json 2>/dev/null || true
```

**Parse** for unresolved comments and resolve any that cover the same
`file:line` that would otherwise be raised. Store as `EXISTING_COMMENTS`.

If the tool is unavailable, record that existing comments were not fetched.

### Step 7: Determine Review Depth and Focus

Analyse the user's original prompt to infer:

| Prompt signal | Depth | Focus |
|---------------|-------|-------|
| "quick review" / "high-level" / "sanity check" | `quick` | none |
| "security review" / "check for vulns" | `standard` | `security` |
| "deep review" / "thorough review" / "everything" | `deep` | none |
| "performance check" / "will this scale" | `standard` | `performance` |
| "does this look right" / generic "review" | `standard` | none |

**Store**: `DEPTH`, `FOCUS`.

### Step 8: Assemble the Review Package

Build the complete input package for the `code-review` skill:

```
═══════════════════════════════════════════════════════════════════════════════
  REVIEW PACKAGE
═══════════════════════════════════════════════════════════════════════════════

MR Title:   <title>
MR ID:      !<MR_ID>
Author:     @<author>
Branch:     <source_branch> → <target_branch>
State:      <state>
Commits:    <count>
Files:      <FILE_COUNT>  | +<TOTAL_ADD> / -<TOTAL_DEL>
Depth:      <DEPTH>
Focus:      <FOCUS>

MR Description:
<description>

Commit Messages:
<commits>

Changed File Statistics:
<stats>

───────────────────────────────────────────────────────────────────────────────
DIFF
───────────────────────────────────────────────────────────────────────────────
<DIFF>

───────────────────────────────────────────────────────────────────────────────
FULL FILE CONTENTS (context)
───────────────────────────────────────────────────────────────────────────────
<FULL_FILES>

───────────────────────────────────────────────────────────────────────────────
EXISTING UNRESOLVED COMMENTS
───────────────────────────────────────────────────────────────────────────────
<EXISTING_COMMENTS or "None fetched">

═══════════════════════════════════════════════════════════════════════════════
```

### Step 9: Delegate to `code-review`

**Load the `code-review` skill** and present the assembled review package to it.

The `code-review` skill will:
- Run its multi-pass review methodology on the provided material
- Produce a severity-ranked, structured report
- Return P0–P3 findings with `file:line` evidence and concrete fixes

If `code-review` is not loaded alongside this skill, fall back to its
methodology as described in the `code-review` skill documentation (but the
report will lose the systematic multi-pass structure).

**Instructions to pass to `code-review`**:
- Diff: use the MR diff from Step 3
- Full files: use `/tmp/mr_files.txt` from Step 5
- Context: MR title + description + commit messages + branch relationship
- Target branch: use the MR target branch
- Depth: `DEPTH` from Step 7
- Focus: `FOCUS` from Step 7
- Existing comments: `EXISTING_COMMENTS` from Step 6
- Tech stack: infer from file extensions and imports in full files

### Step 10: Present the Final Report

Take the structured output from `code-review` and wrap it with GitLab-specific
context at the top:

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  GITLAB MR REVIEW REPORT                                                     ║
║  <MR Title> (!<MR_ID>)                                                       ║
║  <source_branch> → <target_branch>                                           ║
║  Author: @<author>  |  State: <state>                                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

📋 MR CONTEXT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Description: <brief summary>
Commits:     <N> commits (list below)
Files:       <N> changed (+<additions> / -<deletions>)
Depth:       <DEPTH>
Focus:       <FOCUS or "general">

<if draft>  ⚠️  NOTE: This MR is a draft. Some incompleteness may be intentional.
<if merged> 📌 NOTE: This MR is already merged. Review is for learning only.

<list of commit messages>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<insert the full `code-review` report here>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 EXISTING REVIEW COMMENTS (if fetched)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Unresolved: <N>
  ├─ ...
  └─ ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 LINKS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MR URL: https://gitlab.evroc.dev/<org>/<repo>/-/merge_requests/<MR_ID>
Diff:   https://gitlab.evroc.dev/<org>/<repo>/-/merge_requests/<MR_ID>/diffs
```

## Edge Cases

| Situation | Handling |
|-----------|----------|
| No open MR for current branch | Inform user and ask for MR number or branch name |
| On `main`/`master` branch | Never auto-detect. Ask for MR number explicitly. |
| MR has >50 files or >500 total LOC | Proceed but warn user. Suggest a quick review or file-level drill-down. |
| Binary-only changes | Fetch blast radius only. Skip file-content reading. |
| Generated code touched | Note in review package. Instruct `code-review` to review generator config, not generated output. |
| `glab` not authenticated | Error clearly; instruct `glab auth login --hostname gitlab.evroc.dev` |
| `gitlab-comment-extractor` missing | Skip existing comments. Mention in report that prior comments were not considered. |
| Local branch is behind remote | Fetch diff from GitLab (already done). Do not rely on local `git diff`. |
| File deleted in MR | Show old version from target branch as context. |
| MR targets a non-default branch | Use the actual target branch from MR metadata. |

## Example Usage

**"Review my MR"** (auto-detect from current branch):
- Identify MR → fetch metadata → fetch diff → read files → infer `standard` depth
  → load `code-review` → generate report

**"Review MR 123"**:
- Use MR 123 directly. Skip branch auto-detection.

**"Quick security review of my MR"**:
- Identify MR → assemble package → set Depth=`quick`, Focus=`security` →
  load `code-review` → generate report

**"Deep review of MR 456"**:
- Identify MR → assemble package → set Depth=`deep` → load `code-review` →
  generate report

## Troubleshooting

| Error | Fix |
|-------|-----|
| `glab: command not found` | `brew install glab` or https://gitlab.com/gitlab-org/cli |
| `401 Unauthorized` | `glab auth login --hostname gitlab.evroc.dev` |
| `404 Not Found` | MR does not exist; verify the number |
| `no merge request found for branch` | Current branch has no open MR; provide MR number |
| Empty diff | MR may have no changes or be already merged |
| File not found locally | File may be new in this branch; read from GitLab if possible |
| `gitlab-comment-extractor: command not found` | Build the tool: `cd ~/development/gitlab-comment-extractor && go build` |

## Notes

- **Thin by design**: This skill contains zero review methodology. All review
  logic lives in `code-review`.
- **Always use GitLab diff**: Never use local `git diff` alone — the local
  branch state may differ from the remotely-pushed MR state. `glab mr diff`
  is the source of truth.
- **Read full files**: Thorough review requires context outside diff hunks.
- **One writer at a time**: Since this skill is read-only, it never conflicts.
- **Human gate**: The `code-review` skill itself reminds that P0 findings are
  blockers and everything else is advisory. Human judgment applies the MR
  context (draft status, team conventions, etc.).
