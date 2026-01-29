#!/usr/bin/env bash
# ==============================================================================
# Input Validation Tests
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../lib/test_helpers.sh"

# ------------------------------------------------------------------------------
# Test: Help works without root
# ------------------------------------------------------------------------------
test_help_without_root() {
    local output
    output=$("$SCRIPT_PATH" help 2>&1)
    local exit_code=$?

    assert_exit_code 0 "$exit_code" "help should exit with 0" || return 1
    assert_contains "$output" "rsyncshot" "help should mention rsyncshot" || return 1
    assert_contains "$output" "Usage" "help should show usage" || return 1
}

# ------------------------------------------------------------------------------
# Test: Rejects non-alphabetic snapshot type
# ------------------------------------------------------------------------------
test_rejects_numeric_snapshot_type() {
    local output
    output=$(sudo "$SCRIPT_PATH" "123" "5" 2>&1)
    local exit_code=$?

    assert_exit_code 1 "$exit_code" "should reject numeric snapshot type" || return 1
    assert_contains "$output" "must be alphabetic" "should show alphabetic error" || return 1
}

# ------------------------------------------------------------------------------
# Test: Rejects mixed alphanumeric snapshot type
# ------------------------------------------------------------------------------
test_rejects_mixed_snapshot_type() {
    local output
    output=$(sudo "$SCRIPT_PATH" "hourly123" "5" 2>&1)
    local exit_code=$?

    assert_exit_code 1 "$exit_code" "should reject mixed snapshot type" || return 1
    assert_contains "$output" "must be alphabetic" "should show alphabetic error" || return 1
}

# ------------------------------------------------------------------------------
# Test: Rejects non-numeric retention count
# ------------------------------------------------------------------------------
test_rejects_alpha_retention_count() {
    local output
    output=$(sudo "$SCRIPT_PATH" "manual" "abc" 2>&1)
    local exit_code=$?

    assert_exit_code 1 "$exit_code" "should reject alphabetic count" || return 1
    assert_contains "$output" "must be a number" "should show number error" || return 1
}

# ------------------------------------------------------------------------------
# Test: Rejects mixed alphanumeric retention count
# ------------------------------------------------------------------------------
test_rejects_mixed_retention_count() {
    local output
    output=$(sudo "$SCRIPT_PATH" "manual" "5abc" 2>&1)
    local exit_code=$?

    assert_exit_code 1 "$exit_code" "should reject mixed count" || return 1
    assert_contains "$output" "must be a number" "should show number error" || return 1
}

# ------------------------------------------------------------------------------
# Test: Accepts valid alphabetic snapshot types
# ------------------------------------------------------------------------------
test_accepts_valid_snapshot_types() {
    # We use dryrun to avoid actual backup, and expect it to fail on missing config
    # but it should get past the validation stage
    local output
    output=$(sudo "$SCRIPT_PATH" dryrun "hourly" "24" 2>&1)

    # Should not contain the validation error (might fail for other reasons like missing config)
    assert_not_contains "$output" "must be alphabetic" "should accept valid type" || return 1
}

# ------------------------------------------------------------------------------
# Run tests
# ------------------------------------------------------------------------------
run_validation_tests() {
    echo ""
    echo "Running validation tests..."
    echo "------------------------------------------------------------"

    setup_test_env

    run_test "help works without root" test_help_without_root
    run_test "rejects numeric snapshot type" test_rejects_numeric_snapshot_type
    run_test "rejects mixed alphanumeric snapshot type" test_rejects_mixed_snapshot_type
    run_test "rejects alphabetic retention count" test_rejects_alpha_retention_count
    run_test "rejects mixed retention count" test_rejects_mixed_retention_count
    run_test "accepts valid snapshot types" test_accepts_valid_snapshot_types

    teardown_test_env
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_validation_tests
    print_summary
fi
