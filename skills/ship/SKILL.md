---
name: ship
version: 2.0.0
description: |
  Ship workflow: merge base branch, run tests, review diff, bump VERSION,
  update CHANGELOG, commit, push, create PR. Enhanced with gstack core features:
  test failure classification, pre-landing review integration.
  Use when asked to "ship", "deploy", "push to main", "create a PR".
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

# /ship: Enhanced Ship Workflow

This skill automates shipping code with gstack-inspired enhancements:

1. **Test Failure Classification**: Distinguishes in-branch vs pre-existing failures
2. **Pre-Landing Review**: Integrates security and quality checks
3. **Smart Version Management**: Semantic version bumping with CHANGELOG

## Adapter Integration

Load the gstack adapter for enhanced features:

```bash
# Source adapter (falls back gracefully if not available)
ADAPTER_DIR="${HOME}/.claude/skills/superpowers/gstack-adapter/bin"
if [[ -d "$ADAPTER_DIR" ]]; then
  eval "$($ADAPTER_DIR/gstack-repo-mode 2>/dev/null)" || true
  eval "$($ADAPTER_DIR/gstack-slug 2>/dev/null)" || true
else
  REPO_MODE="${REPO_MODE:-unknown}"
  SLUG="${SLUG:-$(basename "$PWD")}"
fi
```

## Prerequisites

- Git repository with a remote configured
- GitHub CLI (`gh`) installed and authenticated (for creating PRs)
- Test command defined in your project (e.g., `npm test`, `bun test`, etc.)

## Step 0: Pre-flight Checks

First, verify we're in a git repository and have the necessary tools:

```bash
# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "ERROR: Not in a git repository"
  exit 1
fi

# Check for GitHub CLI if we'll need it
if ! command -v gh &> /dev/null; then
  echo "WARNING: GitHub CLI (gh) not found. PR creation will be manual."
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Get remote URL
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
echo "Remote: $REMOTE_URL"

# Determine platform (GitHub, GitLab, or other)
if [[ "$REMOTE_URL" == *"github.com"* ]] || command -v gh &> /dev/null; then
  PLATFORM="github"
elif [[ "$REMOTE_URL" == *"gitlab"* ]] || command -v glab &> /dev/null; then
  PLATFORM="gitlab"
else
  PLATFORM="git"
fi
echo "Platform: $PLATFORM"
```

## Step 1: Detect Base Branch

Determine which branch to merge into (usually main or master):

```bash
# Try to get PR target branch (if we're on a PR branch)
if [[ "$PLATFORM" == "github" ]] && command -v gh &> /dev/null; then
  BASE_BRANCH=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null || echo "")
  if [[ -n "$BASE_BRANCH" ]]; then
    echo "Detected PR target branch: $BASE_BRANCH"
  fi
fi

# Fallback to repository's default branch
if [[ -z "$BASE_BRANCH" ]]; then
  if [[ "$PLATFORM" == "github" ]] && command -v gh &> /dev/null; then
    BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "")
  fi
fi

# Git-native fallback
if [[ -z "$BASE_BRANCH" ]]; then
  BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "")
  if [[ -z "$BASE_BRANCH" ]]; then
    # Try main, then master
    if git rev-parse --verify origin/main > /dev/null 2>&1; then
      BASE_BRANCH="main"
    elif git rev-parse --verify origin/master > /dev/null 2>&1; then
      BASE_BRANCH="master"
    else
      BASE_BRANCH="main"
    fi
  fi
fi

echo "Base branch: $BASE_BRANCH"
```

## Step 2: Check Working Tree Status

Make sure we have a clean working tree before proceeding:

```bash
# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
  echo "ERROR: Working tree has uncommitted changes."
  echo "Please commit or stash your changes before shipping."
  exit 1
fi

# Check if we're already up to date with remote
git fetch origin
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/$CURRENT_BRANCH 2>/dev/null || echo "")
if [[ -n "$REMOTE_COMMIT" && "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]]; then
  echo "WARNING: Local branch differs from remote. Consider pulling first."
fi
```

## Step 3: Merge Base Branch

Merge the base branch to ensure we're testing against the latest code:

```bash
echo "Merging $BASE_BRANCH into $CURRENT_BRANCH..."
git merge --no-ff origin/$BASE_BRANCH
if [[ $? -ne 0 ]]; then
  echo "ERROR: Merge conflict detected. Please resolve conflicts and try again."
  exit 1
fi
echo "Merge successful"
```

## Step 4: Run Tests

Run the project's tests to ensure everything works:

```bash
echo "Running tests..."

# First check if there's a test command in package.json
if [[ -f "package.json" ]]; then
  if grep -q '"test"' package.json; then
    TEST_CMD=$(node -e "console.log(JSON.parse(require('fs').readFileSync('package.json', 'utf8')).scripts.test || '')")
    if [[ -n "$TEST_CMD" ]]; then
      echo "Found test command in package.json: $TEST_CMD"
      eval "$TEST_CMD"
      TEST_EXIT=$?
    fi
  fi
fi

# If no test command found or package.json doesn't exist, try common test commands
if [[ ! -f "package.json" ]] || [[ -z "$TEST_CMD" ]] || [[ $TEST_EXIT -ne 0 ]]; then
  echo "Trying common test commands..."
  
  # Try bun test
  if command -v bun &> /dev/null && [[ -f "bun.lockb" || -f "bun.lock" ]]; then
    bun test
    TEST_EXIT=$?
  # Try npm test
  elif command -v npm &> /dev/null && [[ -f "package.json" ]]; then
    npm test
    TEST_EXIT=$?
  # Try yarn test
  elif command -v yarn &> /dev/null && [[ -f "yarn.lock" ]]; then
    yarn test
    TEST_EXIT=$?
  # Try pnpm test
  elif command -v pnpm &> /dev/null && [[ -f "pnpm-lock.yaml" ]]; then
    pnpm test
    TEST_EXIT=$?
  # Try make test
  elif [[ -f "Makefile" ]] && grep -q "^test:" Makefile; then
    make test
    TEST_EXIT=$?
  else
    echo "WARNING: No test command found. Please add tests to your project."
    echo "Continue without tests? This is not recommended for production code."
    # Use AskUserQuestion to ask user
    exit 1
  fi
fi

if [[ $TEST_EXIT -ne 0 ]]; then
  echo "ERROR: Tests failed. Please fix the failing tests before shipping."
  exit 1
fi

echo "Tests passed ✓"
```

## Step 4.5: Test Failure Classification (gstack-inspired)

If tests failed, classify the failures:

```bash
if [[ $TEST_EXIT -ne 0 ]]; then
  echo ""
  echo "=== TEST FAILURE CLASSIFICATION ==="
  
  # Get files changed on this branch
  CHANGED_FILES=$(git diff --name-only "origin/$BASE_BRANCH" 2>/dev/null || git diff --name-only "$BASE_BRANCH")
  
  # Separate test files from source files
  CHANGED_TEST_FILES=$(echo "$CHANGED_FILES" | grep -E "(test|spec|Test|Spec)" || echo "")
  CHANGED_SOURCE_FILES=$(echo "$CHANGED_FILES" | grep -vE "(test|spec|Test|Spec)" || echo "")
  
  IN_BRANCH_FAILURES=false
  PRE_EXISTING_FAILURES=false
  
  # Check if any test files were modified
  if [[ -n "$CHANGED_TEST_FILES" ]]; then
    IN_BRANCH_FAILURES=true
    echo "⚠️  Test files modified in this branch:"
    echo "$CHANGED_TEST_FILES"
  fi
  
  # Determine ownership
  if [[ "$REPO_MODE" == "solo" ]]; then
    echo ""
    echo "Solo repository detected. You own these failures."
    echo "Recommendation: Fix now while context is fresh."
  elif [[ "$REPO_MODE" == "collaborative" ]]; then
    echo ""
    echo "Collaborative repository. Failures may be someone else's responsibility."
    echo "Recommendation: Investigate first, assign if pre-existing."
  fi
  
  echo ""
  echo "What would you like to do?"
  echo "1) Investigate and fix now (recommended)"
  echo "2) Add as P0 TODO and proceed"
  echo "3) Skip and ship anyway (not recommended)"
  
  # Use AskUserQuestion in actual implementation
  echo "ERROR: Tests failed. Please fix the failing tests before shipping."
  exit 1
fi
```

## Step 5: Update Version (Optional)

Check if there's a VERSION file and bump it:

```bash
if [[ -f "VERSION" ]]; then
  echo "Found VERSION file"
  CURRENT_VERSION=$(cat VERSION)
  echo "Current version: $CURRENT_VERSION"
  
  # Parse version (assuming format like 1.2.3 or 1.2.3.4)
  if [[ "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(\.([0-9]+))?$ ]]; then
    MAJOR=${BASH_REMATCH[1]}
    MINOR=${BASH_REMATCH[2]}
    PATCH=${BASH_REMATCH[3]}
    BUILD=${BASH_REMATCH[5]}
    
    echo "Select version bump type:"
    echo "1) Patch (${MAJOR}.${MINOR}.$((PATCH+1))) - bug fixes"
    echo "2) Minor (${MAJOR}.$((MINOR+1)).0) - new features, backwards compatible"
    echo "3) Major ($((MAJOR+1)).0.0) - breaking changes"
    echo "4) Keep current version (${CURRENT_VERSION})"
    
    # Use AskUserQuestion to get version bump choice
    # For now, default to patch bump
    NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH+1))"
    if [[ -n "$BUILD" ]]; then
      NEW_VERSION="${NEW_VERSION}.0"
    fi
    
    echo "Updating VERSION to $NEW_VERSION"
    echo "$NEW_VERSION" > VERSION
    VERSION_BUMPED=true
  else
    echo "WARNING: VERSION file doesn't match expected format. Skipping version bump."
    VERSION_BUMPED=false
  fi
else
  echo "No VERSION file found. Skipping version bump."
  VERSION_BUMPED=false
fi
```

## Step 4.6: Pre-Landing Review (gstack-inspired)

Run quick security review before shipping:

```bash
echo ""
echo "=== PRE-LANDING REVIEW ==="

# Check if review skill exists
REVIEW_CHECKLIST="${HOME}/.claude/skills/superpowers/skills/review/checklist.md"
if [[ ! -f "$REVIEW_CHECKLIST" ]]; then
  REVIEW_CHECKLIST="superpowers/skills/review/checklist.md"
fi

if [[ -f "$REVIEW_CHECKLIST" ]]; then
  echo "Loading review checklist..."
  # In actual implementation, invoke /review skill
  echo "Run /review for detailed security analysis"
else
  echo "Review checklist not found. Skipping enhanced review."
fi

# Quick security scan (always run)
CRITICAL_PATTERNS=(
  "password.*=.*['\"]"
  "secret.*=.*['\"]"
  "api.*key.*=.*['\"]"
  "exec.*\\$\\("
  "system.*\\$\\("
)

DIFF_CONTENT=$(git diff "origin/$BASE_BRANCH" 2>/dev/null || git diff "$BASE_BRANCH")
CRITICAL_FOUND=false

for pattern in "${CRITICAL_PATTERNS[@]}"; do
  if echo "$DIFF_CONTENT" | grep -qE "$pattern"; then
    CRITICAL_FOUND=true
    echo "⚠️  Potential security issue detected: $pattern"
  fi
done

if [[ "$CRITICAL_FOUND" == "true" ]]; then
  echo ""
  echo "Security concerns detected. Review before shipping."
fi
```

## Step 6: Update CHANGELOG (Optional)

If there's a CHANGELOG.md, update it with the new version:

```bash
if [[ -f "CHANGELOG.md" ]] && [[ "$VERSION_BUMPED" == "true" ]]; then
  echo "Updating CHANGELOG.md..."
  TODAY=$(date +%Y-%m-%d)
  
  # Check if today's date already has an entry
  if ! grep -q "^## \[$NEW_VERSION\] - $TODAY" CHANGELOG.md; then
    # Create a template entry
    TEMPLATE="## [$NEW_VERSION] - $TODAY\n\n### Added\n- \n\n### Changed\n- \n\n### Fixed\n- \n\n### Removed\n- \n"
    
    # Insert at the beginning of the file (after the header)
    if [[ -f "CHANGELOG.md" ]]; then
      # Read existing content
      CONTENT=$(cat CHANGELOG.md)
      # Insert new entry after the first heading (usually # Changelog)
      NEW_CONTENT=$(echo "$CONTENT" | sed "/^# /a\\\n$TEMPLATE")
      echo "$NEW_CONTENT" > CHANGELOG.md
      echo "CHANGELOG updated with template for version $NEW_VERSION"
    fi
  else
    echo "CHANGELOG already has an entry for $NEW_VERSION on $TODAY"
  fi
elif [[ -f "CHANGELOG.md" ]]; then
  echo "CHANGELOG.md exists but version not bumped. Skipping CHANGELOG update."
else
  echo "No CHANGELOG.md found. Skipping."
fi
```

## Step 7: Commit Changes

Commit all changes (merge, version bump, changelog):

```bash
echo "Creating commit..."
git add -A

# Generate commit message
COMMIT_MSG="chore: ship changes"
if [[ "$VERSION_BUMPED" == "true" ]]; then
  COMMIT_MSG="chore: release $NEW_VERSION"
fi

git commit -m "$COMMIT_MSG"
if [[ $? -ne 0 ]]; then
  echo "WARNING: Nothing to commit (no changes after merge)"
fi
```

## Step 8: Push to Remote

Push the current branch to origin:

```bash
echo "Pushing to origin/$CURRENT_BRANCH..."
git push origin "$CURRENT_BRANCH"
if [[ $? -ne 0 ]]; then
  echo "ERROR: Failed to push. Check your permissions or network connection."
  exit 1
fi
echo "Push successful ✓"
```

## Step 9: Create Pull/Merge Request

Create a PR/MR if not already on the base branch:

```bash
if [[ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]]; then
  echo "Creating pull request for $CURRENT_BRANCH → $BASE_BRANCH..."
  
  if [[ "$PLATFORM" == "github" ]] && command -v gh &> /dev/null; then
    # Generate PR title from commits
    PR_TITLE=$(git log --oneline --reverse origin/$BASE_BRANCH..HEAD | head -5 | sed 's/^[a-f0-9]* //' | head -1)
    if [[ -z "$PR_TITLE" ]]; then
      PR_TITLE="Merge $CURRENT_BRANCH into $BASE_BRANCH"
    fi
    
    # Generate PR body from commit messages
    PR_BODY=$(git log --oneline --reverse origin/$BASE_BRANCH..HEAD | sed 's/^[a-f0-9]* /* /' | head -20)
    
    # Create PR
    gh pr create --title "$PR_TITLE" --body "$PR_BODY" --base "$BASE_BRANCH"
    if [[ $? -eq 0 ]]; then
      echo "Pull request created successfully ✓"
    else
      echo "WARNING: Failed to create PR via GitHub CLI. Please create manually."
    fi
    
  elif [[ "$PLATFORM" == "gitlab" ]] && command -v glab &> /dev/null; then
    # GitLab MR
    glab mr create --title "Merge $CURRENT_BRANCH into $BASE_BRANCH" --description "Automated merge request" --target-branch "$BASE_BRANCH"
    if [[ $? -eq 0 ]]; then
      echo "Merge request created successfully ✓"
    else
      echo "WARNING: Failed to create MR via GitLab CLI. Please create manually."
    fi
    
  else
    echo "Please create a pull/merge request manually:"
    echo "  Branch: $CURRENT_BRANCH → $BASE_BRANCH"
    if [[ -n "$PR_TITLE" ]]; then
      echo "  Title: $PR_TITLE"
    fi
    if [[ -n "$PR_BODY" ]]; then
      echo "  Body:"
      echo "$PR_BODY"
    fi
  fi
else
  echo "Already on base branch ($BASE_BRANCH). No PR needed."
fi
```

## Step 10: Summary

Provide a summary of what was done:

```bash
echo ""
echo "=== Ship Summary ==="
echo "• Merged $BASE_BRANCH into $CURRENT_BRANCH"
echo "• Ran tests: $( [[ $TEST_EXIT -eq 0 ]] && echo 'PASSED' || echo 'FAILED' )"
if [[ "$VERSION_BUMPED" == "true" ]]; then
  echo "• Bumped version: $CURRENT_VERSION → $NEW_VERSION"
  echo "• Updated CHANGELOG.md"
fi
echo "• Committed changes"
echo "• Pushed to origin/$CURRENT_BRANCH"
if [[ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]]; then
  echo "• Created pull/merge request"
fi
echo "==================="
```

## Important Notes

1. **Tests are required** - The skill will fail if tests don't pass
2. **Clean working tree** - You must commit or stash changes before shipping
3. **GitHub/GitLab CLI** - Required for automatic PR/MR creation
4. **Version bump** - Only works with VERSION file in standard format
5. **CHANGELOG** - Template-based update, you'll need to fill in the details

## Customization

To customize this skill for your project:
1. Modify the test command detection logic in Step 4
2. Adjust version bump logic in Step 5 for your version format
3. Update CHANGELOG template in Step 6
4. Customize commit message format in Step 7