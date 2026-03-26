---
name: git-stack
description: Git branch stack management - manage stacked branches with rebase, status, and validation commands
---

# Skill: git-stack

## Overview

This skill provides git branch stack management through the `git-stack` CLI tool. It helps you organize, track, and rebase dependent branches in a stack-based workflow.

**Key capabilities:**
- Add branches to named stacks with parent-child relationships
- List all stacks and view branch hierarchies
- Check rebase status across stack branches
- Perform sequential rebasing of dependent branches
- Remove stacks or individual branches from tracking
- Validate stack configuration integrity

## Prerequisites

- The `git-stack` binary must be available at `~/dotfiles/.config/opencode/git-stack/git-stack`
- Must be run from within a git repository

## Commands

### Add a branch to a stack

Add the current branch (or a specified branch) to a stack. Creates the stack if it doesn't exist.

```bash
~/dotfiles/.config/opencode/git-stack/git-stack add --name <stack-name> [--parent <parent-branch>] [--branch <branch-name>]
```

**Parameters:**
- `--name, -n` (required): Name of the stack
- `--parent, -p` (optional): Parent branch in the stack
- `--branch, -b` (optional): Branch to add (defaults to current branch)

**Examples:**
```bash
# Add current branch to a new or existing stack
~/dotfiles/.config/opencode/git-stack/git-stack add --name my-feature

# Add a specific branch with a parent
~/dotfiles/.config/opencode/git-stack/git-stack add --name my-feature --parent main --branch feature-auth

# Add current branch with parent
~/dotfiles/.config/opencode/git-stack/git-stack add --name my-feature --parent feature-a
```

### List stacks

List all stacks or show detailed tree view of a specific stack.

```bash
~/dotfiles/.config/opencode/git-stack/git-stack list [--stack <stack-name>]
```

**Parameters:**
- `--stack, -s` (optional): Specific stack to display in detail

**Examples:**
```bash
# List all stacks with branch counts
~/dotfiles/.config/opencode/git-stack/git-stack list

# Show detailed tree view of a specific stack
~/dotfiles/.config/opencode/git-stack/git-stack list --stack my-feature
```

### Check status

Check rebase status of stacks to see which branches need rebasing.

```bash
~/dotfiles/.config/opencode/git-stack/git-stack status [--stack <stack-name>] [--verbose]
```

**Parameters:**
- `--stack, -s` (optional): Specific stack to check
- `--verbose, -v` (optional): Show verbose output with commit details

**Examples:**
```bash
# Check all stacks
~/dotfiles/.config/opencode/git-stack/git-stack status

# Check specific stack with details
~/dotfiles/.config/opencode/git-stack/git-stack status --stack my-feature --verbose
```

### Rebase a stack

Rebase stack branches onto their parent branches.

For each branch in the stack, git-stack will:
1. Fetch the parent's latest state from origin
2. Rebase the branch onto FETCH_HEAD (parent's remote state)
3. Push the rebased branch to remote with force-with-lease

```bash
~/dotfiles/.config/opencode/git-stack/git-stack rebase [--stack <stack-name>] [--dry-run] [--abort]
```

**Parameters:**
- `--stack` (optional): Name of the stack to rebase (auto-detected if only one stack exists)
- `--dry-run` (optional): Preview changes without executing
- `--abort` (optional): Abort the current rebase operation

**Examples:**
```bash
# Preview rebase operations
~/dotfiles/.config/opencode/git-stack/git-stack rebase --stack my-feature --dry-run

# Execute rebase (with explicit stack name)
~/dotfiles/.config/opencode/git-stack/git-stack rebase --stack my-feature

# Execute rebase (auto-detected when only one stack exists)
~/dotfiles/.config/opencode/git-stack/git-stack rebase

# Abort an in-progress rebase
~/dotfiles/.config/opencode/git-stack/git-stack rebase --abort
```

### Remove a stack or branch

Remove a stack or individual branch from tracking.

```bash
~/dotfiles/.config/opencode/git-stack/git-stack remove --stack <stack-name> [--branch <branch-name>]
```

**Parameters:**
- `--stack, -s` (required): Name of the stack
- `--branch, -b` (optional): Specific branch to remove (removes entire stack if not provided)

**Examples:**
```bash
# Remove entire stack (prompts for confirmation)
~/dotfiles/.config/opencode/git-stack/git-stack remove --stack my-feature

# Remove a specific branch
~/dotfiles/.config/opencode/git-stack/git-stack remove --stack my-feature --branch feature-b
```

**Note:** This only removes branches from tracking. Git branches are NOT deleted.

### Validate stacks

Validate stack configuration and report issues.

```bash
~/dotfiles/.config/opencode/git-stack/git-stack validate [--stack <stack-name>]
```

**Parameters:**
- `--stack, -s` (optional): Specific stack to validate

**Examples:**
```bash
# Validate all stacks
~/dotfiles/.config/opencode/git-stack/git-stack validate

# Validate specific stack
~/dotfiles/.config/opencode/git-stack/git-stack validate --stack my-feature
```

**Checks performed:**
- All branches exist in git
- All parent references are valid
- No circular dependencies
- Worktree paths exist

### Show help

Display help information for git-stack commands.

```bash
~/dotfiles/.config/opencode/git-stack/git-stack help [command]
```

**Examples:**
```bash
# Show general help
~/dotfiles/.config/opencode/git-stack/git-stack help

# Show help for a specific command
~/dotfiles/.config/opencode/git-stack/git-stack help rebase
```

## Workflow Example

A typical workflow using git-stack:

```bash
# 1. Create and add the first branch
cd /path/to/your/repo
git checkout -b feature-login
~/dotfiles/.config/opencode/git-stack/git-stack add --name auth-stack

# 2. Create dependent branch
git checkout -b feature-oauth
~/dotfiles/.config/opencode/git-stack/git-stack add --name auth-stack --parent feature-login

# 3. Create another dependent branch
git checkout -b feature-sso
~/dotfiles/.config/opencode/git-stack/git-stack add --name auth-stack --parent feature-oauth

# 4. View the stack structure
~/dotfiles/.config/opencode/git-stack/git-stack list --stack auth-stack

# 5. Check if rebase is needed after main updates
~/dotfiles/.config/opencode/git-stack/git-stack status --stack auth-stack

# 6. Preview the rebase
~/dotfiles/.config/opencode/git-stack/git-stack rebase --stack auth-stack --dry-run

# 7. Execute the rebase
~/dotfiles/.config/opencode/git-stack/git-stack rebase --stack auth-stack

# 8. Validate everything is correct
~/dotfiles/.config/opencode/git-stack/git-stack validate
```

## Configuration

Stack configurations are stored at `~/.config/git-stacks.yaml`.

## Troubleshooting

| Error | Solution |
|-------|----------|
| `Error: Not a git repository` | Run commands from within a git repository |
| `Error: Branch already exists in stack` | Use `list` to see tracked branches, or remove first |
| `Error: Parent branch does not exist` | Add the parent branch first |
| Rebase conflicts | Navigate to worktree, resolve conflicts, then run `git rebase --continue` manually |

## Notes

- This skill wraps the git-stack CLI tool
- All commands require the full path to the binary
- Stack data persists in `~/.config/git-stacks.yaml`
