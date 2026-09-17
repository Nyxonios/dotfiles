---
name: gitlab-analyze-review-comments
description: >
  Analyzes GitLab Merge Request review comments using the gitlab-comment-extractor tool.
  Use this skill when the user wants to review, analyze, or prepare responses to MR comments,
  diff notes, or discussion threads. The skill fetches all review comments (general and diff-specific),
  filters out resolved/completed comments by default, presents unresolved items organized by file
  and line range, suggests concrete code changes to address feedback, and helps draft response text.
  **Does NOT post anything back to GitLab** — output is console-only.
  Requires gitlab-comment-extractor tool and glab CLI authenticated with gitlab.evroc.dev.
---

# GitLab Analyze Review Comments Skill

## Overview

This skill retrieves and analyzes all review comments on a GitLab Merge Request using the `gitlab-comment-extractor` tool. It:

1. Identifies the MR (from current branch context or MR ID provided)
2. Uses `gitlab-comment-extractor` to fetch structured comment data
3. Parses JSON output to extract file paths, line numbers, and comment content
4. Presents a structured summary organized by file and line range
5. Suggests concrete code/document changes to address review feedback
6. Helps draft response text for the user to copy/paste back to GitLab

**Key principle**: This skill is read-only. It never posts, edits, or resolves comments. All output goes to the console where the prompt was received.

## Prerequisites

- `gitlab-comment-extractor` tool installed (built from `/home/mseller/development/gitlab-comment-extractor`)
- `glab` CLI installed (`brew install glab` or https://gitlab.com/gitlab-org/cli)
- Authenticated with `gitlab.evroc.dev` (run `glab auth login` and select `gitlab.evroc.dev` when prompted)
- Must be run from inside a git repository with a GitLab remote on gitlab.evroc.dev, OR provide `--project` flag
- Repository must have an open MR for the current branch (if using auto-detection)

## Step-by-Step Workflow

### Step 1: Identify the MR

First, determine which MR to analyze:

```bash
# Current branch name
git rev-parse --abbrev-ref HEAD

# Check if there's an open MR for this branch
GLAB_HOST=gitlab.evroc.dev glab mr view 2>/dev/null | head -10
```

**Auto-detection logic**:
- If already on a feature branch (not `main`/`master`), try to find the MR for current branch
- If on `main`/`master`, or if auto-detection fails, ask the user:
  - "Which MR would you like to analyze? Provide MR number or branch name:"

Store the MR ID for subsequent queries.

### Step 2: Fetch Comments Using gitlab-comment-extractor

Use the `gitlab-comment-extractor` tool to fetch all MR comments as structured JSON:

```bash
# Fetch comments from current git repository (auto-detects project)
gitlab-comment-extractor --mr <MR_ID> > /tmp/mr_comments.json

# Or specify project explicitly
gitlab-comment-extractor --mr <MR_ID> --project engineering/monorepo > /tmp/mr_comments.json

# Or specify host and project
gitlab-comment-extractor --mr <MR_ID> --host gitlab.evroc.dev --project engineering/monorepo > /tmp/mr_comments.json
```

**Tool output format:**

The tool outputs a JSON object with the following structure:

```json
{
  "schema_version": "1.0",
  "mr": {
    "iid": 9143,
    "title": "MR Title",
    "source_branch": "feature-branch",
    "target_branch": "main",
    "state": "opened",
    "author": {
      "username": "author",
      "name": "Author Name"
    }
  },
  "general_comments": [
    {
      "id": 123,
      "type": null,
      "body": "General comment text",
      "author": {"username": "reviewer", "name": "Reviewer Name"},
      "created_at": "2024-01-15T14:32:00Z",
      "system": false,
      "resolvable": true,
      "resolved": false
    }
  ],
  "file_comments": {
    "src/file.go": [
      {
        "id": 124,
        "type": "DiffNote",
        "body": "File-specific comment",
        "author": {"username": "reviewer", "name": "Reviewer Name"},
        "created_at": "2024-01-15T14:33:00Z",
        "system": false,
        "resolvable": true,
        "resolved": false,
        "position": {
          "new_path": "src/file.go",
          "new_line": 45,
          "old_path": "src/file.go",
          "old_line": 42
        }
      }
    ]
  }
}
```

**Key fields:**

| Field | Description |
|-------|-------------|
| `mr` | MR metadata (title, branches, state, author) |
| `general_comments` | Array of general MR comments (not attached to code) |
| `file_comments` | Object mapping file paths to arrays of diff comments |
| `id` | Comment ID |
| `type` | `"DiffNote"` for file comments, `null` for general |
| `body` | Comment text |
| `author.username` | Comment author |
| `created_at` | Timestamp |
| `system` | `true` for automated GitLab system notes (already filtered by tool) |
| `resolvable` | Whether note can be resolved |
| `resolved` | Resolution status |
| `position` | File position info (for DiffNote types only) |

**The tool automatically:**
- Filters out system notes (no need to filter again)
- Categorizes comments into `general_comments` and `file_comments`
- Groups file comments by file path
- Handles pagination for MRs with many comments
- URL-encodes project paths

### Step 3: Parse and Organize Comments

Process the JSON from the tool to analyze comments:

**Step 3.1: Parse the JSON output**

```python
import json

# Load from the tool output
with open('/tmp/mr_comments.json', 'r') as f:
    data = json.load(f)

mr = data['mr']
general_comments = data['general_comments']
file_comments = data['file_comments']

print(f"MR: {mr['title']} (!{mr['iid']})")
print(f"Branch: {mr['source_branch']} → {mr['target_branch']}")
print(f"General comments: {len(general_comments)}")
print(f"Files with comments: {len(file_comments)}")
```

**Step 3.2: Filter resolved comments (if needed)**

By default, the skill shows unresolved comments. System notes are already filtered by the tool.

```python
# Filter to show only unresolved comments
unresolved_general = [c for c in general_comments if not c.get('resolved')]

unresolved_file_comments = {}
for path, comments in file_comments.items():
    unresolved = [c for c in comments if not c.get('resolved')]
    if unresolved:
        unresolved_file_comments[path] = unresolved
```

**Step 3.3: Organize by file**

The tool already groups file comments by path in `file_comments`.

### Step 4: Present Structured Summary

Output a formatted summary to the console:

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  MR Review Analysis                                                          ║
║  <MR Title> (!<MR_ID>)                                                       ║
║  Branch: <source_branch> → <target_branch>                                   ║
╚══════════════════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 GENERAL COMMENTS (<count>)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1] @reviewer1 — 2024-01-15 14:32
    Status: Unresolved
    
    This looks good overall, but I have a few questions...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 FILE: src/auth/middleware.ts (<count> comments)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Line 45 │ @reviewer1 — Unresolved
────────┼─────────────────────────────────────────────────────────────────────
        │ Consider using a constant here instead of magic number 300.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Showing: Unresolved comments only
Total unresolved: <N>
  ├─ General: <N>
  └─ File-specific: <N>

⚠️  Remember: Copy suggested responses and paste into GitLab manually.
    This skill is read-only and does not post comments automatically.
    
    MR URL: https://gitlab.evroc.dev/<org>/<repo>/-/merge_requests/<MR_ID>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 5: Suggest Code Changes (Optional)

For actionable comments, analyze local files and propose changes:

**Process:**

1. **Gather MR context:**
   ```bash
   git diff origin/<target>...HEAD
   git diff --name-only origin/<target>...HEAD
   ```

2. **Read commented files:**
   ```bash
   cat <file-path>
   ```

3. **Generate proposed changes** in unified diff format

### Step 6: Generate Response Drafts (Optional)

Draft responses for the user to copy/paste:

```
📤 SUGGESTED RESPONSES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

For comment on src/file.go Line 45 (@reviewer):
───────────────────────────────────────────────────────────────────────────────
Good catch! I've made the change as suggested. See diff above.
───────────────────────────────────────────────────────────────────────────────
```

## Example Usage

**Basic usage:**
```bash
# Analyze current MR (auto-detects from git remote)
gitlab-comment-extractor --mr 9143 | jq .

# Analyze specific MR with explicit project
gitlab-comment-extractor --mr 9143 --project engineering/monorepo
```

**User prompts:**

- "Review my MR comments" → Run tool, parse JSON, display formatted summary
- "Analyze review comments for MR 42" → Run tool with MR 42, show analysis
- "Show all comments including resolved" → Include resolved comments in output
- "Draft responses to the middleware comments" → Generate response drafts
- "Suggest fixes for the review comments" → Analyze and propose code changes

## Troubleshooting

| Error | Fix |
|-------|-----|
| `gitlab-comment-extractor: command not found` | Build the tool: `cd ~/development/gitlab-comment-extractor && go build` |
| `Error: not a git repository` | Run from a git repo or use `--project` flag |
| `Error: authentication failed` | Run `glab auth login` and select `gitlab.evroc.dev` |
| `Error: MR not found` | Verify MR number and project path are correct |
| Empty JSON output | MR has no human review comments (tool filters system notes) |

## Notes

- **Read-only by design**: This skill never modifies GitLab state
- **System notes filtered**: The tool automatically filters system notes
- **Structured JSON**: The tool provides structured JSON ready for analysis
- **Full context required**: Always examine the MR diff before suggesting changes
- **Authentication**: Ensure `glab` is authenticated with `gitlab.evroc.dev`
- **Default project**: Tool defaults to `engineering/monorepo` if not in a git repo
