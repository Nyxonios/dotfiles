---
name: mr-message
description: Generate concise GitLab MR descriptions from diffs or recent commits
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: gitlab
---

# Skill: mr-message

Generate a concise GitLab Merge Request description.

**Arguments:** $ARGUMENTS

## Steps

1. Parse input to determine mode:
   - MR number (e.g., `9412`, `!123`) → MR Mode
   - "last N commits" or similar → Commit Mode
   - Otherwise → ask for clarification

2. Gather information:
   - **MR Mode:** `glab mr view <ID> -F json` and `glab mr diff <ID>`
   - **Commit Mode:** `git log -<N> --oneline` and `git diff HEAD~<N>..HEAD`

3. Analyze changes and identify:
   - Primary purpose (feature, fix, refactor, etc.)
   - Affected scope/component
   - 2-4 key changes (ignore trivial edits)
   - Any breaking changes

4. Write the description

## Output Format

```
<title>

<body>

---

To update MR:

glab mr update <MR_ID> --description "<title>

<body>"
```

## Guidelines

**Title (first line):**
- Keep it under 72 characters
- Use imperative mood: "Add" not "Added"
- Include scope if clear: "filestore: Add PVC reconciliation"
- Examples: "Fix VIP infinite update loop", "Add ganesha-manager-init component"

**Body (2-4 sentences):**
- Explain what changed and why
- Use plain language, not buzzwords
- No bullet points or file lists
- Focus on the "why" not "what"
- Examples of good vs bad:
  - BAD: "Comprehensive implementation leveraging cutting-edge paradigms"
  - GOOD: "Add init container to format block devices before Ganesha starts"
  - BAD: "Enhanced functionality by consolidating various procedures"
  - GOOD: "Preserve Kube-OVN assigned IPs to prevent infinite update loops"

**Breaking changes:**
- Add "BREAKING CHANGE: <description>" at the end if applicable

## Rules

- NEVER run `glab mr update` or modify the MR
- Only output the description text
- Keep it simple and direct
- Maximum 4 sentences in body
- Match the style of recent commits in this repo

## Examples

**Input:** "Create description for MR 9412"

**Output:**
```
filestore: Add PVC reconciliation and ganesha-manager-init

Add reconcilePVC() to create PVCs with configurable default size.
Add ganesha-manager-init init container for block device formatting.
Fix VIP infinite update loop by preserving Kube-OVN assigned IPs.
Update LabelKeyManagedBy to use Kubernetes recommended label.

---

To update MR:

glab mr update 9412 --description "filestore: Add PVC reconciliation and ganesha-manager-init

Add reconcilePVC() to create PVCs with configurable default size.
Add ganesha-manager-init init container for block device formatting.
Fix VIP infinite update loop by preserving Kube-OVN assigned IPs.
Update LabelKeyManagedBy to use Kubernetes recommended label."
```

**Input:** "Summarize last 3 commits"

**Output:**
```
filestore: Fix VIP reconciliation and standardize labels

Preserve Kube-OVN assigned IPs in VIP desired state to prevent
infinite update loops during reconciliation. Move deletion logic after
strategy evaluation. Update LabelKeyManagedBy to Kubernetes standard.

---

To update MR:

glab mr update <MR_ID> --description "filestore: Fix VIP reconciliation and standardize labels

Preserve Kube-OVN assigned IPs in VIP desired state to prevent
infinite update loops during reconciliation. Move deletion logic after
strategy evaluation. Update LabelKeyManagedBy to Kubernetes standard."
```
