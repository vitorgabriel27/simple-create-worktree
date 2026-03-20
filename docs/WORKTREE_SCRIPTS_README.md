# Git Worktree Scripts

Utility scripts to create and remove Git worktrees from a bare repository.

## Layout

- `bin/`: public commands (`git-create-worktree`, `git-remove-worktree`)
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
```

## Advanced usage

Run core scripts from your bare repo directory:

```bash
/path/to/this-repo/lib/create-worktree feat/my-feature
/path/to/this-repo/lib/remove-worktree feat/my-feature
```
