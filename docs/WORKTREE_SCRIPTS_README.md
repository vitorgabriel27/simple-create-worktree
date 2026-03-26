# Git Worktree Scripts

Utility scripts to create, remove, update, and merge Git worktrees from a valid Git repository.

## Layout

- `bin/`: public commands (`git-create-worktree`, `git-remove-worktree`, `git-update-worktree`, `git-merge-worktree`)
- `lib/`: core implementation scripts
- `docs/`: usage guides

## Install

```bash
./install.sh
```

This links commands into `~/.local/bin`.

If needed, add to your shell profile:

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

## Advanced usage

Run core scripts from your repository directory:

```bash
/path/to/this-repo/lib/create-worktree feat/my-feature
/path/to/this-repo/lib/remove-worktree feat/my-feature
/path/to/this-repo/lib/update-worktree develop
/path/to/this-repo/lib/merge-worktree feat/chart feat/dashboard
```
