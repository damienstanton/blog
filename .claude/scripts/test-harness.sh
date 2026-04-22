#!/usr/bin/env bash
# =============================================================================
# harness-kit Integration Test
# =============================================================================
# Tests the /harness-kit command end-to-end with scripted input.
#
# Usage:
#   bash .claude/scripts/test-harness.sh
#
# Requirements:
#   - Claude Code CLI (claude) installed
#   - gh CLI authenticated
#   - jq (for JSON parsing)
#   - Git repository with harness-kit framework installed
# =============================================================================

set -euo pipefail

# Test configuration
TEST_GOAL="Add a noop test helper function for integration tests"
SESSION_FILE=".claude/state/harness-session.json"
ARCHIVE_DIR=".claude/state/archive"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

cleanup() {
    log_info "Cleaning up test artifacts..."

    # Archive any existing session
    if [ -f "$SESSION_FILE" ]; then
        mkdir -p "$ARCHIVE_DIR"
        mv "$SESSION_FILE" "$ARCHIVE_DIR/test-session-$(date +%s).json"
        log_info "Archived existing session file"
    fi

    # Note: We don't delete the test issue/PR created during the test.
    # They serve as integration test artifacts and can be closed manually.
}

verify_prerequisites() {
    log_info "Verifying prerequisites..."

    # Check Claude Code CLI
    if ! command -v claude &> /dev/null; then
        log_error "Claude Code CLI not found. Install it first."
        exit 1
    fi
    log_success "Claude Code CLI found"

    # Check gh CLI
    if ! command -v gh &> /dev/null; then
        log_error "gh CLI not found. Install it first."
        exit 1
    fi

    # Check gh authentication
    if ! gh auth status &> /dev/null; then
        log_error "gh CLI not authenticated. Run 'gh auth login' first."
        exit 1
    fi
    log_success "gh CLI authenticated"

    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Install it with: brew install jq (macOS) or apt install jq (Linux)"
        exit 1
    fi
    log_success "jq found"

    # Check git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        log_error "Not in a git repository"
        exit 1
    fi
    log_success "Git repository detected"
}

test_session_creation() {
    log_info "Test 1: Session creation and persistence"

    # Ensure no existing session
    cleanup

    # TODO: Implement automated invocation of /harness-kit with scripted input
    # This requires either:
    # 1. A programmatic way to invoke Claude Code with input
    # 2. An expect-style script to pipe commands
    # 3. A mock implementation that simulates the workflow

    log_warn "Session creation test: MANUAL VERIFICATION REQUIRED"
    log_info "  1. Run: /harness-kit \"$TEST_GOAL\""
    log_info "  2. Verify session file created: $SESSION_FILE"
    log_info "  3. Verify issue created with 'refined' label"

    # For now, check if session file exists (assumes manual run)
    if [ -f "$SESSION_FILE" ]; then
        log_success "Session file exists"

        # Validate JSON structure
        if jq -e '.schema_version == "harness_session.v1"' "$SESSION_FILE" > /dev/null; then
            log_success "Session file has correct schema"
        else
            log_error "Session file has invalid schema"
            return 1
        fi

        # Check required fields
        if jq -e '.session_id and .goal and .current_stage' "$SESSION_FILE" > /dev/null; then
            log_success "Session file has required fields"
        else
            log_error "Session file missing required fields"
            return 1
        fi
    else
        log_warn "Session file not found. Run /harness-kit manually to test."
    fi
}

test_session_resume() {
    log_info "Test 2: Session resume capability"

    if [ ! -f "$SESSION_FILE" ]; then
        log_warn "No session file to test resume. Skipping."
        return 0
    fi

    # Check if session is incomplete (current_stage != COMPLETE)
    CURRENT_STAGE=$(jq -r '.current_stage' "$SESSION_FILE")

    if [ "$CURRENT_STAGE" == "COMPLETE" ]; then
        log_warn "Session is already complete. Cannot test resume."
        return 0
    fi

    log_info "  Current stage: $CURRENT_STAGE"
    log_warn "Resume test: MANUAL VERIFICATION REQUIRED"
    log_info "  1. Run: /harness-kit (without arguments)"
    log_info "  2. Verify resume prompt appears"
    log_info "  3. Select 'Resume existing session'"
    log_info "  4. Verify workflow continues from $CURRENT_STAGE"
}

test_workflow_completion() {
    log_info "Test 3: Full workflow completion"

    # Determine which file to use as source of truth
    local session_source=""

    if [ -f "$SESSION_FILE" ]; then
        session_source="$SESSION_FILE"
    else
        # Look for archived sessions safely with nullglob
        shopt -s nullglob
        local archive_files=("$ARCHIVE_DIR"/test-session-*.json)
        shopt -u nullglob

        if [ ${#archive_files[@]} -eq 0 ]; then
            log_warn "No active or archived session data found. Run /harness-kit manually first."
            return 0
        fi

        # Use most recently modified archive
        session_source=$(ls -t "${archive_files[@]}" 2>/dev/null | head -n 1)
    fi

    # Check if session completed
    CURRENT_STAGE=$(jq -r '.current_stage' "$session_source")

    if [ "$CURRENT_STAGE" == "COMPLETE" ]; then
        log_success "Workflow completed"

        # Verify session was archived (live file should be gone)
        if [ ! -f "$SESSION_FILE" ]; then
            log_success "Session file archived after completion"
        else
            log_warn "Session file still exists after completion"
        fi

        # Extract and verify issue/PR numbers
        ISSUE_NUM=$(jq -r '.issue_number' "$session_source" 2>/dev/null)
        PR_NUM=$(jq -r '.pr_number' "$session_source" 2>/dev/null)

        if [ -n "$ISSUE_NUM" ] && [ "$ISSUE_NUM" != "null" ]; then
            log_success "Issue created: #$ISSUE_NUM"

            # Verify issue exists on GitHub
            if gh issue view "$ISSUE_NUM" &> /dev/null; then
                log_success "Issue #$ISSUE_NUM exists on GitHub"
            else
                log_error "Issue #$ISSUE_NUM not found on GitHub"
            fi
        else
            log_error "No issue number in session data"
        fi

        if [ -n "$PR_NUM" ] && [ "$PR_NUM" != "null" ]; then
            log_success "PR created: #$PR_NUM"

            # Verify PR exists on GitHub
            if gh pr view "$PR_NUM" &> /dev/null; then
                log_success "PR #$PR_NUM exists on GitHub"
            else
                log_error "PR #$PR_NUM not found on GitHub"
            fi
        else
            log_error "No PR number in session data"
        fi
    else
        log_warn "Workflow not yet complete. Current stage: $CURRENT_STAGE"
        log_info "Continue the workflow manually to complete the test."
    fi
}

# =============================================================================
# Main Test Execution
# =============================================================================

main() {
    echo ""
    echo "======================================================================="
    echo "  harness-kit Integration Test Suite"
    echo "======================================================================="
    echo ""

    verify_prerequisites
    echo ""

    test_session_creation
    echo ""

    test_session_resume
    echo ""

    test_workflow_completion
    echo ""

    echo "======================================================================="
    log_info "Test suite complete"
    echo "======================================================================="
    echo ""

    log_warn "Note: This test suite requires manual /harness-kit invocation."
    log_info "Fully automated testing requires expect or similar tooling."
}

main "$@"
