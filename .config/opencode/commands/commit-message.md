---
description: Generate git commit message for staged changes
---

**Only generate text. Never run git commit or other git commands.**

Generate a commit message from staged changes.

Arguments: $ARGUMENTS

## Steps

1. Check what's staged: `git status` and `git diff --staged --stat`
2. Read the diff: `git diff --staged`
3. Check repo style: `git log -20 --oneline`
5. Write the message

## Output Format

```
<header>

<body>

--- 

To commit:

git commit -m "<header>" -m "<body>"
```

## Guidelines

**Header (first line):**
- Keep it under 72 characters
- Use imperative mood: "Add" not "Added"
- Match the repo's style (check recent commits)
- Examples: "file-store: Add OCFS2 support", "Fix auth bug", "Update docs"

**Body (2-4 sentences):**
- Explain what changed and why
- Use plain language, not buzzwords
- No bullet points or file lists
- Examples of good vs bad:
  - BAD: "Comprehensive implementation leveraging cutting-edge paradigms"
  - GOOD: "Add OCFS2 formatting job to prepare block devices before mounting"
  - BAD: "Enhanced functionality by consolidating various initialization procedures"
  - GOOD: "Move OCFS2 mount setup into the init container so it runs before Ganesha starts"

## Rules

- NEVER run git commit or push
- Only output the message text
- Keep it simple and direct
- Match the style of recent commits in this repo
