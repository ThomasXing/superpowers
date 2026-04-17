---
name: qa
version: 2.0.0
description: |
  Enhanced QA workflow with gstack-inspired features:
  test framework detection, failure analysis, fix recommendations.
  Use when asked to "test", "qa", "check for bugs", or "verify functionality".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
  - WebSearch
---

# /qa: Enhanced Quality Assurance

Enhanced with gstack features:
- Comprehensive test framework detection
- Test failure pattern analysis
- Auto-fix suggestions for common issues
- Detailed health score reporting

## Step 0: Pre-flight Checks

```bash
# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "ERROR: Not in a git repository"
  exit 1
fi

# Check working tree status
if [[ -n $(git status --porcelain) ]]; then
  echo "WARNING: Working tree has uncommitted changes."
  echo "QA may create fix commits. Consider committing or stashing first."
  # Use AskUserQuestion to decide
fi

# Detect current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"
```

## Step 1: Identify Test Framework

Detect the project's test framework and runtime:

```bash
echo "Detecting project type and test framework..."

PROJECT_TYPE="unknown"
TEST_COMMAND=""

# Check for common project files
if [[ -f "package.json" ]]; then
  PROJECT_TYPE="node"
  # Check package.json for test script
  if grep -q '"test"' package.json; then
    TEST_COMMAND=$(node -e "try { const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8')); console.log(pkg.scripts?.test || ''); } catch(e) { console.log(''); }")
  fi
elif [[ -f "Gemfile" ]]; then
  PROJECT_TYPE="ruby"
  TEST_COMMAND="bundle exec rspec"
elif [[ -f "requirements.txt" || -f "pyproject.toml" ]]; then
  PROJECT_TYPE="python"
  if [[ -f "pytest.ini" || -f "pyproject.toml" ]]; then
    TEST_COMMAND="pytest"
  elif [[ -f "setup.py" ]]; then
    TEST_COMMAND="python -m pytest"
  else
    TEST_COMMAND="python -m unittest discover"
  fi
elif [[ -f "go.mod" ]]; then
  PROJECT_TYPE="go"
  TEST_COMMAND="go test ./..."
elif [[ -f "Cargo.toml" ]]; then
  PROJECT_TYPE="rust"
  TEST_COMMAND="cargo test"
elif [[ -f "composer.json" ]]; then
  PROJECT_TYPE="php"
  TEST_COMMAND="vendor/bin/phpunit"
elif [[ -f "Makefile" ]]; then
  PROJECT_TYPE="make"
  if grep -q "^test:" Makefile; then
    TEST_COMMAND="make test"
  fi
fi

# If no test command found, try common commands
if [[ -z "$TEST_COMMAND" ]]; then
  echo "No specific test command found, trying common commands..."
  
  # Try npm/yarn/bun test
  if [[ "$PROJECT_TYPE" == "node" ]]; then
    if command -v bun &> /dev/null; then
      TEST_COMMAND="bun test"
    elif command -v yarn &> /dev/null && [[ -f "yarn.lock" ]]; then
      TEST_COMMAND="yarn test"
    elif command -v npm &> /dev/null; then
      TEST_COMMAND="npm test"
    fi
  fi
fi

echo "Project type: $PROJECT_TYPE"
echo "Test command: ${TEST_COMMAND:-Not found}"
```

## Step 2: Run Tests

Execute the test suite and capture results:

```bash
if [[ -z "$TEST_COMMAND" ]]; then
  echo "ERROR: No test command found. Please specify how to run tests."
  echo "Common test commands:"
  echo "  - npm test / yarn test / bun test (Node.js)"
  echo "  - pytest (Python)"
  echo "  - go test ./... (Go)"
  echo "  - bundle exec rspec (Ruby)"
  echo "  - cargo test (Rust)"
  echo "  - make test (Make)"
  
  # Use AskUserQuestion to get test command
  exit 1
fi

echo "Running tests: $TEST_COMMAND"
echo "========================================"

# Run tests and capture output
TEST_OUTPUT_FILE=$(mktemp)
TEST_EXIT_CODE=0

# Execute test command
if eval "$TEST_COMMAND" 2>&1 | tee "$TEST_OUTPUT_FILE"; then
  echo "✓ Tests passed"
  TEST_EXIT_CODE=0
else
  echo "✗ Tests failed"
  TEST_EXIT_CODE=$?
fi

echo "========================================"
```

## Step 3: Analyze Test Results

Analyze test output to identify failures and categorize them:

```bash
# Read test output
TEST_OUTPUT=$(cat "$TEST_OUTPUT_FILE")
rm "$TEST_OUTPUT_FILE"

# Count test results (simple pattern matching)
PASS_COUNT=$(echo "$TEST_OUTPUT" | grep -i "passed\|✓\|PASS" | wc -l || echo "0")
FAIL_COUNT=$(echo "$TEST_OUTPUT" | grep -i "failed\|✗\|FAIL\|ERROR" | wc -l || echo "0")
SKIP_COUNT=$(echo "$TEST_OUTPUT" | grep -i "skipped\|pending" | wc -l || echo "0")

echo "Test Results Summary:"
echo "  Passed:  $PASS_COUNT"
echo "  Failed:  $FAIL_COUNT"
echo "  Skipped: $SKIP_COUNT"
echo "  Exit code: $TEST_EXIT_CODE"

# Extract failure details
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo ""
  echo "=== FAILURE DETAILS ==="
  
  # Try to extract failing test names
  FAILING_TESTS=$(echo "$TEST_OUTPUT" | grep -A 2 -B 2 -i "FAIL\|ERROR\|✗" | head -20)
  if [[ -n "$FAILING_TESTS" ]]; then
    echo "$FAILING_TESTS"
  else
    # Show last 20 lines of output
    echo "$TEST_OUTPUT" | tail -20
  fi
fi
```

## Step 4: Determine Action Based on Results

Based on test results, decide what to do next:

```bash
if [[ $TEST_EXIT_CODE -eq 0 ]]; then
  echo ""
  echo "✅ All tests passed!"
  echo "QA check completed successfully."
  
  # Create a summary report
  REPORT_FILE="qa-report-$(date +%Y%m%d-%H%M%S).txt"
  cat > "$REPORT_FILE" << EOF
QA Report - $(date)
===================

Project: $(basename "$(pwd)")
Branch: $CURRENT_BRANCH
Test command: $TEST_COMMAND

Results:
  Passed: $PASS_COUNT
  Failed: $FAIL_COUNT
  Skipped: $SKIP_COUNT

Status: ✅ PASS
Timestamp: $(date -Iseconds)

All tests passed successfully. No issues found.
EOF
  
  echo "Report saved to: $REPORT_FILE"
  
else
  echo ""
  echo "❌ Tests failed ($FAIL_COUNT failures)"
  
  # Determine severity
  if [[ $FAIL_COUNT -eq 1 ]] && [[ $PASS_COUNT -gt 0 ]]; then
    SEVERITY="low"
    echo "Minor issue - single test failure among many passes"
  elif [[ $FAIL_COUNT -le 3 ]] && [[ $PASS_COUNT -gt 10 ]]; then
    SEVERITY="medium"
    echo "Several test failures - needs investigation"
  else
    SEVERITY="high"
    echo "Critical - multiple test failures or no passes"
  fi
  
  # Ask user what to do
  echo ""
  echo "What would you like to do?"
  echo "1) Analyze failures and attempt fixes"
  echo "2) View full test output"
  echo "3) Skip and just create report"
  echo "4) Abort QA"
  
  # Use AskUserQuestion here in practice
  # For now, default to analyze
  ACTION="analyze"
fi
```

## Step 5: Analyze and Fix Failures (Optional)

If tests failed and user chooses to fix them:

```bash
if [[ "$ACTION" == "analyze" ]] && [[ $FAIL_COUNT -gt 0 ]]; then
  echo ""
  echo "=== ANALYZING FAILURES ==="
  
  # Initialize patterns array
  PATTERNS_FOUND=()
  
  # Look for common failure patterns (gstack-inspired)
  if echo "$TEST_OUTPUT" | grep -q "SyntaxError\|ParseError"; then
    PATTERNS_FOUND+=("syntax")
    echo "📌 Syntax errors detected"
    echo "   Suggestion: Check recent file changes for typos"
    git diff --name-only HEAD~5..HEAD 2>/dev/null | head -5
    
  elif echo "$TEST_OUTPUT" | grep -q "ImportError\|ModuleNotFoundError\|Cannot find module"; then
    PATTERNS_FOUND+=("import")
    echo "📌 Import/Module errors detected"
    echo "   Suggestion: Check dependencies and import paths"
    
  elif echo "$TEST_OUTPUT" | grep -q "AssertionError\|expect.*toBe\|expect.*toEqual"; then
    PATTERNS_FOUND+=("assertion")
    echo "📌 Assertion failures detected"
    echo "   Suggestion: Review test expectations vs actual behavior"
    
  elif echo "$TEST_OUTPUT" | grep -q "Timeout\|timeout\|timed out"; then
    PATTERNS_FOUND+=("timeout")
    echo "📌 Timeout issues detected"
    echo "   Suggestion: Check for infinite loops or slow operations"
  fi
    
  elif echo "$TEST_OUTPUT" | grep -q "ImportError\|ModuleNotFoundError"; then
    echo "Detected import/module errors"
    # Check dependencies
    echo "Checking dependencies..."
    if [[ -f "package.json" ]]; then
      echo "Node.js project - checking node_modules"
      ls node_modules 2>/dev/null | head -5 || echo "node_modules not found"
    elif [[ -f "requirements.txt" ]]; then
      # Generate recommendations based on patterns (gstack-inspired)
  if [[ ${#PATTERNS_FOUND[@]} -gt 0 ]]; then
    echo ""
    echo "=== RECOMMENDATIONS (gstack-enhanced) ==="
    echo "Detected patterns: ${PATTERNS_FOUND[*]}"
    echo ""
    echo "Next steps:"
    echo "1. Focus on files with syntax errors first"
    echo "2. Verify all imports are correct"
    echo "3. Review assertion failures in context"
    echo "4. Consider increasing timeouts if needed"
  fi
  
  # Look for specific failing test files
  FAILING_FILES=$(echo "$TEST_OUTPUT" | grep -E "\.(js|ts|py|rb|go|rs|php|java)\b" | grep -i "fail\|error" | head -5)
  if [[ -n "$FAILING_FILES" ]]; then
    echo ""
    echo "Files mentioned in failures:"
    echo "$FAILING_FILES"
  fi
  
  # Offer to create a fix
  echo ""
  echo "Would you like to attempt to fix these issues?"
  echo "I can:"
  echo "1) Examine specific failing test files"
  echo "2) Check recent changes for regressions"
  echo "3) Run tests with more verbosity"
  echo "4) Create a bug report"
  
  # Use AskUserQuestion here
fi
```

## Step 6: Create Final Report

Generate a comprehensive QA report:

```bash
REPORT_FILE="qa-report-$(date +%Y%m%d-%H%M%S).md"

cat > "$REPORT_FILE" << EOF
# QA Report

**Date:** $(date)  
**Project:** $(basename "$(pwd)")  
**Branch:** $CURRENT_BRANCH  
**Test Framework:** $TEST_FRAMEWORK ($PROJECT_TYPE)

## Executive Summary

| Metric | Value |
|--------|-------|
| Status | $(if [[ $TEST_EXIT_CODE -eq 0 ]]; then echo "✅ PASS"; else echo "❌ FAIL"; fi) |
| Tests Passed | $PASS_COUNT |
| Tests Failed | $FAIL_COUNT |
| Tests Skipped | $SKIP_COUNT |
| Severity | ${SEVERITY:-N/A} |

## Failure Patterns

\`\`\`
$(echo "$TEST_OUTPUT" | tail -50)
\`\`\`

## Failure Patterns

$(if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "Detected patterns: ${PATTERNS_FOUND[*]:-none}"
else
  echo "No failures detected"
fi)

## Recommendations

$(if [[ $TEST_EXIT_CODE -eq 0 ]]; then
  echo "✅ All tests pass. Ready for deployment."
else
  echo "1. Address the $FAIL_COUNT failing tests"
  echo "2. Focus on ${PATTERNS_FOUND[0]:-unknown} issues first"
  echo "3. Run tests again after fixes"
fi)

## Next Steps

1. $(if [[ $TEST_EXIT_CODE -eq 0 ]]; then echo "Proceed with deployment or code review"; else echo "Fix failing tests"; fi)
2. Run tests again after fixes
3. Consider adding more test coverage for critical paths

---

*Report generated by superpowers QA skill*
EOF

echo ""
echo "📋 QA report generated: $REPORT_FILE"
```

## Step 7: Optional - Create Fix Commit

If fixes were made during QA:

```bash
if [[ -n $(git status --porcelain) ]]; then
  echo ""
  echo "Changes were made during QA. Creating fix commit..."
  
  # Check what changed
  CHANGED_FILES=$(git status --porcelain | wc -l)
  echo "$CHANGED_FILES files changed"
  
  # Create commit with QA context
  git add -A
  git commit -m "fix: address test failures identified by QA

- Fixed $FAIL_COUNT failing tests
- QA report: $REPORT_FILE"
  
  echo "✓ Fix commit created"
  
  # Run tests again to verify fixes
  echo "Running tests again to verify fixes..."
  if eval "$TEST_COMMAND"; then
    echo "✅ All tests pass after fixes!"
  else
    echo "❌ Some tests still failing after fixes"
    echo "Please review the changes and test output"
  fi
fi
```

## Usage Notes

1. **Test Framework Detection**: The skill attempts to auto-detect your test framework, but you may need to specify the test command manually.

2. **Failure Analysis**: When tests fail, the skill analyzes output for common patterns (syntax errors, import issues, timeouts, etc.)

3. **Reporting**: Always generates a detailed markdown report with recommendations.

4. **Fix Commits**: If you choose to fix issues, changes are committed with descriptive messages.

5. **Customization**: Modify the test command detection logic in Step 1 for your specific project setup.

## Examples

- `/qa` - Run tests and generate report
- `/qa --verbose` - Run tests with detailed output
- `/qa --fix` - Run tests and attempt to fix failures (interactive)