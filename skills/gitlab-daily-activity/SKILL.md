---
name: gitlab-daily-activity
description: Generate a summary of your GitLab activity for the current day
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: gitlab
---

# Skill: gitlab-daily-activity

Generate a summary of your GitLab activity for the current day.

**Arguments:** $ARGUMENTS (optional date override: YYYY-MM-DD format)

## Overview

This skill retrieves and summarizes your daily GitLab activity across all projects, including:

- Merge Requests created, merged, or updated
- Comments and reviews left on MRs
- Issues created, closed, or commented on
- Commits pushed
- Pipeline status changes

## Steps

1. **Determine the date range:**
   - Default: Today (from 00:00:00 to 23:59:59 in your local timezone)
   - Optional: Parse date from arguments (YYYY-MM-DD format)

2. **Fetch activity data from GitLab:**
   
   Use `glab` to query your recent activity:
   
   ```bash
   # Set the GitLab host
   export GLAB_HOST=gitlab.evroc.dev
   
   # Get your user info
   USER=$(glab api user | jq -r '.username')
   
   # Calculate date range (today, midnight to 23:59:59)
   DATE_START=$(date -d "$(date +%Y-%m-%d)" +%Y-%m-%dT00:00:00Z)
   DATE_END=$(date -d "$(date +%Y-%m-%d) 23:59:59" +%Y-%m-%dT23:59:59Z)
   
   # Fetch recent activity
   glab api "/users/$USER/events" --paginate | jq --arg start "$DATE_START" --arg end "$DATE_END" \
     '[.[] | select(.created_at >= $start and .created_at <= $end)]'
   ```

3. **Fetch MRs authored by you:**
   
   ```bash
   # Get MRs created today
   glab api "/merge_requests?author_id=$USER_ID&state=all&created_after=$DATE_START&created_before=$DATE_END" --paginate
   ```

4. **Fetch MRs merged by you:**
   
   ```bash
   # Get MRs merged today
   glab api "/merge_requests?author_id=$USER_ID&state=merged&target_branch=main&updated_after=$DATE_START&updated_before=$DATE_END" --paginate | jq '[.[] | select(.merged_at >= $start and .merged_at <= $end)]'
   ```

5. **Fetch your comments:**
   
   ```bash
   # Get recent notes (comments) by you
   glab api "/users/$USER/events?action_type=commented" --paginate | jq --arg start "$DATE_START" --arg end "$DATE_END" \
     '[.[] | select(.created_at >= $start and .created_at <= $end)]'
   ```

6. **Fetch issues activity:**
   
   ```bash
   # Issues created today
   glab api "/issues?author_id=$USER_ID&state=all&created_after=$DATE_START&created_before=$DATE_END" --paginate
   
   # Issues closed today
   glab api "/issues?author_id=$USER_ID&state=closed&updated_after=$DATE_START&updated_before=$DATE_END" --paginate | jq '[.[] | select(.closed_at >= $start and .closed_at <= $end)]'
   ```

7. **Organize and categorize activity:**
   - **Merge Requests:** Created, Merged, Reviewed (comments)
   - **Issues:** Created, Closed, Commented
   - **Pipelines:** Triggered, Status changes
   - **Commits:** Pushed (if available)

8. **Generate the summary report:**

## Output Format

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  Daily GitLab Activity Summary                                               ║
║  <Date> — <Username>                                                         ║
╚══════════════════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 OVERVIEW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Merge Requests:  <N> created | <N> merged | <N> reviewed
Issues:          <N> created | <N> closed | <N> commented
Pipelines:       <N> triggered | <N> passed | <N> failed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔀 MERGE REQUESTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Created (<count>):
  • !<MR_ID> [<project>] <title> — <state>
  • !<MR_ID> [<project>] <title> — <state>

Merged (<count>):
  • !<MR_ID> [<project>] <title>
    └─ Branch: <source> → <target>

Reviewed (<count>):
  • !<MR_ID> [<project>] <title>
    └─ <N> comments left

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 ISSUES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Created (<count>):
  • #<ISSUE_ID> [<project>] <title>

Closed (<count>):
  • #<ISSUE_ID> [<project>] <title>

Commented (<count>):
  • #<ISSUE_ID> [<project>] <title>
    └─ <N> comments

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 PIPELINES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Triggered (<count>):
  • [<project>] Pipeline #<ID> — <status>
    └─ Branch: <branch> | Duration: <time>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 COMMITS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Pushed (<count>):
  • [<project>/<branch>] <commit_message> (<hash>)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✨ HIGHLIGHTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• <Highlight 1>
• <Highlight 2>
• <Highlight 3>

━ Generated at <timestamp> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Examples

**Input:** "Show my daily activity"

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  Daily GitLab Activity Summary                                               ║
║  May 18, 2026 — mseller                                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 OVERVIEW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Merge Requests:  2 created | 1 merged | 3 reviewed
Issues:          0 created | 1 closed | 2 commented
Pipelines:       4 triggered | 4 passed | 0 failed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔀 MERGE REQUESTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Created (2):
  • !9143 [engineering/monorepo] Add PVC reconciliation and ganesha-manager-init — Draft
  • !9145 [engineering/cloud-config] Update vault configuration for new region — Open

Merged (1):
  • !9138 [engineering/monorepo] Fix VIP reconciliation loop
    └─ Branch: fix/vip-reconciliation → main

Reviewed (3):
  • !9140 [engineering/monorepo] Refactor auth middleware
    └─ 2 comments left
  • !9135 [engineering/giant] Update dependencies
    └─ 1 comment left
  • !9129 [engineering/metal-config] Add new playbook for disk provisioning
    └─ 3 comments left

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 ISSUES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Created (0):
  (none)

Closed (1):
  • #4521 [engineering/monorepo] Memory leak in filestore controller

Commented (2):
  • #4518 [engineering/monorepo] Node registration failing in prod
    └─ 1 comment
  • #4502 [engineering/cloud-config] Vault unseal automation
    └─ 1 comment

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 PIPELINES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Triggered (4):
  • [engineering/monorepo] Pipeline #48291 — Success
    └─ Branch: main | Duration: 12m 34s
  • [engineering/monorepo] Pipeline #48288 — Success
    └─ Branch: fix/vip-reconciliation | Duration: 8m 12s
  • [engineering/giant] Pipeline #1234 — Success
    └─ Branch: main | Duration: 45m 02s
  • [engineering/cloud-config] Pipeline #567 — Success
    └─ Branch: feature/vault-update | Duration: 3m 15s

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 COMMITS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Pushed (6):
  • [engineering/monorepo/main] Merge branch 'fix/vip-reconciliation' (a1b2c3d)
  • [engineering/monorepo/fix/vip-reconciliation] Fix VIP infinite update loop (e4f5g6h)
  • [engineering/monorepo/fix/vip-reconciliation] Preserve Kube-OVN assigned IPs (i7j8k9l)
  • [engineering/cloud-config/feature/vault-update] Update vault config (m0n1o2p)
  • [engineering/cloud-config/feature/vault-update] Add new region endpoints (q3r4s5t)
  • [engineering/giant/main] Update dependencies (u6v7w8x)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✨ HIGHLIGHTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Merged !9138 fixing the VIP reconciliation infinite loop issue
• Active reviewer: left comments on 3 MRs across 3 different projects
• All 4 pipelines passed with no failures
• Closed issue #4521 resolving the filestore memory leak

━ Generated at 18:30:00 UTC ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Input:** "Activity for yesterday"

**Input:** "Activity for 2026-05-15"

## Alternative Approach: Using GitLab Events API

If the glab API commands don't work directly, you can use the raw GitLab API:

```bash
# Get your user ID
USER_ID=$(glab api user | jq -r '.id')

# Fetch events for today
glab api "/users/$USER_ID/events" --paginate

# Filter by date in jq
```

## Prerequisites

- `glab` CLI installed (`brew install glab` or https://gitlab.com/gitlab-org/cli)
- Authenticated with `gitlab.evroc.dev` (run `glab auth login` and select `gitlab.evroc.dev`)
- `jq` installed for JSON parsing

## Troubleshooting

| Error | Fix |
|-------|-----|
| `glab: command not found` | Install via `brew install glab` or download from https://gitlab.com/gitlab-org/cli |
| `401 Unauthorized` | Check authentication with gitlab.evroc.dev (`glab auth login`) |
| `jq: command not found` | Install jq: `brew install jq` or `apt-get install jq` |
| Empty activity | No activity found for the specified date range |
| Rate limit errors | The tool handles pagination; wait a moment and retry |

## Notes

- **Read-only by design**: This skill never modifies GitLab state
- **Date handling**: Uses UTC timestamps for consistency
- **Pagination**: Automatically handles paginated API responses
- **Cross-project**: Searches activity across all projects you have access to
- **Time zones**: Assumes local timezone for date calculation, but GitLab timestamps are UTC
