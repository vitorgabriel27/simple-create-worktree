#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREATE_CMD="$ROOT_DIR/git-create-worktree"
UPDATE_CMD="$ROOT_DIR/git-update-worktree"
MERGE_CMD="$ROOT_DIR/git-merge-worktree"
SYNC_CMD="$ROOT_DIR/git-worktree-sync"
REMOVE_CMD="$ROOT_DIR/git-remove-worktree"

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

assert_equals() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    [[ "$expected" == "$actual" ]] || fail "$name" "Expected '$expected', got '$actual'"
}

assert_contains() {
    local name="$1"
    local haystack="$2"
    local needle="$3"
    [[ "$haystack" == *"$needle"* ]] || fail "$name" "Expected output to contain '$needle'"
}

setup_repo() {
    local test_dir="$1"
    local upstream="$test_dir/upstream.git"
    local seed="$test_dir/seed"
    local bare_repo="$test_dir/project.git"

    git init --bare -q "$upstream"
    git clone -q "$upstream" "$seed" >/dev/null 2>&1
    git -C "$seed" config user.name "test-user"
    git -C "$seed" config user.email "test-user@example.com"
    git -C "$seed" checkout -q -b develop
    mkdir -p "$seed/backend" "$seed/frontend/app"
    cat > "$seed/backend/pyproject.toml" <<'EOF'
[tool.poetry]
name = "test_backend"
version = "0.1.0"
description = ""
authors = ["test"]

[tool.poetry.dependencies]
python = "^3.11"
EOF
    cp "$seed/backend/pyproject.toml" "$seed/backend/poetry.lock"
    cat > "$seed/backend/.env.sample" <<'EOF'
API_PORT=8000
EOF
    cat > "$seed/frontend/app/package.json" <<'EOF'
{"name":"app","version":"0.1.0"}
EOF
    cat > "$seed/.worktree-sync.sh" <<'EOF'
SYNC_ENV_MAPPINGS=("backend/.env|backend.env|backend/.env.sample")
SYNC_POETRY_PROJECTS=("backend")
SYNC_NODE_PROJECTS=("frontend/app")
EOF
    git -C "$seed" add .
    git -C "$seed" commit -qm "seed develop"
    git -C "$seed" push -q -u origin develop

    git clone --bare -q "$upstream" "$bare_repo"
    cp "$seed/.worktree-sync.sh" "$bare_repo/.worktree-sync.sh"
    git --git-dir="$bare_repo" fetch -q origin "+refs/heads/*:refs/remotes/origin/*"
    git --git-dir="$bare_repo" worktree add -q "$bare_repo/develop" develop

    printf '%s\n' "$bare_repo"
}

make_remote_commit() {
    local upstream="$1"
    local branch="$2"
    local message="$3"
    local writer="$TEST_TMP_DIR/writer-${branch//\//-}-$(date +%s%N)"

    git clone -q "$upstream" "$writer" >/dev/null 2>&1
    git -C "$writer" config user.name "test-user"
    git -C "$writer" config user.email "test-user@example.com"
    git -C "$writer" checkout -q "$branch"
    echo "$message" >> "$writer/changes.txt"
    git -C "$writer" add changes.txt
    git -C "$writer" commit -qm "$message"
    git -C "$writer" push -q origin "$branch"
}

run_update_current_worktree_test() {
    local bare_repo="$1"
    local upstream="$2"
    local worktree="$bare_repo/develop"
    local before_sha
    local after_sha
    local remote_sha

    before_sha="$(git -C "$worktree" rev-parse HEAD)"
    make_remote_commit "$upstream" develop "advance develop once"
    (cd "$worktree" && "$UPDATE_CMD" >/dev/null)
    after_sha="$(git -C "$worktree" rev-parse HEAD)"
    remote_sha="$(git --git-dir="$bare_repo" rev-parse refs/remotes/origin/develop)"

    [[ "$before_sha" != "$after_sha" ]] || fail "update current worktree moves branch forward"
    assert_equals "update current worktree matches remote" "$remote_sha" "$after_sha"
    pass "update current worktree via fast-forward"
}

run_update_explicit_branch_test() {
    local bare_repo="$1"
    local upstream="$2"

    (cd "$bare_repo/develop" && "$CREATE_CMD" -b feat/versioned develop >/dev/null)
    local worktree="$bare_repo/feat/versioned"
    git -C "$worktree" push -q -u origin feat/versioned

    local before_sha
    local after_sha
    local remote_sha
    before_sha="$(git --git-dir="$bare_repo" rev-parse feat/versioned)"
    make_remote_commit "$upstream" feat/versioned "advance feature remotely"
    (cd "$bare_repo" && "$UPDATE_CMD" feat/versioned >/dev/null)
    after_sha="$(git --git-dir="$bare_repo" rev-parse feat/versioned)"
    remote_sha="$(git --git-dir="$bare_repo" rev-parse refs/remotes/origin/feat/versioned)"

    [[ "$before_sha" != "$after_sha" ]] || fail "update explicit branch moves branch forward"
    assert_equals "update explicit branch matches remote" "$remote_sha" "$after_sha"
    pass "update explicit branch with active worktree"
}

run_update_branch_without_worktree_test() {
    local bare_repo="$1"
    local upstream="$2"
    local branch="feat/no-worktree"

    git --git-dir="$bare_repo" branch "$branch" refs/remotes/origin/develop
    git --git-dir="$bare_repo" push -q origin "$branch"

    local before_sha
    local after_sha
    local remote_sha
    before_sha="$(git --git-dir="$bare_repo" rev-parse "$branch")"
    make_remote_commit "$upstream" "$branch" "advance branch without worktree"
    (cd "$bare_repo" && "$UPDATE_CMD" "$branch" >/dev/null)
    after_sha="$(git --git-dir="$bare_repo" rev-parse "$branch")"
    remote_sha="$(git --git-dir="$bare_repo" rev-parse "refs/remotes/origin/$branch")"

    [[ "$before_sha" != "$after_sha" ]] || fail "update branch without worktree moves ref forward"
    assert_equals "update branch without worktree matches remote" "$remote_sha" "$after_sha"
    pass "update branch via ref move without active worktree"
}

run_detached_targets_test() {
    local bare_repo="$1"
    local worktree="$bare_repo/develop"
    local tag_commit
    local head_commit

    tag_commit="$(git -C "$worktree" rev-parse HEAD)"
    git --git-dir="$bare_repo" tag v1.0.0 "$tag_commit"

    (cd "$bare_repo" && "$UPDATE_CMD" "$worktree" --to refs/tags/v1.0.0 >/dev/null)
    assert_equals "tag target produces detached head" "HEAD" "$(git -C "$worktree" symbolic-ref -q --short HEAD || echo HEAD)"
    assert_equals "tag target points at tagged commit" "$tag_commit" "$(git -C "$worktree" rev-parse HEAD)"

    head_commit="$(git -C "$worktree" rev-parse HEAD)"
    (cd "$bare_repo" && "$UPDATE_CMD" "$worktree" --to "$head_commit" >/dev/null)
    assert_equals "commit target remains detached" "HEAD" "$(git -C "$worktree" symbolic-ref -q --short HEAD || echo HEAD)"
    assert_equals "commit target points at requested commit" "$head_commit" "$(git -C "$worktree" rev-parse HEAD)"
    git -C "$worktree" checkout -q develop
    pass "update worktree to tag and commit in detached mode"
}

run_non_fast_forward_rejection_test() {
    local bare_repo="$1"
    local worktree="$bare_repo/develop"
    local output

    git -C "$worktree" commit --allow-empty -qm "local only commit"
    if output="$(cd "$worktree" && "$UPDATE_CMD" 2>&1)"; then
        fail "non-fast-forward update is rejected"
    fi
    assert_contains "non-fast-forward error message" "$output" "Cannot fast-forward"
    git -C "$worktree" reset --hard -q refs/remotes/origin/develop
    pass "reject non-fast-forward update"
}

run_merge_tests() {
    local bare_repo="$1"
    local worktree="$bare_repo/feat/versioned"

    git -C "$bare_repo/develop" checkout -q -b feat/local-source
    echo "local source" > "$bare_repo/develop/local-source.txt"
    git -C "$bare_repo/develop" add local-source.txt
    git -C "$bare_repo/develop" commit -qm "local source branch"

    (cd "$bare_repo" && "$MERGE_CMD" feat/local-source feat/versioned >/dev/null)
    git -C "$worktree" show HEAD:local-source.txt >/dev/null 2>&1 || fail "merge local branch into destination worktree"

    git --git-dir="$bare_repo" tag v1.1.0 "$(git -C "$worktree" rev-parse HEAD)"
    echo "dest change" > "$worktree/dest-change.txt"
    git -C "$worktree" add dest-change.txt
    git -C "$worktree" commit -qm "destination change"
    (cd "$bare_repo" && "$MERGE_CMD" refs/tags/v1.1.0 feat/versioned >/dev/null)

    git -C "$bare_repo/develop" checkout -q develop
    echo "remote merge input" > "$bare_repo/develop/remote-merge.txt"
    git -C "$bare_repo/develop" add remote-merge.txt
    git -C "$bare_repo/develop" commit -qm "prepare remote merge"
    git -C "$bare_repo/develop" push -q origin develop
    (cd "$bare_repo" && "$MERGE_CMD" refs/remotes/origin/develop feat/versioned >/dev/null)
    git -C "$worktree" show HEAD:remote-merge.txt >/dev/null 2>&1 || fail "merge remote branch into destination worktree"

    pass "merge local, tag, and remote refs into destination worktree"
}

run_merge_detached_destination_test() {
    local bare_repo="$1"
    local worktree="$bare_repo/feat/versioned"
    local commit
    local output

    commit="$(git -C "$worktree" rev-parse HEAD)"
    git -C "$worktree" checkout --detach -q "$commit"
    if output="$(cd "$bare_repo" && "$MERGE_CMD" refs/remotes/origin/develop feat/versioned 2>&1)"; then
        fail "merge rejects detached destination"
    fi
    assert_contains "merge detached destination message" "$output" "detached"
    git -C "$worktree" checkout -q feat/versioned
    pass "merge rejects detached destination worktree"
}

run_end_to_end_sync_test() {
    local bare_repo="$1"
    local worktree="$bare_repo/feat/versioned"

    export WORKTREE_SYNC_SKIP_INSTALL=1
    "$SYNC_CMD" "$worktree" >/dev/null
    [[ -L "$worktree/backend/.env" ]] || fail "sync remains independent after update and merge"
    (cd "$bare_repo" && printf "yes\n" | "$REMOVE_CMD" feat/versioned >/dev/null)
    [[ ! -d "$worktree" ]] || fail "remove still works after create update sync merge"
    pass "end-to-end create update sync merge remove flow"
}

main() {
    [[ -x "$CREATE_CMD" ]] || fail "create command executable" "$CREATE_CMD is not executable"
    [[ -x "$UPDATE_CMD" ]] || fail "update command executable" "$UPDATE_CMD is not executable"
    [[ -x "$MERGE_CMD" ]] || fail "merge command executable" "$MERGE_CMD is not executable"

    TEST_TMP_DIR="$(mktemp -d)"
    trap '[[ -n "${TEST_TMP_DIR:-}" ]] && rm -rf "$TEST_TMP_DIR"' EXIT

    local bare_repo
    bare_repo="$(setup_repo "$TEST_TMP_DIR")"
    local upstream="$TEST_TMP_DIR/upstream.git"

    run_update_current_worktree_test "$bare_repo" "$upstream"
    run_update_explicit_branch_test "$bare_repo" "$upstream"
    run_update_branch_without_worktree_test "$bare_repo" "$upstream"
    run_detached_targets_test "$bare_repo"
    run_non_fast_forward_rejection_test "$bare_repo"
    run_merge_tests "$bare_repo"
    run_merge_detached_destination_test "$bare_repo"
    run_end_to_end_sync_test "$bare_repo"

    echo ""
    echo "All worktree version command tests passed."
}

main "$@"
