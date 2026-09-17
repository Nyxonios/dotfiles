---
description: Review a GitLab Merge Request
gitlab-review-mr: true
code-review: true
---

Load the `gitlab-review-mr` skill (orchestrator) and the `code-review` skill
(review engine), then perform a thorough multi-pass code review of the GitLab
Merge Request.

If an MR ID is provided as an argument, review that specific MR. Otherwise,
auto-detect the MR from the current branch.

Arguments: $ARGUMENTS

Follow the `gitlab-review-mr` workflow to:
1. Identify the MR (from current branch or provided MR ID)
2. Fetch MR metadata, description, and diff
3. Retrieve existing review comments and discussions (via `gitlab-analyze-review-comments` if available)
4. Read all changed files for full context
5. Assemble the review package

Then delegate the actual review to the `code-review` skill, which performs:
- Blast-radius & scope assessment
- Correctness & logic pass
- Security pass
- Performance pass
- Testing & validation pass
- Architecture & maintainability pass
- Completeness & documentation pass (deep mode)

Present a structured review report with P0/P1/P2/P3/Nit severity ratings,
`file:line` evidence, and actionable fixes.

Always use GLAB_HOST=gitlab.evroc.dev for all glab commands.

For a quick review focusing only on critical issues, ask the user to specify
"quick" or "high-level". The orchestrator will set depth=quick for the
`code-review` skill.

For a deep review including all severity levels and completeness checks, proceed
with depth=deep.
