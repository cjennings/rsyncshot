#!/usr/bin/env bash
# ==============================================================================
# Concurrency Locking Tests
# ==============================================================================
# rsyncshot acquires an exclusive lock before the backup phase. These tests hold
# the lock in the test process (a separate open file description), then run the
# script with LOCKFILE pointed at the same file, so the script's flock -n fails
# exactly as a second concurrent backup would.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/test_helpers.sh"

# ------------------------------------------------------------------------------
# A real backup refuses to start while another holds the lock
# ------------------------------------------------------------------------------
test_refuses_when_lock_held() {
    setup_test_env
    create_test_config >/dev/null
    create_test_includes >/dev/null
    create_test_excludes >/dev/null

    local lock="$TEST_DIR/rsyncshot.lock"
    exec 9>"$lock"
    if ! flock -n 9; then
        echo "FAIL: test could not acquire the lock to set up the scenario"
        exec 9>&-
        teardown_test_env
        return 1
    fi

    local output rc
    output=$(INSTALLHOME="$TEST_CONFIG_DIR" LOCKFILE="$lock" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" manual 1 2>&1)
    rc=$?
    exec 9>&-   # release the lock for later tests

    assert_exit_code 1 "$rc" "should exit 1 when another instance holds the lock" || { teardown_test_env; return 1; }
    assert_contains "$output" "already running" "should report the lock contention" || { teardown_test_env; return 1; }

    teardown_test_env
}

# ------------------------------------------------------------------------------
# A dryrun is read-only and must NOT be blocked by a held lock
# ------------------------------------------------------------------------------
test_dryrun_not_blocked_by_lock() {
    setup_test_env
    create_test_config >/dev/null
    create_test_includes >/dev/null
    create_test_excludes >/dev/null

    local lock="$TEST_DIR/rsyncshot.lock"
    exec 9>"$lock"
    if ! flock -n 9; then
        echo "FAIL: test could not acquire the lock to set up the scenario"
        exec 9>&-
        teardown_test_env
        return 1
    fi

    local rc
    INSTALLHOME="$TEST_CONFIG_DIR" LOCKFILE="$lock" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" dryrun manual 1 >/dev/null 2>&1
    rc=$?
    exec 9>&-

    assert_exit_code 0 "$rc" "dryrun should not be blocked by a held lock" || { teardown_test_env; return 1; }

    teardown_test_env
}

# ------------------------------------------------------------------------------
# Two sequential real backups both succeed (lock is released on exit)
# ------------------------------------------------------------------------------
test_sequential_runs_each_acquire_lock() {
    setup_test_env
    create_test_config >/dev/null
    create_test_includes >/dev/null
    create_test_excludes >/dev/null

    local lock="$TEST_DIR/rsyncshot.lock"
    INSTALLHOME="$TEST_CONFIG_DIR" LOCKFILE="$lock" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" manual 2 >/dev/null 2>&1
    local rc1=$?
    INSTALLHOME="$TEST_CONFIG_DIR" LOCKFILE="$lock" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" manual 2 >/dev/null 2>&1
    local rc2=$?

    assert_exit_code 0 "$rc1" "first run should succeed and release the lock" || { teardown_test_env; return 1; }
    assert_exit_code 0 "$rc2" "second run should acquire the freed lock and succeed" || { teardown_test_env; return 1; }

    teardown_test_env
}

# ------------------------------------------------------------------------------
# Run tests
# ------------------------------------------------------------------------------
run_locking_tests() {
    echo ""
    echo "Running locking tests..."
    echo "------------------------------------------------------------"

    run_test "refuses to run when the lock is held" test_refuses_when_lock_held
    run_test "dryrun is not blocked by the lock" test_dryrun_not_blocked_by_lock
    run_test "sequential runs each acquire the lock" test_sequential_runs_each_acquire_lock
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_locking_tests
    print_summary
fi
