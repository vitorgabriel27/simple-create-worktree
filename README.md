# Git Worktree Helper Scripts

Small Bash toolkit to create, remove, update, and merge Git worktrees with a consistent folder layout.

## Repository structure

```text
.
├── bin/
│   ├── git-create-worktree
│   ├── git-remove-worktree
│   ├── git-update-worktree
│   └── git-merge-worktree
├── lib/
│   ├── create-worktree
│   ├── remove-worktree
│   ├── update-worktree
│   └── merge-worktree
├── docs/
│   ├── QUICK_START.txt
│   ├── HOW_TO_USE.txt
│   └── WORKTREE_SCRIPTS_README.md
├── create-worktree
├── remove-worktree
├── git-create-worktree
├── git-remove-worktree
├── update-worktree
├── git-update-worktree
├── merge-worktree
├── git-merge-worktree
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

If `~/.local/bin` is not in your `PATH`, add:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

```bash
git-create-worktree feat/my-feature
git-create-worktree -b feat/new-feature develop
git-remove-worktree feat/my-feature
git-update-worktree
git-update-worktree develop
git-merge-worktree feat/chart feat/dashboard
git-merge-worktree -l feat/chart feat/dashboard
```

## Tests

Run the main use-case test suite:

```bash
./tests/test-main-use-cases.sh
```

## Notes

- Wrapper commands auto-detect your Git repository context.
- Core commands (`./create-worktree`, `./remove-worktree`, `./update-worktree`) are intended to run from a valid Git repository directory.
