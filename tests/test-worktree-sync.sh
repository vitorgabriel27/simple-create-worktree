#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREATE_CMD="$ROOT_DIR/git-create-worktree"
SYNC_CMD="$ROOT_DIR/git-worktree-sync"

TEST_TMP_DIR=""

fail() {
    local name="$1"
    local details="${2:-}"
    echo "[FAIL] $name"
    if [[ -n "$details" ]]; then
        echo "       $details"
    fi
    exit 1
}

pass() {
    echo "[PASS] $1"
}

assert_symlink_target() {
    local name="$1"
    local path="$2"
    local expected="$3"

    [[ -L "$path" ]] || fail "$name" "Expected symlink: $path"
    local target
    target="$(readlink "$path")"
    [[ "$target" == "$expected" ]] || fail "$name" "Expected $path -> $expected, got $target"
}

assert_symlink_under() {
    local name="$1"
    local path="$2"
    local expected_prefix="$3"

    [[ -L "$path" ]] || fail "$name" "Expected symlink: $path"
    local target
    target="$(readlink -f "$path")"
    [[ "$target" == "$expected_prefix"* ]] || fail "$name" "Expected $path under $expected_prefix, got $target"
}

assert_exists() {
    local name="$1"
    local path="$2"
    [[ -e "$path" ]] || fail "$name" "Expected path to exist: $path"
}

setup_repo() {
    local test_dir="$1"
    local source_repo="$test_dir/source"
    local bare_repo="$test_dir/reservoir-analytics.git"

    git init -q "$source_repo"
    git -C "$source_repo" config user.name "test-user"
    git -C "$source_repo" config user.email "test-user@example.com"

    mkdir -p "$source_repo/backend" "$source_repo/frontend/reservoir" "$source_repo/frontend/reservoir_analytics" "$source_repo/.local-data"
    cat > "$source_repo/backend/pyproject.toml" <<'EOF'
[tool.poetry]
name = "test_backend"
version = "0.1.0"
description = ""
authors = ["test"]

[tool.poetry.dependencies]
python = "^3.11"
EOF
    cp "$source_repo/backend/pyproject.toml" "$source_repo/backend/poetry.lock"
    cat > "$source_repo/backend/.env.sample" <<'EOF'
API_PORT=8000
EOF
    cat > "$source_repo/backend/.env.keycloak" <<'EOF'
KEYCLOAK_ENABLED=false
EOF
    cat > "$source_repo/frontend/reservoir/package.json" <<'EOF'
{"name":"reservoir","version":"0.1.0"}
EOF
    cat > "$source_repo/frontend/reservoir/.env" <<'EOF'
REACT_APP_API_URL=http://localhost:8000
EOF
    cat > "$source_repo/frontend/reservoir_analytics/package.json" <<'EOF'
{"name":"reservoir_analytics","version":"0.1.0"}
EOF
    cat > "$source_repo/backend/db.json" <<'EOF'
{"_default":{}}
EOF
    cat > "$source_repo/.local-data/state.json" <<'EOF'
{"ok":true}
EOF
    cat > "$source_repo/.worktree-sync.sh" <<'EOF'
SYNC_ENV_MAPPINGS=(
  "backend/.env|backend.env|backend/.env.sample"
  "backend/.env.keycloak|backend.keycloak.env|"
  "frontend/reservoir/.env|frontend.reservoir.env|"
)

SYNC_SHARED_PATH_MAPPINGS=(
  ".local-data|runtime/.local-data|dir"
  "backend/db.json|runtime/backend/db.json|file"
)

SYNC_POETRY_PROJECTS=(
  "backend"
)

SYNC_NODE_PROJECTS=(
  "frontend/reservoir"
)
EOF

    git -C "$source_repo" add .
    git -C "$source_repo" checkout -qb develop
    git -C "$source_repo" commit -qm "init"
    git clone --bare -q "$source_repo" "$bare_repo"
    cp "$source_repo/.worktree-sync.sh" "$bare_repo/.worktree-sync.sh"
    git --git-dir="$bare_repo" worktree add -q "$bare_repo/develop" HEAD

    printf '%s\n' "$bare_repo"
}

main() {
    [[ -x "$CREATE_CMD" ]] || fail "create command executable" "$CREATE_CMD is not executable"
    [[ -x "$SYNC_CMD" ]] || fail "sync command executable" "$SYNC_CMD is not executable"

    TEST_TMP_DIR="$(mktemp -d)"
    trap '[[ -n "${TEST_TMP_DIR:-}" ]] && rm -rf "$TEST_TMP_DIR"' EXIT

    local bare_repo
    bare_repo="$(setup_repo "$TEST_TMP_DIR")"

    export WORKTREE_SYNC_SKIP_INSTALL=1
    (
        cd "$bare_repo/develop"
        "$CREATE_CMD" -b feat/shared-runtime develop >/dev/null
    )

    local worktree="$bare_repo/feat/shared-runtime"
    local shared_env_dir="$bare_repo/shared/env"
    local shared_runtime_dir="$bare_repo/shared/runtime"
    local shared_venv_dir
    shared_venv_dir="$(find "$bare_repo/shared/venv" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

    assert_exists "shared env dir created" "$shared_env_dir"
    assert_exists "shared runtime dir created" "$shared_runtime_dir"
    assert_exists "shared venv created" "$shared_venv_dir"
    assert_symlink_under "backend env linked" "$worktree/backend/.env" "$shared_env_dir"
    assert_symlink_under "backend keycloak env linked" "$worktree/backend/.env.keycloak" "$shared_env_dir"
    assert_symlink_under "frontend env linked" "$worktree/frontend/reservoir/.env" "$shared_env_dir"
    assert_symlink_under "runtime dir linked" "$worktree/.local-data" "$shared_runtime_dir"
    assert_symlink_under "runtime db linked" "$worktree/backend/db.json" "$shared_runtime_dir"
    assert_symlink_under "backend venv linked" "$worktree/backend/.venv" "$shared_venv_dir"

    "$SYNC_CMD" "$worktree" >/dev/null

    assert_symlink_under "backend env still linked after rerun" "$worktree/backend/.env" "$shared_env_dir"
    assert_symlink_under "runtime dir still linked after rerun" "$worktree/.local-data" "$shared_runtime_dir"
    assert_symlink_under "backend venv still linked after rerun" "$worktree/backend/.venv" "$shared_venv_dir"

    pass "git-worktree-sync reuses shared env and backend venv idempotently"
}

main "$@"
