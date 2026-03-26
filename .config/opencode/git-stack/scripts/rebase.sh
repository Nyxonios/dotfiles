#!/bin/bash
#
# Git Stack - Rebase Command
# Rebases stack branches with state tracking and crash recovery
#

set -e

# Prevent interactive mode in git commands
# These must be set early so all git commands inherit them
export GIT_SEQUENCE_EDITOR=':'
export GIT_EDITOR=':'  
export GIT_MERGE_AUTOEDIT='no'
export EDITOR=':'
export VISUAL=':'

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"
source "${SCRIPT_DIR}/yaml-ops.sh"
source "${SCRIPT_DIR}/git-ops.sh"

# ============================================================================
# Parse Arguments
# ============================================================================

STACK_NAME=""
DRY_RUN=false
ABORT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --stack)
            STACK_NAME="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --abort)
            ABORT=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ============================================================================
# Helper Functions
# ============================================================================

# Estimate risk level based on commit count
estimate_risk() {
    local commits=$1
    if [[ ${commits} -lt 3 ]]; then
        echo "Low"
    elif [[ ${commits} -le 10 ]]; then
        echo "Medium"
    else
        echo "High"
    fi
}

# Pull latest changes from remote for a branch
# Usage: pull_branch "branch-name" "/path/to/worktree"
pull_branch() {
    local branch="$1"
    local worktree_path="$2"
    
    # Never pull protected branches (main, master) - let user handle these
    if [[ "${branch}" == "main" ]] || [[ "${branch}" == "master" ]]; then
        echo "   ${branch}: skipping protected branch"
        return 0
    fi
    
    # Validate worktree exists
    if [[ ! -d "${worktree_path}" ]]; then
        echo "   ${branch}: worktree directory not found"
        return 0
    fi
    
    # Check if there's a remote tracking branch
    local upstream
    upstream=$(cd "${worktree_path}" && git rev-parse --abbrev-ref "${branch}@{upstream}" 2>/dev/null) || true
    
    if [[ -z "${upstream}" ]]; then
        echo "   ${branch}: no upstream configured"
        return 0
    fi
    
    echo "   ${branch}: pulling from ${upstream}..."
    
    # Pull latest changes
    local pull_output pull_status
    pull_output=$(cd "${worktree_path}" && git pull --ff-only 2>&1) || true
    pull_status=$?
    
    if [[ ${pull_status} -ne 0 ]]; then
        # Check if it's just "Already up to date"
        if [[ "${pull_output}" == *"Already up to date"* ]] || [[ "${pull_output}" == *"Already up-to-date"* ]]; then
            echo "      ✓ up to date"
            return 0
        fi
        # Non-fast-forward pull - return error but don't fail, let user handle
        echo "      ⚠️ could not fast-forward: ${pull_output}"
        return 0
    fi
    
    if [[ "${pull_output}" == *"Already up to date"* ]] || [[ "${pull_output}" == *"Already up-to-date"* ]]; then
        echo "      ✓ up to date"
        return 0
    fi
    
    echo "      ✓ pulled latest changes"
    return 0
}

# Get state file path
get_state_file() {
    local repo="$1"
    local git_dir
    git_dir=$(cd "${repo}" && git rev-parse --git-dir 2>/dev/null)
    if [[ -z "${git_dir}" ]]; then
        echo "${repo}/.git/git-stack-rebase"
    else
        if [[ "${git_dir}" == "." ]]; then
            echo "${repo}/git-stack-rebase"
        elif [[ "${git_dir}" == /* ]]; then
            echo "${git_dir}/git-stack-rebase"
        else
            echo "${repo}/${git_dir}/git-stack-rebase"
        fi
    fi
}

# Read state from file
read_state() {
    local state_file="$1"
    if [[ -f "${state_file}" ]]; then
        cat "${state_file}"
    fi
}

# Write state to file
write_state() {
    local state_file="$1"
    local branch_name="$2"
    local original_hash="$3"
    local last_message="$4"
    local remaining="$5"
    
    cat > "${state_file}" << EOF
BranchName=${branch_name}
OriginalHash=${original_hash}
LastCommitMessage=${last_message}
RemainingCommits=${remaining}
EOF
}

# Clear state file
clear_state() {
    local state_file="$1"
    rm -f "${state_file}"
}

# Get branches in dependency order (parents before children)
get_ordered_branches() {
    local stack="$1"
    local ordered=()
    local processed=()
    
    # Get all branches
    local all_branches=()
    while IFS= read -r branch; do
        [[ -z "${branch}" ]] && continue
        all_branches+=("${branch}")
    done < <(get_branches "${stack}")
    
    # Process in order (roots first, then children)
    local changed=true
    while [[ "${changed}" == "true" ]]; do
        changed=false
        for branch in "${all_branches[@]}"; do
            # Skip if already processed
            local found=false
            for p in "${processed[@]}"; do
                if [[ "${p}" == "${branch}" ]]; then
                    found=true
                    break
                fi
            done
            [[ "${found}" == "true" ]] && continue
            
            # Get parent
            local parent
            parent=$(get_parent "${stack}" "${branch}")
            
            # If no parent or parent already processed, add to ordered
            if [[ -z "${parent}" ]] || [[ "${parent}" == "null" ]]; then
                ordered+=("${branch}")
                processed+=("${branch}")
                changed=true
            else
                # Check if parent is processed
                local parent_found=false
                for p in "${processed[@]}"; do
                    if [[ "${p}" == "${parent}" ]]; then
                        parent_found=true
                        break
                    fi
                done
                
                if [[ "${parent_found}" == "true" ]]; then
                    ordered+=("${branch}")
                    processed+=("${branch}")
                    changed=true
                fi
            fi
        done
    done
    
    # Output ordered branches
    for branch in "${ordered[@]}"; do
        echo "${branch}"
    done
}

# Push all rebased branches to remote
# Usage: push_all_rebased "stack-name" "branch1" "branch2" ...
push_all_rebased() {
    local stack="$1"
    shift
    local branches=("$@")
    local push_count=0
    local fail_count=0
    
    if [[ ${#branches[@]} -eq 0 ]]; then
        return 0
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "PUSHING BRANCHES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for branch in "${branches[@]}"; do
        local worktree
        worktree=$(get_branch_worktree "${stack}" "${branch}")
        
        if [[ -z "${worktree}" ]] || [[ ! -d "${worktree}" ]]; then
            echo "⚠️  Warning: Worktree not found for ${branch}, skipping push" >&2
            ((fail_count++))
            continue
        fi
        
        if push_branch "${branch}" "${worktree}"; then
            ((push_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    echo "Push complete: ${push_count} succeeded, ${fail_count} failed"
    
    return ${fail_count}
}

# ============================================================================
# Handle Abort
# ============================================================================

if [[ "${ABORT}" == "true" ]]; then
    ensure_yq
    yaml_exists
    
    # Auto-detect stack if not provided
    if [[ -z "${STACK_NAME}" ]]; then
        STACK_COUNT=$(get_stacks | wc -l)
        if [[ ${STACK_COUNT} -eq 1 ]]; then
            STACK_NAME=$(get_stacks | head -1)
        else
            echo "Error: Stack name is required (--stack) when multiple stacks exist" >&2
            exit 1
        fi
    fi
    
    if ! stack_exists "${STACK_NAME}"; then
        echo "Error: Stack '${STACK_NAME}' not found" >&2
        exit 1
    fi
    
    # Get repo path from stack and find state file
    STACK_DATA=$(get_stack "${STACK_NAME}")
    REPO=$(echo "${STACK_DATA}" | yq eval '.repo' -)
    STATE_FILE=$(get_state_file "${REPO}")
    
    if [[ ! -f "${STATE_FILE}" ]]; then
        echo "Error: No rebase in progress for stack '${STACK_NAME}'" >&2
        exit 1
    fi
    
    echo "Aborting git-stack rebase..."
    git rebase --abort 2>/dev/null || true
    clear_state "${STATE_FILE}"
    
    echo "✓ Rebase aborted"
    exit 0
fi

# ============================================================================
# Main Rebase Logic
# ============================================================================

ensure_yq
yaml_exists

# Auto-detect stack if not provided
if [[ -z "${STACK_NAME}" ]]; then
    # Count available stacks
    STACK_COUNT=$(get_stacks | wc -l)
    
    if [[ ${STACK_COUNT} -eq 0 ]]; then
        echo "Error: No stacks found. Create a stack first with 'git-stack add --name <stack-name>'" >&2
        exit 1
    elif [[ ${STACK_COUNT} -eq 1 ]]; then
        # Auto-select the only stack
        STACK_NAME=$(get_stacks | head -1)
        echo "Using only available stack: ${STACK_NAME}"
        echo ""
    else
        echo "Error: Stack name is required (--stack)" >&2
        echo "Available stacks:" >&2
        get_stacks | sed 's/^/  - /' >&2
        exit 1
    fi
fi

if ! stack_exists "${STACK_NAME}"; then
    echo "Error: Stack '${STACK_NAME}' not found" >&2
    exit 1
fi

# Get repo root
STACK_DATA=$(get_stack "${STACK_NAME}")
REPO=$(echo "${STACK_DATA}" | yq eval '.repo' -)

if [[ ! -d "${REPO}" ]]; then
    echo "Error: Repository not found: ${REPO}" >&2
    exit 1
fi

cd "${REPO}"

STATE_FILE=$(get_state_file "${REPO}")

# Check for existing git rebase
if check_rebase_progress; then
    echo "Error: Rebase already in progress. Resolve it first or run --abort" >&2
    exit 1
fi

# Check for existing state file
if [[ -f "${STATE_FILE}" ]]; then
    echo "Error: Rebase state file exists at: ${STATE_FILE}" >&2
    echo "Run --abort first" >&2
    exit 1
fi

# Get branches in order
echo "Analyzing stack: ${STACK_NAME}"
echo ""

ALL_BRANCHES=()
while IFS= read -r branch; do
    [[ -z "${branch}" ]] && continue
    ALL_BRANCHES+=("${branch}")
done <<< "$(get_ordered_branches "${STACK_NAME}")"

BRANCHES_TO_REBASE=()
TOTAL_COMMITS=0
PARENT_WAS_REBASED=false

for branch in "${ALL_BRANCHES[@]}"; do
    parent=$(get_parent "${STACK_NAME}" "${branch}")
    [[ -z "${parent}" ]] || [[ "${parent}" == "null" ]] && continue
    
    needs_rebase=false
    if ! is_ancestor "${parent}" "${branch}"; then
        needs_rebase=true
        commits=$(get_commit_count_between "${parent}" "${branch}")
        TOTAL_COMMITS=$((TOTAL_COMMITS + commits))
    else
        BEHIND=$(get_commits_behind "${parent}" "${branch}")
        if [[ "${BEHIND}" -gt 0 ]]; then
            needs_rebase=true
            TOTAL_COMMITS=$((TOTAL_COMMITS + BEHIND))
        fi
    fi
    
    if [[ "${needs_rebase}" == "true" ]] || [[ "${PARENT_WAS_REBASED}" == "true" ]]; then
        BRANCHES_TO_REBASE+=("${branch}")
        if [[ "${needs_rebase}" == "true" ]]; then
            PARENT_WAS_REBASED=true
        fi
    fi
done

# Check for uncommitted changes in branches that need rebase
echo "Checking working directories..."
DIRTY_BRANCHES=()
for branch in "${BRANCHES_TO_REBASE[@]}"; do
    worktree=$(get_branch_worktree "${STACK_NAME}" "${branch}")
    if [[ -n "${worktree}" ]] && [[ -d "${worktree}" ]]; then
        if ! (cd "${worktree}" && is_working_directory_clean); then
            DIRTY_BRANCHES+=("${branch}")
        fi
    fi
done

if [[ ${#DIRTY_BRANCHES[@]} -gt 0 ]]; then
    echo ""
    echo "❌ Error: Uncommitted changes found in the following branches:" >&2
    for branch in "${DIRTY_BRANCHES[@]}"; do
        worktree=$(get_branch_worktree "${STACK_NAME}" "${branch}")
        echo "   - ${branch}" >&2
        echo "     Location: ${worktree}" >&2
    done
    echo "" >&2
    echo "   Please commit or stash your changes before rebasing." >&2
    exit 1
fi

if [[ ${#BRANCHES_TO_REBASE[@]} -eq 0 ]]; then
    echo "All branches are up to date. Nothing to rebase."
    exit 0
fi

RISK=$(estimate_risk "${TOTAL_COMMITS}")

echo "Branches to rebase: ${#BRANCHES_TO_REBASE[@]}"
echo "Total commits: ${TOTAL_COMMITS}"
echo "Risk level: ${RISK}"
echo ""

# Dry run
if [[ "${DRY_RUN}" == "true" ]]; then
    echo "Dry run - would perform:"
    for branch in "${BRANCHES_TO_REBASE[@]}"; do
        parent=$(get_parent "${STACK_NAME}" "${branch}")
        echo "  ${branch}:"
        echo "    Fetch: origin/${parent}"
        echo "    Rebase: FETCH_HEAD"
        echo "    Push: to remote"
    done
    exit 0
fi

# Confirm
if [[ "${RISK}" == "High" ]]; then
    if ! confirm "High risk rebase with ${TOTAL_COMMITS} commits. Continue?"; then
        echo "Cancelled"
        exit 0
    fi
fi

# Perform rebase
echo ""
echo "Rebase plan:"
TOTAL_BRANCHES=${#BRANCHES_TO_REBASE[@]}
CURRENT_BRANCH=0

for branch in "${BRANCHES_TO_REBASE[@]}"; do
    CURRENT_BRANCH=$((CURRENT_BRANCH + 1))
    parent=$(get_parent "${STACK_NAME}" "${branch}")
    echo "  ${CURRENT_BRANCH}/${TOTAL_BRANCHES}: ${branch} → ${parent}"
done
echo ""

FIRST=true
REMAINING_LIST=""

for branch in "${BRANCHES_TO_REBASE[@]}"; do
    [[ "${FIRST}" == "true" ]] || REMAINING_LIST="${REMAINING_LIST},"
    REMAINING_LIST="${REMAINING_LIST}${branch}"
    FIRST=false
done

CURRENT_BRANCH=0
REBASED_COUNT=0
CASCADED_COUNT=0
FAILED_BRANCH=""

for branch in "${BRANCHES_TO_REBASE[@]}"; do
    CURRENT_BRANCH=$((CURRENT_BRANCH + 1))
    parent=$(get_parent "${STACK_NAME}" "${branch}")
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[${CURRENT_BRANCH}/${TOTAL_BRANCHES}] Rebasing ${branch}"
    echo "         Onto: ${parent}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    BRANCH_WORKTREE=$(get_branch_worktree "${STACK_NAME}" "${branch}")
    if [[ -z "${BRANCH_WORKTREE}" ]] || [[ ! -d "${BRANCH_WORKTREE}" ]]; then
        echo ""
        echo "❌ Error: Worktree not found for branch ${branch}" >&2
        FAILED_BRANCH="${branch}"
        break
    fi
    
    if check_rebase_progress "${BRANCH_WORKTREE}"; then
        echo ""
        echo "❌ Error: Rebase already in progress for ${branch}" >&2
        echo "         Worktree: ${BRANCH_WORKTREE}" >&2
        FAILED_BRANCH="${branch}"
        break
    fi
    
    ORIGINAL_HASH=$(cd "${BRANCH_WORKTREE}" && git rev-parse HEAD)
    REMAINING_LIST=$(echo "${REMAINING_LIST}" | sed "s|^${branch},*||; s|,${branch},|,|; s|,${branch}$||")
    write_state "${STATE_FILE}" "${branch}" "${ORIGINAL_HASH}" "Rebasing ${branch}" "${REMAINING_LIST}"
    
    # Ensure we're on the branch before rebasing
    if ! (cd "${BRANCH_WORKTREE}" && git checkout "${branch}" 2>/dev/null); then
        echo ""
        echo "❌ Error: Failed to checkout ${branch}" >&2
        echo "         Worktree: ${BRANCH_WORKTREE}" >&2
        FAILED_BRANCH="${branch}"
        break
    fi
    
    # Fetch parent's remote state before rebasing
    echo "   Fetching origin/${parent}..."
    if ! (cd "${BRANCH_WORKTREE}" && git fetch origin "${parent}" 2>&1); then
        echo ""
        echo "❌ Error: Failed to fetch origin/${parent}" >&2
        echo "         Branch: ${branch}" >&2
        FAILED_BRANCH="${branch}"
        break
    fi
    
    # Run rebase in non-interactive mode with GPG signing
    # Environment variables are set at script level (GIT_SEQUENCE_EDITOR, GIT_EDITOR, etc.)
    # --no-autosquash flag disables automatic interactive mode for fixup commits
    REBASE_OUTPUT=$(cd "${BRANCH_WORKTREE}" && git -c commit.gpgsign=true rebase --no-autosquash FETCH_HEAD </dev/null 2>&1)
    REBASE_STATUS=$?
    
    if [[ ${REBASE_STATUS} -ne 0 ]]; then
        echo ""
        echo "⚠️  Rebase failed with conflicts"
        echo ""
        echo "   Navigate to: ${BRANCH_WORKTREE}"
        echo "   Resolve conflicts manually"
        echo ""
        FAILED_BRANCH="${branch}"
        break
    fi
    
    # Verify rebase actually completed (not stuck in interactive mode)
    if check_rebase_progress "${BRANCH_WORKTREE}"; then
        echo ""
        echo "❌ Error: Rebase did not complete - appears to be stuck" >&2
        echo "         Branch: ${branch}" >&2
        echo "         Worktree: ${BRANCH_WORKTREE}" >&2
        echo "" >&2
        echo "   The rebase may be waiting for user input." >&2
        echo "   To abort and start over: git-stack rebase --abort" >&2
        FAILED_BRANCH="${branch}"
        break
    fi
    
    COMMITS_REBASED=$(echo "${REBASE_OUTPUT}" | grep -c "^Successfully rebased" || echo "0")
    
    echo ""
    echo "✅ Success"
    REBASED_COUNT=$((REBASED_COUNT + 1))
    
    if ! push_branch "${branch}" "${BRANCH_WORKTREE}"; then
        echo ""
        echo "❌ Error: Failed to push ${branch}" >&2
        FAILED_BRANCH="${branch}"
        break
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -n "${FAILED_BRANCH}" ]]; then
    echo ""
    echo "❌ Rebase failed at: ${FAILED_BRANCH}"
    echo "   ${REBASED_COUNT}/${TOTAL_BRANCHES} branches completed"
    echo ""
    exit 1
fi

clear_state "${STATE_FILE}"
update_last_rebased "${STACK_NAME}"
cleanup_backups

echo ""
echo "✅ Rebase completed successfully"
echo "   ${REBASED_COUNT} branch(es) rebased and pushed"
echo ""
