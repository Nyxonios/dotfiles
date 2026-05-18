---
description: Analyze GitLab MR review comments
agent: build
subtask: true
---

Load the `gitlab-analyze-review-comments` skill and analyze the review comments on the current GitLab Merge Request.

If an MR ID is provided as an argument, analyze that specific MR. Otherwise, auto-detect the MR from the current branch.

Arguments: $ARGUMENTS

Follow the skill workflow to:
1. Identify the MR (from current branch or provided MR ID)
2. Fetch all discussions and comments (both general and diff-level)
3. Parse JSON output to extract file paths, line numbers, and comment content
4. Present a structured summary organized by file and line range
5. Filter out resolved comments by default (show only actionable items)
6. Suggest concrete code changes to address review feedback
7. Help draft response text for the user to copy/paste back to GitLab

Always use GLAB_HOST=gitlab.evroc.dev for all glab commands.
