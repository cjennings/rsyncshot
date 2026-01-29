#!/usr/bin/env bash
# ==============================================================================
# rsyncshot Test Suite
# ==============================================================================
#
# Runs all automated tests for rsyncshot.
#
# Usage:
#   sudo ./tests/test_rsyncshot.sh           # Run all tests
#   sudo ./tests/test_rsyncshot.sh -v        # Verbose output
#   sudo ./tests/test_rsyncshot.sh --quick   # Skip slow tests
#
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE=false
QUICK=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quick)
            QUICK=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-v|--verbose] [-q|--quick]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose  Show detailed test output"
            echo "  -q, --quick    Skip slow tests (backup/rotation)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo "Tests must be run as root (sudo ./tests/test_rsyncshot.sh)"
    exit 1
fi

# Source test helpers
source "$SCRIPT_DIR/lib/test_helpers.sh"

echo "============================================================"
echo "rsyncshot Test Suite"
echo "============================================================"
echo ""
echo "Script: $(cd "$SCRIPT_DIR/.." && pwd)/rsyncshot"
echo "Date:   $(date)"
echo ""

# Track overall results
TOTAL_RUN=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Run a test file and accumulate results
run_test_file() {
    local test_file="$1"
    local test_name="$2"

    # Reset counters before sourcing
    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0

    # Source and run the test file
    source "$test_file"

    # Call the run function
    "run_${test_name}_tests"

    # Accumulate totals
    TOTAL_RUN=$((TOTAL_RUN + TESTS_RUN))
    TOTAL_PASSED=$((TOTAL_PASSED + TESTS_PASSED))
    TOTAL_FAILED=$((TOTAL_FAILED + TESTS_FAILED))
}

# Run test suites
run_test_file "$SCRIPT_DIR/cases/test_validation.sh" "validation"
run_test_file "$SCRIPT_DIR/cases/test_includes.sh" "includes"
run_test_file "$SCRIPT_DIR/cases/test_dryrun.sh" "dryrun"

if [ "$QUICK" = false ]; then
    run_test_file "$SCRIPT_DIR/cases/test_backup.sh" "backup"
    run_test_file "$SCRIPT_DIR/cases/test_cron.sh" "cron"
else
    echo ""
    echo "Skipping slow tests (backup, cron) - use without --quick to run all"
fi

# Print final summary
echo ""
echo "============================================================"
echo "Final Summary"
echo "============================================================"
echo -e "Total:  $TOTAL_RUN"
echo -e "Passed: ${GREEN}$TOTAL_PASSED${NC}"
echo -e "Failed: ${RED}$TOTAL_FAILED${NC}"
echo ""

if [ "$TOTAL_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
