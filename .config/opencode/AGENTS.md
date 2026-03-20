# Global Agent Context

This file provides global context about the user's work environment that applies across all projects.

## Git Worktrees

The user works with git worktrees located at `/home/mseller/development/worktrees/`. Each worktree contains a 'main' folder with the main branch and user-specific folders for feature branches.

### Repositories

| Repository | Path | Purpose | Tech Stack |
|------------|------|---------|------------|
| **monorepo** | `/home/mseller/development/worktrees/monorepo-worktree` | Primary monorepo containing all code and documentation | Bazel, Go, Python, Docker |
| **cloud-config** | `/home/mseller/development/worktrees/cloud-config-worktree` | Kubernetes infrastructure configuration management | Kustomize, SOPS, Vault, dev CLI, Nix/devenv |
| **giant** | `/home/mseller/development/worktrees/giant-worktree` | Team platform service | Rust, Cargo |
| **metal-config** | `/home/mseller/development/worktrees/metal-config-worktree` | Bare-metal infrastructure configuration | Ansible, Terraform |

All repositories are hosted on GitLab at `gitlab.evroc.dev`.

### Worktree Structure

Each repository worktree follows this pattern:
```
/home/mseller/development/worktrees/<repo>-worktree/
├── main/                    # Main branch checkout
├── mseller/                 # User's branch worktrees
├── [other users]/           # Other team members' worktrees
└── .git/                    # Shared git repository metadata
```

### User's Worktrees

The user often works directly in branch worktrees such as:
- `/home/mseller/development/worktrees/monorepo-worktree/mseller/<branch-name>`
- `/home/mseller/development/worktrees/cloud-config-worktree/mseller/<branch-name>`
- `/home/mseller/development/worktrees/metal-config-worktree/mseller/<branch-name>`

### Search Guidance

**IMPORTANT:** When searching for information about these repositories (unless otherwise specified), look in the main branch directories:

- `/home/mseller/development/worktrees/monorepo-worktree/main/`
- `/home/mseller/development/worktrees/cloud-config-worktree/main/`
- `/home/mseller/development/worktrees/giant-worktree/main/`
- `/home/mseller/development/worktrees/metal-config-worktree/main/`

Branch worktrees may contain incomplete or work-in-progress code. Always reference the main branch for authoritative information about the codebase structure, patterns, and established practices.
