#!/usr/bin/env bash
# ==============================================================================
# Cron Job Management Tests
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../lib/test_helpers.sh"

# Save original crontab to restore later
ORIGINAL_CRONTAB=""

save_crontab() {
    ORIGINAL_CRONTAB=$(crontab -l 2>/dev/null || true)
}

restore_crontab() {
    if [ -n "$ORIGINAL_CRONTAB" ]; then
        echo "$ORIGINAL_CRONTAB" | crontab -
    else
        crontab -r 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# Test: Setup adds cron jobs
# ------------------------------------------------------------------------------
test_setup_adds_cron_jobs() {
    setup_test_env
    save_crontab

    # Clear existing crontab
    crontab -r 2>/dev/null || true

    # Create minimal config
    cat > "$TEST_CONFIG_DIR/config" << EOF
REMOTE_HOST=""
MOUNTDIR="$TEST_BACKUP_DIR"
EOF
    create_test_includes
    create_test_excludes

    # Run setup (will fail on some checks but should still add cron)
    sudo INSTALLHOME="$TEST_CONFIG_DIR" SCRIPTLOC="/tmp/rsyncshot-test" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" setup >/dev/null 2>&1 || true

    # Check crontab contains rsyncshot entries
    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    restore_crontab
    teardown_test_env

    assert_contains "$crontab_content" "rsyncshot" "crontab should contain rsyncshot" || return 1
    assert_contains "$crontab_content" "hourly" "crontab should contain hourly job" || return 1
    assert_contains "$crontab_content" "daily" "crontab should contain daily job" || return 1
    assert_contains "$crontab_content" "weekly" "crontab should contain weekly job" || return 1
}

# ------------------------------------------------------------------------------
# Test: Repeated setup doesn't duplicate entries
# ------------------------------------------------------------------------------
test_no_duplicate_cron_entries() {
    setup_test_env
    save_crontab

    # Clear existing crontab
    crontab -r 2>/dev/null || true

    cat > "$TEST_CONFIG_DIR/config" << EOF
REMOTE_HOST=""
MOUNTDIR="$TEST_BACKUP_DIR"
EOF
    create_test_includes
    create_test_excludes

    # Run setup twice
    sudo INSTALLHOME="$TEST_CONFIG_DIR" SCRIPTLOC="/tmp/rsyncshot-test" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" setup >/dev/null 2>&1 || true
    sudo INSTALLHOME="$TEST_CONFIG_DIR" SCRIPTLOC="/tmp/rsyncshot-test" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" setup >/dev/null 2>&1 || true

    # Count rsyncshot entries
    local crontab_content hourly_count
    crontab_content=$(crontab -l 2>/dev/null)
    hourly_count=$(echo "$crontab_content" | grep -c "hourly" || echo 0)

    restore_crontab
    teardown_test_env

    # Should only have 1 hourly entry, not 2
    assert_equals "1" "$hourly_count" "should have exactly 1 hourly entry after repeated setup" || return 1
}

# ------------------------------------------------------------------------------
# Test: Setup preserves existing cron jobs
# ------------------------------------------------------------------------------
test_preserves_existing_cron() {
    setup_test_env
    save_crontab

    # Add a custom cron job
    (crontab -l 2>/dev/null || true; echo "0 5 * * * /custom/job.sh") | crontab -

    cat > "$TEST_CONFIG_DIR/config" << EOF
REMOTE_HOST=""
MOUNTDIR="$TEST_BACKUP_DIR"
EOF
    create_test_includes
    create_test_excludes

    # Run setup
    sudo INSTALLHOME="$TEST_CONFIG_DIR" SCRIPTLOC="/tmp/rsyncshot-test" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" setup >/dev/null 2>&1 || true

    # Check custom job still exists
    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    restore_crontab
    teardown_test_env

    assert_contains "$crontab_content" "/custom/job.sh" "should preserve existing cron jobs" || return 1
    assert_contains "$crontab_content" "rsyncshot" "should also have rsyncshot jobs" || return 1
}

# ------------------------------------------------------------------------------
# Test: Cron entries no longer wrap rsyncshot in an external flock
# ------------------------------------------------------------------------------
# rsyncshot locks internally now, so setup should write bare cron commands.
test_cron_no_flock_wrapper() {
    setup_test_env
    save_crontab

    crontab -r 2>/dev/null || true

    cat > "$TEST_CONFIG_DIR/config" << EOF
REMOTE_HOST=""
MOUNTDIR="$TEST_BACKUP_DIR"
EOF
    create_test_includes
    create_test_excludes

    sudo INSTALLHOME="$TEST_CONFIG_DIR" SCRIPTLOC="/tmp/rsyncshot-test" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" setup >/dev/null 2>&1 || true

    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    restore_crontab
    teardown_test_env

    assert_not_contains "$crontab_content" "flock" "cron entries should not wrap rsyncshot in flock (internal locking)" || return 1
    assert_contains "$crontab_content" "rsyncshot" "cron should still contain rsyncshot entries" || return 1
}

# ------------------------------------------------------------------------------
# Run tests
# ------------------------------------------------------------------------------
run_cron_tests() {
    echo ""
    echo "Running cron tests..."
    echo "------------------------------------------------------------"

    run_test "setup adds cron jobs" test_setup_adds_cron_jobs
    run_test "repeated setup doesn't duplicate entries" test_no_duplicate_cron_entries
    run_test "setup preserves existing cron jobs" test_preserves_existing_cron
    run_test "cron entries have no flock wrapper" test_cron_no_flock_wrapper
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_cron_tests
    print_summary
fi
