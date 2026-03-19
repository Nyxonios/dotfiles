---
name: gitlab-analyze-review-comments
description: >
  Analyzes GitLab Merge Request review comments using the glab CLI for gitlab.evroc.dev.
  Use this skill when the user wants to review, analyze, or prepare responses to MR comments,
  diff notes, or discussion threads. The skill fetches all review comments (general and diff-specific),
  filters out resolved/completed comments by default, presents unresolved items organized by file
  and line range, suggests concrete code changes to address feedback, and helps draft response text.
  **Does NOT post anything back to GitLab** — output is console-only.
  Requires glab CLI authenticated with gitlab.evroc.dev.
---

# GitLab Analyze Review Comments Skill

## Overview

This skill retrieves and analyzes all review comments on a GitLab Merge Request using the `glab` CLI. It:

1. Identifies the MR (from current branch context or MR ID provided)
2. Fetches all discussions and comments (both general and diff-level)
3. Parses JSON output to extract file paths, line numbers, and comment content
4. Presents a structured summary organized by file and line range
5. Suggests concrete code/document changes to address review feedback
6. Helps draft response text for the user to copy/paste back to GitLab

**Key principle**: This skill is read-only. It never posts, edits, or resolves comments. All output goes to the console where the prompt was received.

## Prerequisites

- `glab` CLI installed (`brew install glab` or https://gitlab.com/gitlab-org/cli)
- Authenticated with `gitlab.evroc.dev` (run `glab auth login` and select `gitlab.evroc.dev` when prompted)
- Must be run from inside a git repository with a GitLab remote on gitlab.evroc.dev, OR an MR ID must be provided
- Repository must have an open MR for the current branch (if using auto-detection)

## Step-by-Step Workflow

### Step 1: Identify the MR

First, determine which MR to analyze:

```bash
# Current branch name
git rev-parse --abbrev-ref HEAD

# Check if there's an open MR for this branch
GLAB_HOST=gitlab.evroc.dev glab mr view --json 2>/dev/null | head -1
```

**Auto-detection logic**:
- If already on a feature branch (not `main`/`master`), try to find the MR for current branch
- If on `main`/`master`, or if auto-detection fails, ask the user:
  - "Which MR would you like to analyze? Provide MR number or branch name:"

Store the MR ID for subsequent queries.

### Step 2: Fetch All Discussions and Comments

**IMPORTANT**: The `glab mr note list` command does NOT exist in glab CLI. Instead, use the GitLab API directly to fetch all MR notes:

```bash
# First, get the project ID and MR details
GLAB_HOST=gitlab.evroc.dev glab mr view <MR_ID> --json | jq '{project_id: .project_id, iid: .iid}'

# Fetch all notes (both general comments and diff-level comments) using the API
# This returns an array of notes including DiffNote types with position data
GLAB_HOST=gitlab.evroc.dev glab api "projects/<PROJECT_ID>/merge_requests/<MR_IID>/notes" --output json > /tmp/mr_notes.json

# Alternative: Fetch discussions endpoint (groups threaded discussions)
GLAB_HOST=gitlab.evroc.dev glab api "projects/<PROJECT_ID>/merge_requests/<MR_IID>/discussions" --output json > /tmp/mr_discussions.json
```

**Understanding the note types:**

The API returns notes with different `type` values:
- `null` or missing: General MR comment (not attached to code)
- `"DiffNote"`: Comment attached to a specific line in a diff
- `"Discussion"`: Threaded discussion (may contain multiple notes)

**Key fields to extract:**

| Field | Description |
|-------|-------------|
| `id` | Note ID |
| `type` | `"DiffNote"` for diff comments, `null` for general |
| `body` | Comment text |
| `author.username` | Comment author |
| `created_at` | Timestamp |
| `system` | `true` for automated GitLab system notes (commit additions, status changes, etc.) |
| `resolvable` | Whether note can be resolved |
| `resolved` | Resolution status (only for resolvable notes) |
| `position` | **Diff position object** (only for DiffNote types) |

**Critical filtering - ALWAYS filter out system notes:**

System notes are automated entries created by GitLab (not human reviewers):
- Commit addition notifications ("added 3 commits")
- Status changes ("marked as ready", "merged")
- Assignment changes ("assigned to @user")
- Pipeline status updates
- Title/description changes

**You MUST filter these out** by checking `system: true`:
```python
# Only keep actual review comments, not system notes
actual_comments = [n for n in notes if not n.get('system', False)]
```

The `position` object for DiffNote types contains file/line info:

| Position Field | Description |
|----------------|-------------|
| `new_path` | File path in new version |
| `old_path` | File path in old version |
| `new_line` | Line number in new version |
| `old_line` | Line number in old version |
| `line_range` | Multi-line comment range |
| `head_sha` / `base_sha` | Commit SHAs |

### Step 3: Parse and Organize Comments

Process the JSON from the API to group comments by file:

**Step 3.1: Parse the API response**

```python
import json

# Load from the saved API response
with open('/tmp/mr_notes.json', 'r') as f:
    notes = json.load(f)

print(f"Total API entries: {len(notes)}")
```

**Step 3.2: Filter out system notes (CRITICAL)**

System notes are automated GitLab entries, NOT human review comments:
```python
# Filter out system notes - keep only actual review comments
review_comments = [n for n in notes if not n.get('system', False)]

print(f"Review comments found: {len(review_comments)}")
```

**Step 3.3: Categorize comments**

```python
# General MR comments (no file attachment)
general_comments = [n for n in review_comments if n.get('type') != 'DiffNote']

# File-specific comments (DiffNote type)
diff_comments = [n for n in review_comments if n.get('type') == 'DiffNote']

# Filter resolved/unresolved
unresolved = [n for n in review_comments if n.get('resolvable') and not n.get('resolved')]
resolved = [n for n in review_comments if n.get('resolvable') and n.get('resolved')]

print(f"  General comments: {len(general_comments)}")
print(f"  Diff comments: {len(diff_comments)}")
print(f"  Unresolved: {len(unresolved)}")
print(f"  Resolved: {len(resolved)}")
```

**Step 3.4: Group by file**

```python
files = {}
for comment in review_comments:
    if comment.get('type') == 'DiffNote' and comment.get('position'):
        path = comment['position'].get('new_path', 'Unknown')
    else:
        path = 'General'
    
    if path not in files:
        files[path] = []
    files[path].append(comment)
```

**Filtering resolved comments** (by default):
- Skip any note where `resolved: true` — these are completed and don't need action
- Skip any note where `resolvable: true` AND `resolved: true`
- Keep non-resolvable notes (general comments that can't be "resolved" in GitLab)
- If user asks to "show all comments" or "include resolved", skip this filter

**Groups to create**:

1. **General MR Comments** (no file attachment, `type: null` or not DiffNote)
2. **File-specific Comments** (grouped by file path from `position.new_path`)
   - Sorted by line number within each file
   - Include line range for context

**For each comment, extract**:
- Author (`@username` from `author.username`)
- File path (if DiffNote, from `position.new_path`)
- Line number (from `position.new_line`)
- Comment body (truncated if very long, with "..." indicator)
- Resolution status (`resolved` field)
- Whether it's a reply (check if it's part of a discussion thread)

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
    
    This looks good overall, but I have a few questions about the
    approach taken in the auth module...
    
    └─ Reply from @author — 2024-01-15 15:10
       I considered that, but went with this approach because...

[2] @reviewer2 — 2024-01-15 16:45
    Status: Resolved ✓
    
    Nit: typo in the PR description

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 FILE: src/auth/middleware.ts (<count> comments)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Line 45 │ @reviewer1 — Unresolved
────────┼─────────────────────────────────────────────────────────────────────
        │ Consider using a constant here instead of magic number 300.
        │ Suggested: STATUS_CODE_REDIRECT = 300

Line 67-72 │ @reviewer2 — Unresolved
───────────┼───────────────────────────────────────────────────────────────────
           │ This function is getting complex. Could we split the validation
           │ logic into a separate helper? Something like:
           │ 
           │ ```typescript
           │ function validateToken(token: string) { ... }
           │ ```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 FILE: src/api/users.ts (<count> comments)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Line 123 │ @reviewer1 — Resolved ✓
─────────┼────────────────────────────────────────────────────────────────────
         │ Add return type annotation here
```

### Step 5: Suggest Code/Document Changes (Optional)

For actionable comments (those pointing out specific issues), analyze the local files and propose concrete changes:

**When to suggest changes**:
- A comment mentions a specific line and suggests a fix (naming, logic, formatting)
- A reviewer asks for refactoring or code reorganization
- Documentation or comments need updates
- A bug or issue is pointed out that can be fixed

**Critical: Understand full MR context first**

Before suggesting changes to address review comments, the agent MUST understand the broader context of the MR. A comment on a specific line may relate to patterns elsewhere in the change, dependencies on other files, or the overall architectural approach.

**Process**:

1. **First, gather full MR context**:
   ```bash
   # Show the complete diff for this MR
   git diff origin/<target>...HEAD
   
   # List all files changed in this MR
   git diff --name-only origin/<target>...HEAD
   
   # Show commits in this MR
   git log --oneline origin/<target>..HEAD
   
   # Show MR description for context
   GLAB_HOST=gitlab.evroc.dev glab mr view <MR_ID> --json | jq '.description'
   ```

2. **Read files with comments in their entirety**:
   ```bash
   # Read the full file, not just the commented section
   cat <file-path>
   
   # Understand imports/dependencies
   head -30 <file-path>
   ```

3. **Understand cross-file relationships**:
   - If the comment is about an exported function, check where it's used
   - If about types/interfaces, check consistency across files
   - If about naming conventions, check if the pattern exists elsewhere in the change
   
   ```bash
   # Find uses of a symbol across the MR
   git grep -n "symbolName" -- $(git diff --name-only origin/<target>..HEAD)
   ```

4. **Identify the root cause**:
   - Don't just treat the symptom at the commented line
   - Ask: Why did the reviewer comment here? What pattern or issue are they catching?
   - Does this same issue exist elsewhere in the MR?
   - Does the fix need to be applied in multiple places?

5. **Read the relevant section(s)** at the commented line range:
   ```bash
   # Show context around the commented line (e.g., 10 lines before/after)
   sed -n '<start>,<end>p' <file-path>
   # Or use git to show the file at HEAD
   git show HEAD:<file-path> | sed -n '<start>,<end>p'
   ```

6. **Analyze the comment intent**:
   - Is it a naming issue? (rename variable/function) — Check if this naming appears elsewhere
   - Is it a logic issue? (fix condition, add validation) — Understand the data flow
   - Is it a refactoring request? (extract function, split code) — Check dependencies
   - Is it documentation? (add/update comments, fix typos)
   - Is it about consistency? (with codebase conventions, with other parts of this MR)

7. **Generate proposed changes** in unified diff format:

```
🛠️  SUGGESTED CHANGES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

For comment on src/auth/middleware.ts Line 45 (@reviewer1):
"Consider using a constant here instead of magic number 300."

Proposed change:
──────────────────────────────────────────────────────────────────────────────
--- a/src/auth/middleware.ts
+++ b/src/auth/middleware.ts
@@ -42,9 +42,11 @@
 import { Request, Response } from 'express';
 import { validateUser } from './users';
 
+const STATUS_CODE_REDIRECT = 300;
+
 export function handleAuth(req: Request, res: Response) {
   if (req.isAuthenticated()) {
-    res.redirect(300, '/dashboard');
+    res.redirect(STATUS_CODE_REDIRECT, '/dashboard');
     return;
   }
   // ... rest of function
──────────────────────────────────────────────────────────────────────────────

For comment on src/auth/middleware.ts Lines 67-72 (@reviewer2):
"This function is getting complex. Could we split the validation logic?"

Proposed change:
──────────────────────────────────────────────────────────────────────────────
--- a/src/auth/middleware.ts
+++ b/src/auth/middleware.ts
@@ -65,20 +65,28 @@ export function handleAuth(req: Request, res: Response) {
     return;
   }
 
-  // Validate token format
-  const token = req.headers.authorization?.split(' ')[1];
-  if (!token || token.length < 32) {
-    res.status(401).json({ error: 'Invalid token' });
-    return;
-  }
-  
-  // Check token expiration
-  const decoded = jwt.decode(token);
-  if (decoded.exp < Date.now() / 1000) {
-    res.status(401).json({ error: 'Token expired' });
+  const tokenResult = validateToken(req);
+  if (!tokenResult.valid) {
+    res.status(401).json({ error: tokenResult.error });
     return;
   }
   
   // ... rest of function
 }
+
+function validateToken(req: Request): { valid: boolean; error?: string } {
+  const token = req.headers.authorization?.split(' ')[1];
+  if (!token || token.length < 32) {
+    return { valid: false, error: 'Invalid token' };
+  }
+  
+  const decoded = jwt.decode(token);
+  if (decoded.exp < Date.now() / 1000) {
+    return { valid: false, error: 'Token expired' };
+  }
+  
+  return { valid: true };
+}
──────────────────────────────────────────────────────────────────────────────
```

**Change suggestion guidelines**:
- Present changes in standard unified diff format (`---` / `+++` with `@@` hunks)
- Include 3-5 lines of context before/after changes for clarity
- Only propose changes for files that exist in the local working tree
- If a suggestion involves multiple files, show each separately
- If the comment is ambiguous, present 2-3 alternative approaches with trade-offs
- For documentation-only changes (typo fixes, wording), show the excerpt with `[-old-]{+new+}` inline diff style
- Always preserve the original indentation and style of the file
- Mark destructive changes (deletions, renames) with ⚠️  warning

**When NOT to suggest changes**:
- The comment is asking a question (seeking clarification)
- The comment is giving high-level design feedback ("consider a different approach")
- The change would require modifying files not in the local repo
- The reviewer explicitly said "this is just a nit, feel free to ignore"
- **Insufficient context**: If you cannot determine the full context of the change (cross-file dependencies, architectural constraints), do not suggest changes — instead draft a response asking for clarification or acknowledging the issue with a plan to investigate

### Step 6: Generate Response Drafts (Optional)

If the user asks to "answer" or "respond to" specific comments:

1. Identify which comment(s) they want to address (by number or description)
2. Reference any code changes already suggested in Step 5
3. For each comment, draft a response:

```
📤 SUGGESTED RESPONSES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

For comment on src/auth/middleware.ts Line 45 (@reviewer1):
──────────────────────────────────────────────────────────────────────────────
Good catch! I've extracted that to a constant `STATUS_CODE_REDIRECT` — see
suggested change above. Would you prefer it in a separate constants file at
src/auth/constants.ts or keep it local to this module?
──────────────────────────────────────────────────────────────────────────────

For comment on src/auth/middleware.ts Lines 67-72 (@reviewer2):
──────────────────────────────────────────────────────────────────────────────
You're right, it's getting unwieldy. I've refactored into a separate
`validateToken()` helper function as suggested above. It now returns a result
object `{ valid, error? }` which cleans up the main function. Let me know if
you'd prefer the helper in a separate utils module instead.
──────────────────────────────────────────────────────────────────────────────
```

**Response drafting guidelines**:
- Acknowledge the specific point raised
- Reference any code changes proposed in Step 5
- Ask clarifying questions if the feedback is ambiguous
- Suggest trade-offs when appropriate (e.g., "I can do X, but that would mean Y")
- Keep tone professional and collaborative
- Include code snippets if relevant

### Step 7: Action Summary

Conclude with a summary of what's been presented:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Showing: Unresolved comments only (use "show all" to include resolved)

Total unresolved comments: <N>
  ├─ General: <N>
  ├─ File-specific: <N>
  └─ Files with comments: <N> (<list of file paths>)

Resolved comments filtered out: <N> (already completed)

Unresolved comments requiring attention:
  • src/auth/middleware.ts: Lines 45, 67-72
  • src/api/users.ts: Line 123

⚠️  To respond to these comments, you must manually post replies on GitLab.
    Copy the suggested responses above and paste them into the MR discussion.
    
    MR URL: https://gitlab.evroc.dev/<org>/<repo>/-/merge_requests/<MR_ID>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Edge Cases

- **No open MR for current branch**: Inform the user and ask for an MR number
- **MR has no comments**: Report clearly that the review queue is empty
- **All comments are resolved**: Report "All review comments are marked as resolved ✓" and offer to show resolved comments anyway
- **Comments on deleted files**: Handle gracefully — show the old file path and note that the file was deleted
- **Multi-line comments**: Display as "Line X-Y" and include full context
- **Threaded discussions**: Show the thread hierarchy (parent → replies)
- **System notes**: Filter out or clearly mark system-generated notes (e.g., "added 3 commits")
- **Resolved comments**: Filtered out by default; only show unresolved actionable items
- **Very long comments**: Truncate at ~10 lines with "..." and note full text available on GitLab
- **Comment on outdated diff**: Note when a comment refers to an older commit SHA
- **Large MRs with 50+ comments**: Show summary first, then paginate or filter by file on request

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `glab: command not found` | Install via `brew install glab` or download from https://gitlab.com/gitlab-org/cli |
| `401 Unauthorized` | Check you're authenticated with gitlab.evroc.dev (run `glab auth login`) |
| `404 Not Found` | MR may not exist; verify the MR number or branch name |
| `no merge request found for branch` | Current branch has no open MR; provide an MR number explicitly |
| **"No comments found" but MR has comments** | You're likely not filtering `system: false`. System notes are 90%+ of entries. Always filter: `[n for n in notes if not n.get('system', False)]` |
| **Missing diff comments** | Use `/projects/<id>/merge_requests/<iid>/notes` endpoint, not `/discussions`. Notes endpoint returns all comment types including `DiffNote` |
| Empty JSON response | MR exists but has no human review comments yet (only system notes) |
| Missing `position` fields | Not all notes are diff notes; general MR comments won't have position data |

---

## Notes

- **Read-only by design**: This skill intentionally never modifies GitLab state. It's for analysis and preparation only.
- **JSON output**: The `-F json` flag is required to parse file/line data; text output doesn't include position information.
- **Full context required**: Always examine the complete MR diff and understand cross-file relationships before suggesting changes. A comment on one line may indicate a pattern that exists elsewhere, or may depend on changes in other files.
- **Line numbers**: Always display `new_line` (line number in the post-merge version) rather than `old_line` for clarity.
- **Copy-paste friendly**: Response drafts should be ready to copy and paste into GitLab's web UI.
- **Thread context**: When showing threaded discussions, include enough parent context to understand the reply.
- **MR status**: Include the MR state (open/merged/closed) in the header to avoid confusion when reviewing old MRs.
- **Authentication**: Always use `GLAB_HOST=gitlab.evroc.dev` to ensure the correct GitLab instance is used.

## Context-First Approach

This skill emphasizes understanding the **full MR context** before suggesting changes:

**Why context matters**:
- A reviewer commenting on line 45 may be identifying a pattern that repeats elsewhere
- Refactoring one function may require updating imports, tests, or call sites in other files  
- Naming conventions should be consistent across the entire change, not just at the commented location
- Logic errors at one site may indicate the same error was made elsewhere

**When to pause and gather more context**:
- The comment mentions a pattern or convention — check if it applies elsewhere
- The fix involves changing an exported symbol — find all usages first
- The comment is about architecture or design — understand the full change before proposing alternatives
- Multiple files in the MR touch related functionality — read them all

**Output when context is insufficient**:
If you cannot gather enough context to confidently suggest changes:
```
⚠️  Insufficient Context
    
The comment on src/auth/middleware.ts Line 45 suggests moving the logic to
a shared utility. However, I need to see how this pattern is used in other
auth-related files changed in this MR.

To suggest a proper fix, I need to examine:
- Other auth files in this MR (src/auth/*.ts)
- How the current function is called from other modules
- Whether a shared utility already exists

Would you like me to explore these files first, or would you prefer to
address this comment manually?
```

## Example Usage

**User prompt**: "Review my MR comments"
```
# Auto-detects MR from current branch, fetches and displays unresolved comments
# (resolved/completed comments are filtered out by default)
```

**User prompt**: "Analyze review comments for MR 42"
```
# Fetches comments for MR !42 specifically, showing only unresolved items
```

**User prompt**: "Show all comments including resolved"
```
# Shows both unresolved and already-resolved comments
```

**User prompt**: "Draft responses to the middleware comments"
```
# Shows existing unresolved comments on middleware.ts with suggested reply text
```

**User prompt**: "Show me unresolved comments only"
```
# Filters to show only unresolved/open comment threads (default behavior)
```

**User prompt**: "Suggest fixes for the review comments"
```
# Analyzes unresolved actionable comments and proposes concrete code changes
```

**User prompt**: "Review and fix my MR"
```
# Full workflow: shows unresolved comments + suggests code changes + drafts responses
```
