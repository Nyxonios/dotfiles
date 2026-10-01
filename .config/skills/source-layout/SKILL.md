---
name: source-layout
description: A description of how the evroc source code is organized on my machine
---

# Skill: source-layout

## Main placements of source code

The source code for all evroc components lives in git worktrees under
`~/development/worktrees/`. Each branch has its own dedicated worktree
directory. The main repositories are:

- **`monorepo-worktree`** — the primary monorepo containing Go, Python, and
  TypeScript/Svelte code. Branch worktrees are nested under this directory,
  e.g.:
  - `~/development/worktrees/monorepo-worktree/main` (the `main` branch)
  - `~/development/worktrees/monorepo-worktree/mseller/custom-data-pools`
  - `~/development/worktrees/monorepo-worktree/ahakansson/fix-graceful-shutdown`

  There is a `AGENTS.md` file in the monorepo root that gives context on the
  repository structure.

- **`cloud-config-worktree`** — deployment manifests (K8s, Terraform, etc.).
  Also uses worktrees per branch:
  - `~/development/worktrees/cloud-config-worktree/main`
  - `~/development/worktrees/cloud-config-worktree/mseller/local-csi-dns-fix`

  There is an `AGENTS.md` file in that repository as well.

Other worktree directories that may be relevant:
- `deployments-worktree`
- `giant-worktree`
- `metal-config-worktree`
- `object-storage-worktree`
- `oncall-worktree`
- `vendor-images-worktree`
- `work-scripts-worktree`

## Git worktrees

Both the monorepo and cloud-config repos are bare repositories with per-branch
worktrees. `git worktree list` from the bare root (e.g.
`~/development/worktrees/monorepo-worktree`) enumerates all active worktrees.
The user's current working branch is typically in a non-`main` worktree — do
not assume `main` is the active development tree.
