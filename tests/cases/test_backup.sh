#!/usr/bin/env bash
# ==============================================================================
# Backup and Rotation Tests
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../lib/test_helpers.sh"

# ------------------------------------------------------------------------------
# Test: Creates backup directory structure
# ------------------------------------------------------------------------------
test_creates_backup_structure() {
    setup_test_env

    create_test_config
    create_test_includes
    create_test_excludes

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" manual 1 2>&1)
    local exit_code=$?

    # Check directory structure
    assert_dir_exists "$TEST_BACKUP_DIR/$HOSTNAME" "should create hostname dir" || {
        teardown_test_env
        return 1
    }
    assert_dir_exists "$TEST_BACKUP_DIR/$HOSTNAME/latest" "should create latest dir" || {
        teardown_test_env
        return 1
    }
    assert_dir_exists "$TEST_BACKUP_DIR/$HOSTNAME/MANUAL.0" "should create MANUAL.0 snapshot" || {
        teardown_test_env
        return 1
    }

    teardown_test_env
}

# ------------------------------------------------------------------------------
# Test: Copies files to backup
# ------------------------------------------------------------------------------
test_copies_files() {
    setup_test_env

    create_test_config
    create_test_includes
    create_test_excludes

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" manual 1 2>&1)

    # Check files were copied
    assert_file_exists "$TEST_BACKUP_DIR/$HOSTNAME/latest/home/testuser/file1.txt" "should copy file1.txt" || {
        teardown_test_env
        return 1
    }
    assert_file_exists "$TEST_BACKUP_DIR/$HOSTNAME/latest/etc/test.conf" "should copy test.conf" || {
        teardown_test_env
        return 1
    }

    teardown_test_env
}

# ------------------------------------------------------------------------------
# Test: Snapshot is read-only
# ------------------------------------------------------------------------------
test_snapshot_readonly() {
    setup_test_env

    create_test_config
    create_test_includes
    create_test_excludes

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" manual 1 2>&1)

    # Check snapshot directory has no write permission
    # Note: We use stat to check actual permissions because -w always returns true for root
    local perms
    perms=$(stat -c '%A' "$TEST_BACKUP_DIR/$HOSTNAME/MANUAL.0" 2>/dev/null)
    if [[ "$perms" == *w* ]]; then
        echo "FAIL: Snapshot should be read-only (perms: $perms)"
        teardown_test_env
        return 1
    fi

    teardown_test_env
    return 0
}

# ------------------------------------------------------------------------------
# Test: Rotation works correctly
# ------------------------------------------------------------------------------
test_rotation() {
    setup_test_env

    create_test_config
    create_test_includes
    create_test_excludes

    # Run backup twice
    sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" manual 3 2>&1 >/dev/null
    sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" manual 3 2>&1 >/dev/null

    # Should have MANUAL.0 and MANUAL.1
    assert_dir_exists "$TEST_BACKUP_DIR/$HOSTNAME/MANUAL.0" "should have MANUAL.0" || {
        teardown_test_env
        return 1
    }
    assert_dir_exists "$TEST_BACKUP_DIR/$HOSTNAME/MANUAL.1" "should have MANUAL.1 after rotation" || {
        teardown_test_env
        return 1
    }

    teardown_test_env
}

# ------------------------------------------------------------------------------
# Test: Deletes oldest snapshot beyond retention
# ------------------------------------------------------------------------------
test_retention_limit() {
    setup_test_env

    create_test_config
    create_test_includes
    create_test_excludes

    # Run backup 4 times with retention of 3
    for i in 1 2 3 4; do
        sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" manual 3 2>&1 >/dev/null
    done

    # Should have MANUAL.0, MANUAL.1, MANUAL.2 but NOT MANUAL.3
    assert_dir_exists "$TEST_BACKUP_DIR/$HOSTNAME/MANUAL.0" "should have MANUAL.0" || {
        teardown_test_env
        return 1
    }
    assert_dir_exists "$TEST_BACKUP_DIR/$HOSTNAME/MANUAL.1" "should have MANUAL.1" || {
        teardown_test_env
        return 1
    }
    assert_dir_exists "$TEST_BACKUP_DIR/$HOSTNAME/MANUAL.2" "should have MANUAL.2" || {
        teardown_test_env
        return 1
    }
    assert_dir_not_exists "$TEST_BACKUP_DIR/$HOSTNAME/MANUAL.3" "should NOT have MANUAL.3 (beyond retention)" || {
        teardown_test_env
        return 1
    }

    teardown_test_env
}

# ------------------------------------------------------------------------------
# Test: Backup command works as alias
# ------------------------------------------------------------------------------
test_backup_command() {
    setup_test_env

    create_test_config
    create_test_includes
    create_test_excludes

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" backup 2>&1)
    local exit_code=$?

    # Should create MANUAL.0 (backup is alias for manual 1)
    assert_dir_exists "$TEST_BACKUP_DIR/$HOSTNAME/MANUAL.0" "backup should create MANUAL.0" || {
        teardown_test_env
        return 1
    }

    teardown_test_env
}

# ------------------------------------------------------------------------------
# Test: Excludes files matching patterns
# ------------------------------------------------------------------------------
test_excludes_patterns() {
    setup_test_env

    create_test_config
    create_test_includes

    # Create exclude file
    cat > "$TEST_CONFIG_DIR/exclude.txt" << 'EOF'
*.tmp
*.log
EOF

    # Create files that should be excluded
    echo "temp" > "$TEST_SOURCE_DIR/home/testuser/temp.tmp"
    echo "log" > "$TEST_SOURCE_DIR/home/testuser/app.log"

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" manual 1 2>&1)

    # Excluded files should not exist in backup
    assert_file_not_exists "$TEST_BACKUP_DIR/$HOSTNAME/latest/home/testuser/temp.tmp" "should exclude .tmp files" || {
        teardown_test_env
        return 1
    }
    assert_file_not_exists "$TEST_BACKUP_DIR/$HOSTNAME/latest/home/testuser/app.log" "should exclude .log files" || {
        teardown_test_env
        return 1
    }
    # Regular files should still exist
    assert_file_exists "$TEST_BACKUP_DIR/$HOSTNAME/latest/home/testuser/file1.txt" "should include regular files" || {
        teardown_test_env
        return 1
    }

    teardown_test_env
}

# ------------------------------------------------------------------------------
# Run tests
# ------------------------------------------------------------------------------
run_backup_tests() {
    echo ""
    echo "Running backup tests..."
    echo "------------------------------------------------------------"

    run_test "creates backup directory structure" test_creates_backup_structure
    run_test "copies files to backup" test_copies_files
    run_test "snapshot is read-only" test_snapshot_readonly
    run_test "rotation works correctly" test_rotation
    run_test "respects retention limit" test_retention_limit
    run_test "backup command works as alias" test_backup_command
    run_test "excludes files matching patterns" test_excludes_patterns
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_backup_tests
    print_summary
fi
