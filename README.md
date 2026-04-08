# Git Worktree Helper Scripts

Small Bash toolkit to create, update, merge, remove, and synchronize Git worktrees with a consistent folder layout.

## Repository structure

```text
.
├── bin/
│   ├── git-create-worktree
│   ├── git-update-worktree
│   ├── git-merge-worktree
│   ├── git-remove-worktree
│   └── git-worktree-sync
├── lib/
│   ├── create-worktree
│   ├── update-worktree
│   ├── merge-worktree
│   ├── remove-worktree
│   ├── git-worktree-sync
│   └── git-worktree-common
├── docs/
│   ├── QUICK_START.txt
│   ├── HOW_TO_USE.txt
│   └── WORKTREE_SCRIPTS_README.md
├── create-worktree
├── git-update-worktree
├── git-merge-worktree
├── remove-worktree
├── git-create-worktree
├── git-remove-worktree
├── git-worktree-sync
└── install.sh
```

`bin/` contains public CLI entrypoints.

`lib/` contains core script logic.

Root-level script names are compatibility launchers.

## Install

```bash
./install.sh
```

This creates symlinks in `~/.local/bin`:

- `git-create-worktree`
- `git-remove-worktree`
- `git-update-worktree`
- `git-merge-worktree`
- `git-worktree-sync`

If `~/.local/bin` is not in your `PATH`, add:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

```bash
git-create-worktree feat/my-feature
git-create-worktree -b feat/new-feature develop
git-update-worktree feat/my-feature
git-update-worktree feat/my-feature --to refs/tags/v1.2.3
git-merge-worktree refs/remotes/origin/develop feat/my-feature
git-remove-worktree feat/my-feature
git-worktree-sync
```

## Tests

Run the main use-case test suite:

```bash
./tests/test-main-use-cases.sh
```

## Notes

- Wrapper commands auto-detect your Git repository context.
- Core commands (`./create-worktree`, `./remove-worktree`, `./update-worktree`, `./merge-worktree`) are intended to run from a valid Git repository directory.
- `git-update-worktree` and `git-merge-worktree` manage Git version state only.
- `git-worktree-sync` standardizes shared env files, backend virtualenvs, and pnpm store usage for reservoir-analytics-style repositories.
