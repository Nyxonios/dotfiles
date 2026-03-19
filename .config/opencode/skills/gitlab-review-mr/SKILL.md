# Skill: gitlab-review-mr

# GitLab MR Review Skill

## Overview

This skill performs comprehensive code reviews of GitLab Merge Requests. It:

1. Identifies the MR (from current branch context or MR ID provided)
2. Fetches MR metadata, description, and diff
3. Retrieves existing review comments and discussions
4. Analyzes the code changes for:
   - Code quality and best practices
   - Potential bugs and issues
   - Security concerns
   - Performance implications
   - Maintainability and readability
   - Test coverage
   - Documentation completeness
5. Presents a structured review report with actionable feedback
6. Provides severity ratings (Critical/High/Medium/Low/Nit)

**Key principle**: This skill is read-only. It never posts, edits, or modifies the MR. All output goes to the console where the prompt was received.

## Prerequisites

- `glab` CLI installed (`brew install glab` or https://gitlab.com/gitlab-org/cli)
- Authenticated with `gitlab.evroc.dev` (run `glab auth login` and select `gitlab.evroc.dev` when prompted)
- Must be run from inside a git repository with a GitLab remote on gitlab.evroc.dev, OR an MR ID must be provided
- Repository must have an open MR for the current branch (if using auto-detection)

## Step-by-Step Workflow

### Step 1: Identify the MR

First, determine which MR to review:

```bash
# Current branch name
git rev-parse --abbrev-ref HEAD

# Check if there's an open MR for this branch
GLAB_HOST=gitlab.evroc.dev glab mr view --json 2>/dev/null | head -1
```

**Auto-detection logic**:
- If already on a feature branch (not `main`/`master`), try to find the MR for current branch
- If on `main`/`master`, or if auto-detection fails, ask the user:
  - "Which MR would you like to review? Provide MR number or branch name:"

Store the MR ID for subsequent queries.

### Step 2: Fetch MR Metadata and Description

Retrieve comprehensive MR information:

```bash
# Fetch MR details including description
GLAB_HOST=gitlab.evroc.dev glab mr view <MR_ID> --json
```

**Extract key information**:
- Title and description (understanding the "why" behind changes)
- Source and target branches
- Author and creation date
- MR state (open/merged/closed/draft)
- Commit count and list
- Labels and assignees
- Related issues or MRs mentioned

### Step 3: Fetch the MR Diff

Retrieve the complete code diff:

```bash
# Fetch the diff for the MR
GLAB_HOST=gitlab.evroc.dev glab mr diff <MR_ID>

# Also get list of changed files
GLAB_HOST=gitlab.evroc.dev glab mr view <MR_ID> --json | jq -r '.diff_stats[] | "\(.path): +\(.additions)/-\(.deletions)"'
```

**Analyze diff characteristics**:
- Total files changed
- Lines added/removed per file
- File types involved
- Binary vs text changes

### Step 4: Fetch Existing Review Comments

Retrieve any existing discussions and comments:

```bash
# Fetch all discussions
GLAB_HOST=gitlab.evroc.dev glab mr note list <MR_ID> -F json --output json

# Fetch general MR notes
GLAB_HOST=gitlab.evroc.dev glab mr view <MR_ID> --json | jq '.description'
```

**Note**: Filter out resolved comments by default - focus on open issues. Only show resolved comments if user explicitly asks.

### Step 5: Read Changed Files

For thorough review, read the full content of changed files:

```bash
# Get list of changed files
CHANGED_FILES=$(GLAB_HOST=gitlab.evroc.dev glab mr view <MR_ID> --json | jq -r '.diff_stats[].path')

# Read each file at HEAD (current state)
for file in $CHANGED_FILES; do
  if [ -f "$file" ]; then
    echo "=== $file ==="
    cat "$file"
  fi
done
```

**Context gathering**:
- Read imports and dependencies at the top of files
- Understand the overall structure and patterns
- Check for related files that might need attention

### Step 6: Perform Code Review Analysis

Analyze the MR comprehensively across multiple dimensions:

#### 6.1 Code Quality Review
- **Code style consistency**: Does it follow project conventions?
- **Naming clarity**: Are variables, functions, and classes well-named?
- **Function complexity**: Are functions/methods too long or doing too much?
- **Duplication**: Is there repeated code that should be extracted?
- **Comments**: Are comments helpful, accurate, and necessary?

#### 6.2 Bug and Logic Review
- **Logic errors**: Conditions, loops, edge cases
- **Null/undefined safety**: Proper handling of nullable values
- **Error handling**: Try-catch, error propagation, user feedback
- **State management**: Proper initialization, updates, cleanup
- **Race conditions**: Async/await usage, concurrent access

#### 6.3 Security Review
- **Input validation**: Sanitization of user inputs
- **Authentication/authorization**: Proper access controls
- **Sensitive data**: No secrets, tokens, or PII in code
- **Injection risks**: SQL, command, XSS vulnerabilities
- **Dependencies**: Security of imported packages

#### 6.4 Performance Review
- **Algorithmic complexity**: Big O analysis where relevant
- **Resource usage**: Memory leaks, excessive allocations
- **Database queries**: N+1 problems, missing indexes
- **Caching**: Appropriate use of caching strategies
- **Unnecessary work**: Redundant calculations or API calls

#### 6.5 Architecture and Design
- **Separation of concerns**: Single responsibility principle
- **Coupling and cohesion**: Module dependencies
- **API design**: Interface consistency and usability
- **Extensibility**: Easy to modify and extend
- **Testability**: Code structure supports testing

#### 6.6 Testing Review
- **Test coverage**: Are changes covered by tests?
- **Test quality**: Meaningful assertions, not just coverage
- **Edge cases**: Boundary conditions tested
- **Test readability**: Clear arrange-act-assert structure
- **Mocking**: Appropriate use of mocks/stubs

#### 6.7 Documentation Review
- **Code comments**: Explain why, not just what
- **README updates**: If behavior changes
- **API documentation**: Public interfaces documented
- **Changelog**: User-facing changes recorded
- **Commit messages**: Clear and descriptive

### Step 7: Generate Structured Review Report

Present findings in a clear, actionable format:

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  CODE REVIEW REPORT                                                          ║
║  <MR Title> (!<MR_ID>)                                                       ║
║  Branch: <source_branch> → <target_branch>                                   ║
║  Author: @<author>                                                           ║
╚══════════════════════════════════════════════════════════════════════════════╝

📋 MR SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Description: <brief summary of what the MR does>

Files Changed: <N> | +<additions>/-<deletions>
├─ src/...
├─ tests/...
└─ docs/...

Commits: <N> | <list of commit messages>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 CRITICAL ISSUES (Must Fix)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[CRITICAL-1] Security: SQL Injection Risk
  File: src/api/users.ts
  Line: 45
  
  The user input is directly interpolated into the SQL query without
  parameterization. This is a critical security vulnerability.
  
  Current:
    const query = `SELECT * FROM users WHERE name = '${userName}'`;
  
  Recommended:
    const query = 'SELECT * FROM users WHERE name = ?';
    db.query(query, [userName]);

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟠 HIGH PRIORITY (Strongly Recommended)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[HIGH-1] Bug: Missing Null Check
  File: src/utils/parser.ts
  Line: 78
  
  The function assumes data is always present, but the API can return null.
  This will cause runtime errors.
  
  Suggested fix:
    if (!data) {
      throw new ValidationError('Invalid response from API');
    }

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟡 MEDIUM PRIORITY (Consider Addressing)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[MEDIUM-1] Performance: N+1 Query Pattern
  File: src/services/orders.ts
  Lines: 34-42
  
  The loop makes individual database calls. Consider using a single query
  with JOIN or IN clause.
  
  Suggested: Batch fetch all related data in one query

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 LOW PRIORITY (Nice to Have)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[LOW-1] Code Style: Inconsistent Naming
  File: src/models/user.ts
  Line: 23
  
  Variable uses camelCase while the rest of the file uses snake_case.
  Consider renaming for consistency.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✏️  NITS (Minor Suggestions)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[NIT-1] Typo in comment
  File: src/config/app.ts
  Line: 12
  "recieve" should be "receive"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 EXISTING REVIEW COMMENTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Unresolved Comments: <N>
  ├─ @reviewer1 on src/api/users.ts:45 (Unresolved)
  │   "Consider using a constant here..."
  └─ @reviewer2 on src/auth/middleware.ts:67 (Unresolved)
      "This function is getting complex..."

Resolved Comments: <N> (filtered out by default)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ POSITIVE FEEDBACK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- Good use of early returns in src/utils/helpers.ts
- Well-structured test cases with clear descriptions
- Nice documentation update explaining the new feature
- Clean separation between business logic and API layer

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 RECOMMENDATIONS SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Must Fix:      <N> critical issues
Should Fix:    <N> high priority items
Consider:      <N> medium priority items
Nice to Have:  <N> low priority items
Nits:          <N> minor suggestions

Overall Assessment: <APPROVE/APPROVE_WITH_COMMENTS/NEEDS_WORK>

Next Steps:
1. Address critical and high priority issues
2. Review existing unresolved comments
3. Consider running the test suite to ensure no regressions
4. Request re-review after fixes

⚠️  Note: This is an automated review. Please use your judgment and consider
    the context of the changes. Not all suggestions may be applicable.
```

### Step 8: Severity Classification Guidelines

Classify each finding with appropriate severity:

**🔴 CRITICAL**
- Security vulnerabilities (injection, XSS, auth bypass)
- Data loss or corruption risks
- Production crashes or downtime
- Legal or compliance violations

**🟠 HIGH**
- Likely bugs that will cause errors
- Significant performance degradation
- Missing critical error handling
- Breaking API changes without versioning

**🟡 MEDIUM**
- Code that may cause issues in edge cases
- Maintainability concerns
- Missing test coverage for complex logic
- Inefficient algorithms

**🟢 LOW**
- Style inconsistencies
- Missing documentation for internal code
- Minor refactoring opportunities
- Performance issues unlikely to matter

**✏️ NIT**
- Typos in comments
- Whitespace/formatting issues
- Variable naming preferences
- Optional style improvements

### Step 9: Context-Aware Review Guidelines

**Read full files, not just diffs**:
- A line change might affect behavior elsewhere in the file
- Check imports and dependencies for context
- Understand the overall architecture before critiquing

**Consider the MR description**:
- The "why" matters more than the "what"
- Emergency fixes might justify shortcuts
- Feature flags might explain temporary code

**Balance thoroughness with practicality**:
- Not every MR needs the same depth of review
- Small bug fixes don't need architecture critique
- New features deserve more scrutiny than refactors

**Acknowledge good practices**:
- Point out what was done well
- Positive reinforcement for tests, docs, clean code
- Constructive tone throughout

## Edge Cases

- **No open MR for current branch**: Inform user and ask for MR number
- **MR is a draft**: Note this in review (may be intentionally incomplete)
- **Very large MR (>50 files)**: Provide high-level summary first, offer detailed review of specific files on request
- **Binary files only**: Review description and approach, skip code analysis
- **Generated code**: Acknowledge if clearly generated (e.g., protobuf, graphql), focus on generation config
- **All files are documentation**: Adjust review to focus on clarity and accuracy
- **Existing many unresolved comments**: Suggest addressing those before adding more review items
- **MR already merged/closed**: Note the status and suggest the review is for learning purposes

## Troubleshooting

| Error | Fix |
|-------|-----|
| `glab: command not found` | Install via `brew install glab` or download from https://gitlab.com/gitlab-org/cli |
| `401 Unauthorized` | Check authentication with gitlab.evroc.dev (`glab auth login`) |
| `404 Not Found` | MR may not exist; verify MR number |
| `no merge request found for branch` | Current branch has no open MR; provide MR number |
| Empty diff | MR may have no changes or be already merged |
| Large binary files | Skip content analysis, note in review |

## Notes

- **Read-only by design**: Never posts comments or modifies the MR
- **Context matters**: Always consider the MR description and existing comments
- **Full file review**: Read entire changed files, not just the diff context
- **Constructive tone**: Balance critical feedback with positive observations
- **Actionable items**: Every finding should have a clear path to resolution
- **Scope awareness**: Tailor review depth to MR size and complexity
- **Human judgment**: User should apply their own context and expertise

## Example Usage

**User prompt**: "Review my MR"
```
# Auto-detects MR from current branch, performs comprehensive review
```

**User prompt**: "Review MR 123"
```
# Reviews MR !123 specifically
```

**User prompt**: "Quick review of my changes"
```
# High-level review focusing on critical/high issues only
```

**User prompt**: "Deep review of MR 456"
```
# Thorough review with all severity levels, architecture analysis
```

**User prompt**: "Review focusing on security"
```
# Prioritizes security analysis over other aspects
```
