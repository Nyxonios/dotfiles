---
name: commit-message
description: Generate a concise git commit message from staged changes. Use when the user wants to commit, write a commit message, or summarize the current diff.
license: MIT
---

# Skill: commit-message

Generate a concise, conventional-commit-style message for the current changes.

**Arguments:** $ARGUMENTS

## Steps

1. Determine what to diff:
   - If there are staged changes (`git diff --staged --quiet` fails → non-zero), use `git diff --staged`.
   - Otherwise use `git diff` and note that nothing is staged.
2. Gather style context:
   - `git log --oneline -5`
3. Analyze the diff and identify:
   - **Type:** `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `ci`, etc.
   - **Scope:** component, package, or file area (if obvious)
   - **Summary:** what changed and why (in plain language)
4. Write the commit message

## Output Format

```
<type>[(scope)]: <summary>

[Optional body explaining why or important details]
```

## Guidelines

**Title (first line):**
- Maximum 72 characters
- Use imperative mood: "Add" not "Added"
- Include scope when the change is localized: `filestore: Add PVC reconciliation`
- Examples: "fix: Prevent VIP infinite update loop", "docs: Update API examples"

**Body (optional):**
- Only add a body if the "why" isn't obvious from the title
- Use plain language, not buzzwords
- No bullet lists of changed files
- Maximum 2–4 sentences

**Breaking changes:**
- Append "BREAKING CHANGE: <description>" at the end of the body if applicable

## Rules

- NEVER run `git commit` or any write operation automatically
- Only output the commit message text and the command to use it
- Keep it simple and direct
- Match the style of recent commits in this repo

## Examples

**Staged diff:** Added `reconcilePVC()` to controller

**Output:**
```
feat: Add PVC reconciliation

Add reconcilePVC() to create PVCs with a configurable default size.

---

git commit -m "feat: Add PVC reconciliation

Add reconcilePVC() to create PVCs with a configurable default size."
```
