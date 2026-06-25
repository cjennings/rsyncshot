#!/usr/bin/env bash
# ==============================================================================
# Remote (SSH) Mode Tests
# ==============================================================================
# First coverage of the remote path — backup + rotation run over SSH. The whole
# transfer and rotation happen via ssh to localhost, which exercises run_cmd's
# remote branch and the bare cp/mv/rm rotation commands. Gated: if root can't
# ssh to localhost with key auth, the suite skips rather than fails, so machines
# without loopback SSH still pass.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/test_helpers.sh"

remote_available() {
    ssh -o BatchMode=yes -o ConnectTimeout=5 localhost true 2>/dev/null
}

# ------------------------------------------------------------------------------
# Backup + rotation over SSH-to-localhost
# ------------------------------------------------------------------------------
test_remote_backup_and_rotation() {
    setup_test_env
    cat > "$TEST_CONFIG_DIR/config" <<EOF
REMOTE_HOST="localhost"
REMOTE_PATH="$TEST_BACKUP_DIR"
EOF
    create_test_includes >/dev/null
    create_test_excludes >/dev/null

    # Two runs to exercise rotation over SSH (MANUAL.0 rotates to MANUAL.1)
    INSTALLHOME="$TEST_CONFIG_DIR" "$SCRIPT_PATH" manual 2 >/dev/null 2>&1
    INSTALLHOME="$TEST_CONFIG_DIR" "$SCRIPT_PATH" manual 2 >/dev/null 2>&1

    assert_dir_exists "$TEST_BACKUP_DIR/$HOSTNAME/MANUAL.0" "remote backup should create MANUAL.0" || { teardown_test_env; return 1; }
    assert_dir_exists "$TEST_BACKUP_DIR/$HOSTNAME/MANUAL.1" "remote rotation should produce MANUAL.1" || { teardown_test_env; return 1; }
    assert_file_exists "$TEST_BACKUP_DIR/$HOSTNAME/latest$TEST_SOURCE_DIR/home/testuser/file1.txt" "remote backup should copy files" || { teardown_test_env; return 1; }

    teardown_test_env
}

# ------------------------------------------------------------------------------
# An unreachable remote skips gracefully (exit 0), not an error
# ------------------------------------------------------------------------------
# Needs no real remote: an unresolvable .invalid host makes the SSH check fail,
# so this runs unconditionally (not behind the localhost gate).
test_remote_unreachable_skips_gracefully() {
    setup_test_env
    cat > "$TEST_CONFIG_DIR/config" <<EOF
REMOTE_HOST="rsyncshot-nonexistent.invalid"
REMOTE_PATH="/tmp/rsyncshot-noremote"
EOF
    create_test_includes >/dev/null
    create_test_excludes >/dev/null

    local output rc
    output=$(INSTALLHOME="$TEST_CONFIG_DIR" LOCKFILE="$TEST_DIR/lock" "$SCRIPT_PATH" manual 1 2>&1)
    rc=$?

    teardown_test_env

    assert_exit_code 0 "$rc" "unreachable remote should skip gracefully (exit 0)" || return 1
    assert_contains "$output" "unreachable" "should log the unreachable skip" || return 1
}

# ------------------------------------------------------------------------------
# Run tests
# ------------------------------------------------------------------------------
run_remote_tests() {
    echo ""
    echo "Running remote (SSH) tests..."
    echo "------------------------------------------------------------"

    run_test "unreachable remote skips gracefully" test_remote_unreachable_skips_gracefully

    if ! remote_available; then
        echo "  SKIP: root cannot ssh to localhost with key auth — skipping live remote tests"
        return 0
    fi

    run_test "remote backup + rotation over SSH" test_remote_backup_and_rotation
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_remote_tests
    print_summary
fi
