---
name: gitlab-fetch-mr-comments
description: >
  Fetches ALL review comments from a GitLab Merge Request — given a direct MR link
  (URL), an MR number, or the MR for the current branch — and returns them as
  structured, agent-actionable data: the raw tool JSON (/tmp/mr_<iid>_comments.json)
  plus a flat list of action items with exact code anchors (file:line on the source
  branch, or old-line/file/MR-general anchors), author, resolution status, note ID
  and full comment text (/tmp/mr_<iid>_action_items.json). Use this skill when the
  user supplies an MR link and wants comments fetched, listed, or structured for
  later action, or when a workflow/skill needs MR review comments as input data.
  Does NOT analyze, suggest changes, or post anything to GitLab — pair with
  gitlab-analyze-review-comments for analysis. Requires gitlab-comment-extractor
  and glab CLI.
metadata:
  companions: [gitlab-analyze-review-comments, gitlab-review-mr]
---

# GitLab Fetch MR Comments Skill

## Overview

Fetch-only building block. Given any MR reference, it retrieves every review
comment and **where in the code/text it refers to**, flattens them into
machine-actionable records, and hands them off for a downstream agent to act on.

This skill **does not**:
- analyze or summarize the feedback (see `gitlab-analyze-review-comments`)
- fetch MR diffs or run code review (see `gitlab-review-mr`)
- post, edit, or resolve anything on GitLab — it is strictly read-only

Primary entry point is the bundled script:

```
scripts/fetch_mr_comments.py <MR_URL | MR_NUMBER | current> [options]
```

It resolves the reference, calls `gitlab-comment-extractor`, saves both outputs,
and prints a digest. Run it with the path relative to this skill directory.

## Prerequisites

- `gitlab-comment-extractor` installed (`cd ~/development/gitlab-comment-extractor && go build -o ~/.local/bin/gitlab-comment-extractor .`)
- `glab` CLI installed and authenticated with the MR's host
  (`glab auth login --hostname gitlab.evroc.dev`)
- No git repository required when the MR URL is given (host/project are parsed
  from the URL and passed explicitly to the extractor)

## Accepted inputs

| Input | Example | Resolution |
|-------|---------|------------|
| Full MR URL (recommended) | `https://gitlab.evroc.dev/group/project/-/merge_requests/9143` | host + project parsed from URL; works from any directory |
| MR URL with note anchor | `https://gitlab.evroc.dev/group/project/-/merge_requests/9143#note_5678` | same, and the referenced comment ID is marked `from_note_url: true` |
| URL with view suffixes | `.../merge_requests/9143/diffs` | suffix ignored |
| Plain MR number | `9143` | project auto-detected from git remote (or requires `--project` outside a repo) |
| Current branch MR | `current` | `glab mr view --json` on the current branch resolves the MR |

## Workflow

### Step 1: Run the bundled script

```bash
# From an MR link (primary use case — works anywhere)
python3 <skill-dir>/scripts/fetch_mr_comments.py \
  "https://gitlab.evroc.dev/engineering/monorepo/-/merge_requests/9143"

# Plain MR number inside the project's repo
python3 <skill-dir>/scripts/fetch_mr_comments.py 9143

# Outside the repo, MR number + explicit project
python3 <skill-dir>/scripts/fetch_mr_comments.py 9143 --project engineering/monorepo --host gitlab.evroc.dev

# The open MR for the current branch
python3 <skill-dir>/scripts/fetch_mr_comments.py current

# Only unresolved items, headers only
python3 <skill-dir>/scripts/fetch_mr_comments.py "<MR_URL>" --unresolved-only --quiet
```

Useful options: `--unresolved-only`, `--quiet` (omit bodies), `--no-save`,
`--raw <path>` / `--items <path>` (override save paths), `--timeout <s>`.

### Step 2: Verify

Exit codes follow the extractor: `0` success · `1` general error ·
`2` auth failed (`glab auth login --hostname gitlab.evroc.dev`) ·
`3` MR not found · `4` not a git repository (use `--project` or an MR URL).

A fetched `total` of 0 means the MR has no human comments yet (system notes are
always filtered by the extractor). This is a valid result — report it; do not retry.

### Step 3: Hand off the data

Two files are written by default and are the deliverables:

1. `/tmp/mr_<iid>_comments.json` — raw extractor JSON (schema below)
2. `/tmp/mr_<iid>_action_items.json` — flat, agent-ready action items (schema below)

**If a downstream agent/skill will act on the comments, pass it the action-items
file and the anchor rules below. Do not re-fetch.**

## Action item schema (contract for downstream agents)

Each comment (including every thread reply) becomes one flat record:

```json
{
  "id": 124,
  "type": "DiffNote",
  "anchor": "src/file.go:45",
  "anchor_kind": "line",
  "anchor_detail": "targets source-branch (new) code",
  "author": "reviewer",
  "created_at": "2024-01-15T14:33:00Z",
  "resolvable": true,
  "resolved": false,
  "from_note_url": false,
  "body": "Consider using a constant here instead."
}
```

| Field | Use for an acting agent |
|-------|------------------------|
| `anchor` | The actionable location: `file:line`, `file`, or `MR !<iid> (general)` |
| `anchor_kind` | Routing rule, see below |
| `author` | Whose feedback to address / credit |
| `resolved` | Skip or deprioritize resolved items (unresolved items sort first) |
| `resolvable` | `false` + unresolved usually means informational comments |
| `id` | Stable identity — reference replies/threads by this ID; matches `#note_<id>` URLs |
| `from_note_url` | `true` when the user's MR link pointed at this specific comment — prioritize it |
| `body` | Full comment text (Markdown) |

### Anchor rules — how to map to code

| `anchor_kind` | Meaning | Acting agent should |
|---------------|---------|--------------------|
| `line` | `path:new_line` in the **MR source branch** version | Check out / diff against the source branch, edit at that line |
| `old-line` | Comment sits on **deleted** code (`old_path:old_line`) | Compare against the target branch; likely about code the MR removes |
| `file` | Comment on a file, no specific line | Read the whole file in MR context |
| `mr-general` | MR-level comment (description/general feedback) | Act on the MR as a whole; may need `glab mr view` for context |

Notes for consumers:

- **Line numbers refer to the source-branch (upstream-pushed) state**, not the
  local checkout. Fetch/reset to `origin/<source_branch>` before acting.
- Threads are flattened: every reply is its own record sharing the thread's
  resolve state. Deduplicate by anchor when acting.
- System notes (label changes, "approved", …) are already filtered by the tool.

## Raw JSON schema (from gitlab-comment-extractor)

```json
{
  "schema_version": "1.0",
  "mr": {"iid": 9143, "title": "...", "source_branch": "...", "target_branch": "...",
          "state": "opened", "author": {"username": "...", "name": "..."}},
  "general_comments": [ {"id": 123, "body": "...", "author": {...},
                          "created_at": "...", "system": false,
                          "resolvable": true, "resolved": false } ],
  "file_comments": {
    "src/file.go": [ {"id": 124, "type": "DiffNote", "position": {
                        "new_path": "src/file.go", "new_line": 45,
                        "old_path": "src/file.go", "old_line": 42 }, ...} ]
  }
}
```

## Manual fallback (script unavailable)

If the bundled script is missing, do it by hand:

```bash
MR_URL="https://gitlab.evroc.dev/engineering/monorepo/-/merge_requests/9143"
HOST=$(echo "$MR_URL"   | sed -E 's|^https?://([^/]+)/.*|\1|')
PROJECT=$(echo "$MR_URL" | sed -E 's|^https?://[^/]+/(.+)/-/merge_requests/.*|\1|')
MR_IID=$(echo "$MR_URL"  | sed -E 's|.*/-/merge_requests/([0-9]+).*|\1|')

gitlab-comment-extractor --mr "$MR_IID" --host "$HOST" --project "$PROJECT" \
  > /tmp/mr_${MR_IID}_comments.json
```

Then read the raw JSON directly and apply the anchor rules above when
presenting/acting on comments.

## Example usage

- "Fetch the review comments for https://gitlab.evroc.dev/x/y/-/merge_requests/42"
  → run script with the URL, report digest + files
- "Get all unresolved comments for MR 9143 in engineering/monorepo"
  → `... 9143 --project engineering/monorepo --unresolved-only`
- "What does comment https://.../merge_requests/9143#note_5678 refer to?"
  → script marks the record with `from_note_url: true`; report its anchor + body
- (from another skill) "existing comments for the review"
  → run script with the MR identifer, consume `/tmp/mr_<iid>_action_items.json`

## Troubleshooting

| Error | Fix |
|-------|-----|
| Script: `gitlab-comment-extractor not found` | Build it: `cd ~/development/gitlab-comment-extractor && go build -o ~/.local/bin/gitlab-comment-extractor .` |
| Exit `2` auth failed | `glab auth login --hostname gitlab.evroc.dev` |
| Exit `3` MR not found | Check MR number and project path (nested groups must be fully spelled out) |
| Exit `4` not a git repository | Pass `--project group/project`, or use the full MR URL |
| `Unrecognized MR reference` | Input was neither a URL, an integer, nor `current` |
| 0 comments fetched | Valid result: MR has no human comments (system notes are filtered). |
| Note focus not found | The `#note_<id>` refers to a filtered system note or a resolve action |

## Notes

- **Read-only by design** — never posts, edits, or resolves anything
- **Deterministic output shape** — the two JSON files are a stable interface
  for skills and agents; do not re-derive their format ad hoc
- MRs in a `merged`/`closed` state also fetch fine — flag this to the
  downstream agent, since anchors may refer to code that has since moved
