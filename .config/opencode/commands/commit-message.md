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
4. Check git-stack: `~/dotfiles/.config/opencode/git-stack/git-stack list`
5. Write the message

## Output Format

```
<header>

<body>

---

Review order:
<branch-1>
└── <branch-2>
    └── <branch-3>
        └── <current-branch> <--- You are here
            └── <child-branch>

---

To commit:

git commit -m "<header>" -m "<body>"
```

**Note:** The "Review order" section is for informational purposes only. Do NOT include it in the commit message body or the `git commit` command. The commit should only contain `<header>` and `<body>`.

## Git-Stack Integration

When running `git-stack list`, the output shows a tree with `*` marking the current branch.

**Example output:**
```
file-store-operator (/home/mseller/...)
└── main
    └── mseller/file-store-resource-rendering
        └── mseller/file-store-operator-reconciliation
            └── mseller/file-store-operator-reconciliation-ganesha-init
                └── mseller/file-store-operator-resource-creation
                    └── mseller/file-store-operator-resource-job-creation *
                        └── mseller/file-store-operator-creation-reconciliation
```

**Format the Review order section:**
1. **Skip the base branch** (e.g., `main`) - start from the first feature branch
2. **Use tree visuals**: `└──` for the last child, `├──` for siblings, `    ` (4 spaces) for indentation
3. **Mark current branch** with ` <--- You are here` (with 1 space before the arrow)
4. **Include descendants** (branches under current) to show the full context

**In the example above, output:**
```
file-store-operator: Add resource job creation logic

Implement the job creation controller for file store operator
resources. This handles the reconciliation loop for creating
and managing Kubernetes jobs.

---

Review order:
mseller/file-store-resource-rendering
└── mseller/file-store-operator-reconciliation
    └── mseller/file-store-operator-reconciliation-ganesha-init
        └── mseller/file-store-operator-resource-creation
            └── mseller/file-store-operator-resource-job-creation <--- You are here
                └── mseller/file-store-operator-creation-reconciliation

---

To commit:

git commit -m "file-store-operator: Add resource job creation logic" -m "Implement the job creation controller for file store operator resources. This handles the reconciliation loop for creating and managing Kubernetes jobs."
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
- The commit message body (used in `git commit -m "<body>"`) should NOT include the "Review order" section
- If current branch is NOT in a git-stack, omit the "Review order" section entirely from output
- If current branch IS in a git-stack:
  - OUTPUT the "Review order" section for user information (between the body and the "To commit" section)
  - EXCLUDE "Review order" from the commit message body in the `git commit` command
  - Start from the first feature branch (skip `main` or base branch)
  - Use `└──` prefix for each branch in the tree
  - Indent with 4 spaces for each level
  - Mark current branch with ` <--- You are here`
  - Include all descendant branches below current
