#!/usr/bin/env bash
# ==============================================================================
# Include File Parsing Tests
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../lib/test_helpers.sh"

# ------------------------------------------------------------------------------
# Test: Reads newline-separated paths
# ------------------------------------------------------------------------------
test_reads_newline_paths() {
    setup_test_env

    # Create config and include files
    create_test_config
    create_test_excludes

    # Create include file with newline-separated paths
    cat > "$TEST_CONFIG_DIR/include.txt" << EOF
$TEST_SOURCE_DIR/home
$TEST_SOURCE_DIR/etc
EOF

    # Run dryrun to test parsing
    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" dryrun manual 1 2>&1)
    local exit_code=$?

    teardown_test_env

    # Should process both directories
    assert_contains "$output" "Syncing $TEST_SOURCE_DIR/home" "should sync home" || return 1
    assert_contains "$output" "Syncing $TEST_SOURCE_DIR/etc" "should sync etc" || return 1
}

# ------------------------------------------------------------------------------
# Test: Skips comment lines
# ------------------------------------------------------------------------------
test_skips_comments() {
    setup_test_env

    create_test_config
    create_test_excludes

    # Create include file with comments
    cat > "$TEST_CONFIG_DIR/include.txt" << EOF
# This is a comment
$TEST_SOURCE_DIR/home
# Another comment
$TEST_SOURCE_DIR/etc
EOF

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" dryrun manual 1 2>&1)

    teardown_test_env

    # Should not try to sync comment lines
    assert_not_contains "$output" "Syncing # This" "should skip comments" || return 1
    assert_contains "$output" "Syncing $TEST_SOURCE_DIR/home" "should sync home" || return 1
}

# ------------------------------------------------------------------------------
# Test: Skips empty lines
# ------------------------------------------------------------------------------
test_skips_empty_lines() {
    setup_test_env

    create_test_config
    create_test_excludes

    # Create include file with empty lines
    cat > "$TEST_CONFIG_DIR/include.txt" << EOF
$TEST_SOURCE_DIR/home

$TEST_SOURCE_DIR/etc

EOF

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" dryrun manual 1 2>&1)

    teardown_test_env

    # Should process both directories without errors
    assert_contains "$output" "Syncing $TEST_SOURCE_DIR/home" "should sync home" || return 1
    assert_contains "$output" "Syncing $TEST_SOURCE_DIR/etc" "should sync etc" || return 1
}

# ------------------------------------------------------------------------------
# Test: Handles paths with spaces
# ------------------------------------------------------------------------------
test_handles_paths_with_spaces() {
    setup_test_env

    create_test_config
    create_test_excludes

    # Create a directory with spaces
    mkdir -p "$TEST_SOURCE_DIR/path with spaces"
    echo "test" > "$TEST_SOURCE_DIR/path with spaces/file.txt"

    # Create include file with path containing spaces
    cat > "$TEST_CONFIG_DIR/include.txt" << EOF
$TEST_SOURCE_DIR/path with spaces
EOF

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" dryrun manual 1 2>&1)

    teardown_test_env

    # Should handle the path with spaces
    assert_contains "$output" "path with spaces" "should handle spaces in path" || return 1
    assert_not_contains "$output" "not found" "should not report path not found" || return 1
}

# ------------------------------------------------------------------------------
# Test: Reports missing directory
# ------------------------------------------------------------------------------
test_reports_missing_directory() {
    setup_test_env

    create_test_config
    create_test_excludes

    # Create include file with non-existent path
    cat > "$TEST_CONFIG_DIR/include.txt" << EOF
/nonexistent/path/that/does/not/exist
EOF

    local output
    output=$(sudo INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" dryrun manual 1 2>&1)
    local exit_code=$?

    teardown_test_env

    assert_exit_code 1 "$exit_code" "should fail for missing directory" || return 1
    assert_contains "$output" "not found" "should report directory not found" || return 1
}

# ------------------------------------------------------------------------------
# Run tests
# ------------------------------------------------------------------------------
run_includes_tests() {
    echo ""
    echo "Running include file tests..."
    echo "------------------------------------------------------------"

    run_test "reads newline-separated paths" test_reads_newline_paths
    run_test "skips comment lines" test_skips_comments
    run_test "skips empty lines" test_skips_empty_lines
    run_test "handles paths with spaces" test_handles_paths_with_spaces
    run_test "reports missing directory" test_reports_missing_directory
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_includes_tests
    print_summary
fi
