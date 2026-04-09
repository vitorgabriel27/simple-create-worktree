# Git Worktree Scripts

Utility scripts to create, update, merge, remove, and synchronize Git worktrees.

Primary documentation lives in `docs/`. This top-level copy is a short reference.

## Commands

- `git-create-worktree`: create a worktree from an existing branch or create a new branch and worktree
- `git-update-worktree`: fast-forward a branch safely or move a worktree to an explicit ref
- `git-merge-worktree`: merge a source ref into a destination branch checked out in a worktree
- `git-remove-worktree`: remove a worktree and delete its local branch
- `git-worktree-sync`: share env/runtime assets across compatible worktrees

## Examples

```bash
git-create-worktree feat/my-feature
git-create-worktree -b feat/new-feature develop
git-update-worktree feat/my-feature
git-update-worktree feat/my-feature --to refs/tags/v1.2.3
git-merge-worktree refs/remotes/origin/develop feat/my-feature
git-remove-worktree feat/my-feature
git-worktree-sync /path/to/worktree
```

## More detail

- `docs/HOW_TO_USE.txt`
- `docs/QUICK_START.txt`
- `docs/WORKTREE_SCRIPTS_README.md`
