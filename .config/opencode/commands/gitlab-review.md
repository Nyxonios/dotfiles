---
description: Review a GitLab Merge Request
gitlab-review-mr: true
---

Load the `gitlab-review-mr` skill and perform a comprehensive code review of the GitLab Merge Request.

If an MR ID is provided as an argument, review that specific MR. Otherwise, auto-detect the MR from the current branch.

Arguments: $ARGUMENTS

Follow the skill workflow to:
1. Identify the MR (from current branch or provided MR ID)
2. Fetch MR metadata, description, and diff
3. Retrieve existing review comments and discussions
4. Read all changed files for full context
5. Perform comprehensive code review across:
   - Code quality and best practices
   - Potential bugs and logic issues
   - Security vulnerabilities
   - Performance implications
   - Architecture and design
   - Test coverage
   - Documentation
6. Present a structured review report with severity ratings
7. Provide actionable feedback with specific file/line references

Always use GLAB_HOST=gitlab.evroc.dev for all glab commands.

For a quick review focusing only on critical issues, ask the user to specify "quick" or "high-level".
For a deep review including all severity levels, proceed with full analysis.
