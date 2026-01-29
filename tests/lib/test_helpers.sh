#!/usr/bin/env bash
# ==============================================================================
# Test Helper Functions for rsyncshot
# ==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test environment paths
TEST_DIR=""
TEST_CONFIG_DIR=""
TEST_BACKUP_DIR=""
SCRIPT_PATH=""

# ------------------------------------------------------------------------------
# Setup/Teardown
# ------------------------------------------------------------------------------

setup_test_env() {
    # Create temporary directories for testing
    TEST_DIR=$(mktemp -d)
    TEST_CONFIG_DIR="$TEST_DIR/etc/rsyncshot"
    TEST_BACKUP_DIR="$TEST_DIR/backup"
    TEST_SOURCE_DIR="$TEST_DIR/source"

    mkdir -p "$TEST_CONFIG_DIR"
    mkdir -p "$TEST_BACKUP_DIR"
    mkdir -p "$TEST_SOURCE_DIR/home/testuser"
    mkdir -p "$TEST_SOURCE_DIR/etc"

    # Create some test files
    echo "test file 1" > "$TEST_SOURCE_DIR/home/testuser/file1.txt"
    echo "test file 2" > "$TEST_SOURCE_DIR/home/testuser/file2.txt"
    echo "config data" > "$TEST_SOURCE_DIR/etc/test.conf"

    # Find the script (relative to tests directory)
    SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/rsyncshot"

    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "ERROR: Cannot find rsyncshot script at $SCRIPT_PATH"
        exit 1
    fi
}

teardown_test_env() {
    # Clean up temporary directories
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Run rsyncshot with test environment variables
# Usage: run_rsyncshot [args...]
run_rsyncshot() {
    INSTALLHOME="$TEST_CONFIG_DIR" RSYNCSHOT_SKIP_MOUNT_CHECK=1 "$SCRIPT_PATH" "$@"
}

# Create a test config file
create_test_config() {
    local config_file="$TEST_CONFIG_DIR/config"
    cat > "$config_file" << EOF
REMOTE_HOST=""
MOUNTDIR="$TEST_BACKUP_DIR"
EOF
    echo "$config_file"
}

# Create a test include file
create_test_includes() {
    local include_file="$TEST_CONFIG_DIR/include.txt"
    cat > "$include_file" << EOF
$TEST_SOURCE_DIR/home
$TEST_SOURCE_DIR/etc
EOF
    echo "$include_file"
}

# Create a test exclude file
create_test_excludes() {
    local exclude_file="$TEST_CONFIG_DIR/exclude.txt"
    cat > "$exclude_file" << EOF
*.tmp
*.log
.cache
EOF
    echo "$exclude_file"
}

# ------------------------------------------------------------------------------
# Assertions
# ------------------------------------------------------------------------------

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    if [ "$expected" = "$actual" ]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code should be $expected}"

    if [ "$expected" -eq "$actual" ]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected exit code: $expected"
        echo "  Actual exit code:   $actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Output should contain '$needle'}"

    if echo "$haystack" | grep -q "$needle"; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Looking for: $needle"
        echo "  In output:   $haystack"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Output should not contain '$needle'}"

    if ! echo "$haystack" | grep -q "$needle"; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Should not contain: $needle"
        echo "  But found in:       $haystack"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"

    if [ -f "$file" ]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist: $dir}"

    if [ -d "$dir" ]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist: $file}"

    if [ ! -f "$file" ]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message"
        return 1
    fi
}

assert_dir_not_exists() {
    local dir="$1"
    local message="${2:-Directory should not exist: $dir}"

    if [ ! -d "$dir" ]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: $message"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Test Runner
# ------------------------------------------------------------------------------

run_test() {
    local test_name="$1"
    local test_func="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    # Run the test function and capture result
    if $test_func; then
        echo -e "${GREEN}PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

print_summary() {
    echo ""
    echo "============================================================"
    echo "Test Summary"
    echo "============================================================"
    echo -e "Total:  $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}
