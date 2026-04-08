# Git Worktree Scripts

Utility scripts to create, update, merge, and remove Git worktrees from a valid Git repository.

## Layout

- `bin/`: public commands (`git-create-worktree`, `git-update-worktree`, `git-merge-worktree`, `git-remove-worktree`, `git-worktree-sync`)
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
git-update-worktree feat/my-feature
git-update-worktree feat/my-feature --to refs/tags/v1.2.3
git-merge-worktree refs/remotes/origin/develop feat/my-feature
git-remove-worktree feat/my-feature
git-worktree-sync
```

## Advanced usage

Run core scripts from your repository directory:

```bash
/path/to/this-repo/lib/create-worktree feat/my-feature
/path/to/this-repo/lib/update-worktree feat/my-feature
/path/to/this-repo/lib/merge-worktree refs/remotes/origin/develop feat/my-feature
/path/to/this-repo/lib/remove-worktree feat/my-feature
/path/to/this-repo/lib/git-worktree-sync /path/to/worktree
```
