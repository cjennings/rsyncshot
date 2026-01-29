#!/usr/bin/env bash
# ==============================================================================
# Dry-Run Mode Tests
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../lib/test_helpers.sh"

# ------------------------------------------------------------------------------
# Test: Dry-run doesn't create backup directory
# ------------------------------------------------------------------------------
test_dryrun_no_directory_creation() {
    setup_test_env

    create_test_config
    create_test_includes
    create_test_excludes

    # Remove backup dir to verify it's not created
    rmdir "$TEST_BACKUP_DIR"

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" dryrun manual 1 2>&1)

    # Backup directory should NOT be created in dry-run mode
    assert_dir_not_exists "$TEST_BACKUP_DIR/$HOSTNAME" "backup dir should not be created in dryrun" || {
        teardown_test_env
        return 1
    }

    teardown_test_env
}

# ------------------------------------------------------------------------------
# Test: Dry-run shows what would be transferred
# ------------------------------------------------------------------------------
test_dryrun_shows_transfer_info() {
    setup_test_env

    create_test_config
    create_test_includes
    create_test_excludes

    # Create the backup directory structure for dryrun to work
    mkdir -p "$TEST_BACKUP_DIR/$HOSTNAME/latest"

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" dryrun manual 1 2>&1)

    teardown_test_env

    # Should show syncing messages
    assert_contains "$output" "Syncing" "should show syncing info" || return 1
    # Should show dry run message
    assert_contains "$output" "Dry run complete" "should show dryrun complete message" || return 1
}

# ------------------------------------------------------------------------------
# Test: Dry-run shows command to run actual backup
# ------------------------------------------------------------------------------
test_dryrun_shows_actual_command() {
    setup_test_env

    create_test_config
    create_test_includes
    create_test_excludes

    mkdir -p "$TEST_BACKUP_DIR/$HOSTNAME/latest"

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" dryrun manual 1 2>&1)

    teardown_test_env

    # Should show how to run actual backup
    assert_contains "$output" "sudo rsyncshot manual 1" "should show actual command" || return 1
}

# ------------------------------------------------------------------------------
# Test: Dry-run doesn't create snapshots
# ------------------------------------------------------------------------------
test_dryrun_no_snapshot_creation() {
    setup_test_env

    create_test_config
    create_test_includes
    create_test_excludes

    mkdir -p "$TEST_BACKUP_DIR/$HOSTNAME/latest"

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" dryrun manual 1 2>&1)

    # Should not create manual.0 snapshot
    assert_dir_not_exists "$TEST_BACKUP_DIR/$HOSTNAME/manual.0" "snapshot should not be created in dryrun" || {
        teardown_test_env
        return 1
    }

    teardown_test_env
}

# ------------------------------------------------------------------------------
# Run tests
# ------------------------------------------------------------------------------
run_dryrun_tests() {
    echo ""
    echo "Running dry-run tests..."
    echo "------------------------------------------------------------"

    run_test "dry-run doesn't create backup directory" test_dryrun_no_directory_creation
    run_test "dry-run shows transfer info" test_dryrun_shows_transfer_info
    run_test "dry-run shows actual command" test_dryrun_shows_actual_command
    run_test "dry-run doesn't create snapshots" test_dryrun_no_snapshot_creation
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_dryrun_tests
    print_summary
fi
