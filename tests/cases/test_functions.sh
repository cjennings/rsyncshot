#!/usr/bin/env bash
# ==============================================================================
# Unit Tests for Internal Functions (is_mounted, derive_paths)
# ==============================================================================
# These source the script with RSYNCSHOT_SOURCE_ONLY=1 so the functions are
# defined without running the main flow, then exercise them directly. Each test
# runs the source + assertions in a subshell so the derived globals and config
# variables don't leak into other suites.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/test_helpers.sh"

# ------------------------------------------------------------------------------
# is_mounted: exact mount point matches
# ------------------------------------------------------------------------------
test_is_mounted_exact_match() {
    setup_test_env
    local mounts="$TEST_DIR/mounts"
    cat > "$mounts" <<EOF
/dev/sda1 /media/backup ext4 rw,relatime 0 0
/dev/sdb1 /home ext4 rw,relatime 0 0
EOF
    (
        INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SOURCE_ONLY=1 source "$SCRIPT_PATH"
        is_mounted "/media/backup" "$mounts"
    )
    local rc=$?
    teardown_test_env
    assert_exit_code 0 "$rc" "exact mount point should match" || return 1
}

# ------------------------------------------------------------------------------
# is_mounted: a prefix is NOT a match (the substring-grep bug)
# ------------------------------------------------------------------------------
test_is_mounted_no_substring_match() {
    setup_test_env
    local mounts="$TEST_DIR/mounts"
    cat > "$mounts" <<EOF
/dev/sda1 /media/backup2 ext4 rw,relatime 0 0
EOF
    (
        INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SOURCE_ONLY=1 source "$SCRIPT_PATH"
        is_mounted "/media/backup" "$mounts"
    )
    local rc=$?
    teardown_test_env
    assert_exit_code 1 "$rc" "/media/backup must NOT match /media/backup2" || return 1
}

# ------------------------------------------------------------------------------
# is_mounted: mount points with spaces (encoded as \040 in /proc/mounts)
# ------------------------------------------------------------------------------
test_is_mounted_handles_spaces() {
    setup_test_env
    local mounts="$TEST_DIR/mounts"
    printf '/dev/sda1 /media/my\\040backup ext4 rw 0 0\n' > "$mounts"
    (
        INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SOURCE_ONLY=1 source "$SCRIPT_PATH"
        is_mounted "/media/my backup" "$mounts"
    )
    local rc=$?
    teardown_test_env
    assert_exit_code 0 "$rc" "mount point with spaces should match" || return 1
}

# ------------------------------------------------------------------------------
# is_mounted: target is treated literally, not as a regex
# ------------------------------------------------------------------------------
test_is_mounted_target_is_literal() {
    setup_test_env
    local mounts="$TEST_DIR/mounts"
    cat > "$mounts" <<EOF
/dev/sda1 /media/backup ext4 rw 0 0
EOF
    (
        INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SOURCE_ONLY=1 source "$SCRIPT_PATH"
        is_mounted "/media/b.ckup" "$mounts"
    )
    local rc=$?
    teardown_test_env
    assert_exit_code 1 "$rc" "regex metacharacters in target must be literal" || return 1
}

# ------------------------------------------------------------------------------
# derive_paths: remote mode uses bare cp/mv/rm (resolved by remote PATH)
# ------------------------------------------------------------------------------
test_derive_paths_remote() {
    setup_test_env
    cat > "$TEST_CONFIG_DIR/config" <<EOF
REMOTE_HOST="truenas"
REMOTE_PATH="/mnt/vault/Backups"
EOF
    (
        # The script sources the config and runs derive_paths during load.
        INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SOURCE_ONLY=1 source "$SCRIPT_PATH"
        assert_equals "remote" "$MODE" "should be remote mode" &&
        assert_equals "truenas:/mnt/vault/Backups/$HOSTNAME" "$DESTINATION" "remote destination" &&
        assert_equals "cp" "$CP" "remote cp is bare (remote PATH resolves it)" &&
        assert_equals "mv" "$MV" "remote mv is bare" &&
        assert_equals "rm" "$RM" "remote rm is bare"
    )
    local rc=$?
    teardown_test_env
    return $rc
}

# ------------------------------------------------------------------------------
# derive_paths: local mode resolves cp/mv/rm to real absolute binaries
# ------------------------------------------------------------------------------
test_derive_paths_local() {
    setup_test_env
    cat > "$TEST_CONFIG_DIR/config" <<EOF
REMOTE_HOST=""
MOUNTDIR="/media/backup"
EOF
    (
        INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SOURCE_ONLY=1 source "$SCRIPT_PATH"
        assert_equals "local" "$MODE" "should be local mode" &&
        assert_equals "/media/backup/$HOSTNAME" "$DESTINATION" "local destination" &&
        assert_contains "$CP" "/" "local cp resolves to an absolute path, not a bare name"
    )
    local rc=$?
    teardown_test_env
    return $rc
}

# ------------------------------------------------------------------------------
# Run tests
# ------------------------------------------------------------------------------
run_functions_tests() {
    echo ""
    echo "Running function unit tests..."
    echo "------------------------------------------------------------"

    run_test "is_mounted exact match" test_is_mounted_exact_match
    run_test "is_mounted rejects prefix (no substring match)" test_is_mounted_no_substring_match
    run_test "is_mounted handles spaces" test_is_mounted_handles_spaces
    run_test "is_mounted treats target literally" test_is_mounted_target_is_literal
    run_test "derive_paths remote mode" test_derive_paths_remote
    run_test "derive_paths local mode" test_derive_paths_local
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_functions_tests
    print_summary
fi
