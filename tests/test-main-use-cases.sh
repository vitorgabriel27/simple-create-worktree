#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREATE_CMD="$ROOT_DIR/git-create-worktree"
REMOVE_CMD="$ROOT_DIR/git-remove-worktree"
UPDATE_CMD="$ROOT_DIR/git-update-worktree"
MERGE_CMD="$ROOT_DIR/git-merge-worktree"

TEST_COUNT=0
TEST_TMP_DIR=""

pass() {
    local name="$1"
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "[PASS] $name"
}

fail() {
    local name="$1"
    local details="${2:-}"
    echo "[FAIL] $name"
    if [[ -n "$details" ]]; then
        echo "       $details"
    fi
    exit 1
}

assert_file_exists() {
    local name="$1"
    local path="$2"
    [[ -e "$path" ]] || fail "$name" "Expected path to exist: $path"
}

assert_file_not_exists() {
    local name="$1"
    local path="$2"
    [[ ! -e "$path" ]] || fail "$name" "Expected path to not exist: $path"
}

assert_branch_exists() {
    local name="$1"
    local repo="$2"
    local branch="$3"
    git -C "$repo" rev-parse --verify "$branch" >/dev/null 2>&1 || fail "$name" "Expected branch to exist: $branch"
}

assert_branch_not_exists() {
    local name="$1"
    local repo="$2"
    local branch="$3"
    if git -C "$repo" rev-parse --verify "$branch" >/dev/null 2>&1; then
        fail "$name" "Expected branch to not exist: $branch"
    fi
}

assert_worktree_registered() {
    local name="$1"
    local repo="$2"
    local wt="$3"
    git -C "$repo" worktree list | grep -q "^$wt " || fail "$name" "Expected registered worktree: $wt"
}

assert_worktree_not_registered() {
    local name="$1"
    local repo="$2"
    local wt="$3"
    if git -C "$repo" worktree list | grep -q "^$wt "; then
        fail "$name" "Expected worktree to be unregistered: $wt"
    fi
}

run_help_tests() {
    local out_create
    out_create="$("$CREATE_CMD" --help 2>&1 || true)"
    echo "$out_create" | grep -q "Usage:" || fail "create --help works" "Expected Usage output"
    pass "create --help works"

    local out_remove
    out_remove="$("$REMOVE_CMD" --help 2>&1 || true)"
    echo "$out_remove" | grep -q "Usage:" || fail "remove --help works" "Expected Usage output"
    pass "remove --help works"

    local out_update
    out_update="$("$UPDATE_CMD" --help 2>&1 || true)"
    echo "$out_update" | grep -q "Usage:" || fail "update --help works" "Expected Usage output"
    pass "update --help works"

    local out_merge
    out_merge="$("$MERGE_CMD" --help 2>&1 || true)"
    echo "$out_merge" | grep -q "Usage:" || fail "merge --help works" "Expected Usage output"
    pass "merge --help works"
}

setup_repo() {
    local test_dir="$1"
    local origin="$test_dir/origin.git"
    local repo="$test_dir/repo"

    git init --bare -q "$origin"
    git clone -q "$origin" "$repo" >/dev/null 2>&1

    git -C "$repo" config user.name "test-user"
    git -C "$repo" config user.email "test-user@example.com"
    git -C "$repo" checkout -q -b main
    git -C "$repo" commit --allow-empty -m "init" -q
    git -C "$repo" push -q -u origin main
    git -C "$repo" branch feat/existing main
}

setup_repo_with_non_origin_remote() {
    local test_dir="$1"
    local upstream_remote="$test_dir/upstream.git"
    local seed_repo="$test_dir/seed-upstream"
    local repo="$test_dir/repo-non-origin"

    git init --bare -q "$upstream_remote"
    git clone -q "$upstream_remote" "$seed_repo" >/dev/null 2>&1
    git -C "$seed_repo" config user.name "test-user"
    git -C "$seed_repo" config user.email "test-user@example.com"
    git -C "$seed_repo" checkout -q -b develop
    git -C "$seed_repo" commit --allow-empty -m "seed" -q
    git -C "$seed_repo" push -q -u origin develop

    git init -q "$repo"
    git -C "$repo" config user.name "test-user"
    git -C "$repo" config user.email "test-user@example.com"
    git -C "$repo" remote add upstream "$upstream_remote"
    git -C "$repo" fetch -q upstream
    git -C "$repo" checkout -q -b develop upstream/develop
}

run_non_git_failure_test() {
    local non_repo="$1/non-repo"
    mkdir -p "$non_repo"

    if (cd "$non_repo" && "$CREATE_CMD" feat/any >/dev/null 2>&1); then
        fail "create fails outside git repository"
    fi
    pass "create fails outside git repository"
}

run_create_existing_branch_test() {
    local repo="$1"
    local nested="$repo/a/b"
    local worktree="$repo/feat/existing"

    mkdir -p "$nested"
    (cd "$nested" && "$CREATE_CMD" feat/existing >/dev/null)

    assert_file_exists "existing branch worktree directory created" "$worktree"
    assert_worktree_registered "existing branch worktree registered" "$repo" "$worktree"
    pass "create from existing branch"
}

run_remove_by_branch_test() {
    local repo="$1"
    local worktree="$repo/feat/existing"

    (cd "$repo" && printf "yes\n" | "$REMOVE_CMD" feat/existing >/dev/null)

    assert_file_not_exists "existing branch worktree removed" "$worktree"
    assert_worktree_not_registered "existing branch worktree unregistered" "$repo" "$worktree"
    assert_branch_not_exists "existing branch deleted" "$repo" "feat/existing"
    pass "remove by branch name"
}

run_create_new_branch_test() {
    local repo="$1"
    local nested="$repo/deep/path"
    local worktree="$repo/chore/new-work"

    mkdir -p "$nested"
    (cd "$nested" && "$CREATE_CMD" -b chore/new-work main >/dev/null)

    assert_file_exists "new branch worktree directory created" "$worktree"
    assert_worktree_registered "new branch worktree registered" "$repo" "$worktree"
    assert_branch_exists "new branch created" "$repo" "chore/new-work"
    pass "create with -b new branch"
}

run_remove_by_path_test() {
    local repo="$1"
    local worktree="$repo/chore/new-work"

    (cd "$repo" && printf "yes\n" | "$REMOVE_CMD" "$worktree" >/dev/null)

    assert_file_not_exists "new branch worktree removed by path" "$worktree"
    assert_worktree_not_registered "new branch worktree unregistered by path" "$repo" "$worktree"
    assert_branch_not_exists "new branch deleted by path removal" "$repo" "chore/new-work"
    pass "remove by worktree path"
}

run_create_existing_branch_with_non_origin_remote_test() {
    local repo="$1"
    local nested="$repo/nested/non-origin"
    local worktree="$repo/chore/upstream-branch"

    git -C "$repo" branch chore/upstream-branch upstream/develop
    mkdir -p "$nested"
    (cd "$nested" && "$CREATE_CMD" chore/upstream-branch >/dev/null)

    assert_file_exists "non-origin existing branch worktree directory created" "$worktree"
    assert_worktree_registered "non-origin existing branch worktree registered" "$repo" "$worktree"
    pass "create existing branch with non-origin remote"
}

run_create_new_branch_with_non_origin_remote_test() {
    local repo="$1"
    local nested="$repo/nested/non-origin-new"
    local worktree="$repo/feat/from-upstream"

    mkdir -p "$nested"
    (cd "$nested" && "$CREATE_CMD" -b feat/from-upstream develop >/dev/null)

    assert_file_exists "non-origin new branch worktree directory created" "$worktree"
    assert_worktree_registered "non-origin new branch worktree registered" "$repo" "$worktree"
    assert_branch_exists "non-origin new branch created" "$repo" "feat/from-upstream"
    pass "create new branch from non-origin remote base"
}

run_remove_non_origin_worktrees_test() {
    local repo="$1"

    (cd "$repo" && printf "yes\n" | "$REMOVE_CMD" chore/upstream-branch >/dev/null)
    (cd "$repo" && printf "yes\n" | "$REMOVE_CMD" feat/from-upstream >/dev/null)

    assert_file_not_exists "non-origin existing worktree removed" "$repo/chore/upstream-branch"
    assert_file_not_exists "non-origin new worktree removed" "$repo/feat/from-upstream"
    assert_branch_not_exists "non-origin existing branch deleted" "$repo" "chore/upstream-branch"
    assert_branch_not_exists "non-origin new branch deleted" "$repo" "feat/from-upstream"
    pass "remove non-origin worktrees"
}

main() {
    [[ -x "$CREATE_CMD" ]] || fail "create command executable" "$CREATE_CMD is not executable"
    [[ -x "$REMOVE_CMD" ]] || fail "remove command executable" "$REMOVE_CMD is not executable"
    [[ -x "$UPDATE_CMD" ]] || fail "update command executable" "$UPDATE_CMD is not executable"
    [[ -x "$MERGE_CMD" ]] || fail "merge command executable" "$MERGE_CMD is not executable"

    TEST_TMP_DIR="$(mktemp -d)"
    trap '[[ -n "${TEST_TMP_DIR:-}" ]] && rm -rf "$TEST_TMP_DIR"' EXIT

    run_help_tests
    run_non_git_failure_test "$TEST_TMP_DIR"

    setup_repo "$TEST_TMP_DIR"
    local repo="$TEST_TMP_DIR/repo"

    run_create_existing_branch_test "$repo"
    run_remove_by_branch_test "$repo"
    run_create_new_branch_test "$repo"
    run_remove_by_path_test "$repo"

    setup_repo_with_non_origin_remote "$TEST_TMP_DIR"
    local non_origin_repo="$TEST_TMP_DIR/repo-non-origin"
    run_create_existing_branch_with_non_origin_remote_test "$non_origin_repo"
    run_create_new_branch_with_non_origin_remote_test "$non_origin_repo"
    run_remove_non_origin_worktrees_test "$non_origin_repo"

    echo ""
    echo "All main use-case tests passed ($TEST_COUNT checks)."
}

main "$@"
