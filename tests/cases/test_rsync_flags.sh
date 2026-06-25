#!/usr/bin/env bash
# ==============================================================================
# rsync Invocation Flag Tests
# ==============================================================================
# Uses the command-capture shim to intercept rsync and assert on the flags the
# script passes, without performing a real transfer. Runs a dryrun so only rsync
# is invoked (no rotation, no cp/mv/rm).

source "$(dirname "${BASH_SOURCE[0]}")/../lib/test_helpers.sh"

# ------------------------------------------------------------------------------
# rsync is called with --numeric-ids (ownership fidelity) and -R (relative paths)
# ------------------------------------------------------------------------------
test_rsync_flags_numeric_ids_and_relative() {
    setup_test_env
    create_test_config >/dev/null
    create_test_includes >/dev/null
    create_test_excludes >/dev/null

    local shim
    shim=$(make_command_shim rsync)

    PATH="$shim:$PATH" INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 \
        "$SCRIPT_PATH" dryrun manual 1 >/dev/null 2>&1

    local args
    args=$(cat "$shim/rsync.args" 2>/dev/null)

    assert_file_exists "$shim/rsync.args" "rsync shim should have been invoked" || { rm -rf "$shim"; teardown_test_env; return 1; }
    assert_contains "$args" "--numeric-ids" "rsync should be called with --numeric-ids" || { rm -rf "$shim"; teardown_test_env; return 1; }
    assert_contains "$args" "-avhR" "rsync should be called with -R (relative paths, in -avhR)" || { rm -rf "$shim"; teardown_test_env; return 1; }
    assert_contains "$args" "--dry-run" "dryrun should pass --dry-run" || { rm -rf "$shim"; teardown_test_env; return 1; }

    rm -rf "$shim"
    teardown_test_env
}

# ------------------------------------------------------------------------------
# Run tests
# ------------------------------------------------------------------------------
run_rsync_flags_tests() {
    echo ""
    echo "Running rsync flag tests..."
    echo "------------------------------------------------------------"

    run_test "rsync uses --numeric-ids and -R" test_rsync_flags_numeric_ids_and_relative
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_rsync_flags_tests
    print_summary
fi
