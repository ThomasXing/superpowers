#!/bin/bash
# using-spec post-install hook
# When using-spec is installed via `npx skills add`, this script
# automatically installs ALL other skills from the spec-kit repository.
#
# Usage:
#   Triggered automatically by `npx skills add <repo> --skill using-spec -a qoder`
#   Can also be run manually:
#     SKILL_REPO_ROOT=/path/to/spec-kit SKILL_TARGET_DIR=.qoder/skills bash post-install.sh

set -euo pipefail

# Determine paths
# SKILL_REPO_ROOT: root of the cloned spec-kit repository (set by npx skills or fallback)
# SKILL_TARGET_DIR: where skills should be installed (set by npx skills or fallback)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Multi-level fallback to find the spec-kit repo root containing skills/:
#   1. SKILL_REPO_ROOT env var (set by npx skills add during remote install)
#   2. git rev-parse --show-toplevel (works when run inside a git repo)
#   3. Walk up from script location looking for skills/ dir AND .git marker
#   4. Current working directory
#   5. Assume 4 levels up from scripts/ (last resort)
find_repo_root() {
    # Priority 1: explicit env var from npx skills add
    if [ -n "${SKILL_REPO_ROOT:-}" ] && [ -d "$SKILL_REPO_ROOT/skills" ]; then
        echo "$SKILL_REPO_ROOT"
        return
    fi

    # Priority 2: git repo toplevel (works for local dev and most remote installs)
    local git_root
    if git_root="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -d "$git_root/skills" ]; then
        echo "$git_root"
        return
    fi

    # Priority 3: walk up from script location looking for skills/ + .git marker
    # (requires .git to avoid matching .qoder/skills/ which is not the real repo root)
    local dir="$SCRIPT_DIR"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/skills" ] && [ -f "$dir/skills/using-spec/SKILL.md" ] && [ -d "$dir/.git" ]; then
            echo "$dir"
            return
        fi
        dir="$(dirname "$dir")"
    done

    # Priority 4: check current working directory
    local cwd="$(pwd)"
    if [ -d "$cwd/skills" ] && [ -f "$cwd/skills/using-spec/SKILL.md" ]; then
        echo "$cwd"
        return
    fi

    # Priority 5: assume 4 levels up from scripts/ (local dev layout, last resort)
    echo "$(cd "$SCRIPT_DIR/../../../.." && pwd)"
}

REPO_ROOT="$(find_repo_root)"
TARGET_DIR="${SKILL_TARGET_DIR:-.qoder/skills}"

SKILLS_SOURCE="$REPO_ROOT/skills"

# Verify source exists
if [ ! -d "$SKILLS_SOURCE" ]; then
    echo "[using-spec] ERROR: Skills directory not found at $SKILLS_SOURCE"
    exit 1
fi

# Ensure target directory exists
mkdir -p "$TARGET_DIR"

echo "[using-spec] Installing all skills from spec-kit..."
echo "[using-spec] Source: $SKILLS_SOURCE"
echo "[using-spec] Target: $TARGET_DIR"
echo ""

INSTALLED=0
SKIPPED=0

for skill_dir in "$SKILLS_SOURCE"/*/; do
    [ -d "$skill_dir" ] || continue

    skill_name=$(basename "$skill_dir")

    # Skip using-spec itself (already installed by npx skills)
    if [ "$skill_name" = "using-spec" ]; then continue; fi

    # Skip directories without SKILL.md
    if [ ! -f "$skill_dir/SKILL.md" ]; then continue; fi

    # If target already exists, skip (user may have custom modifications)
    if [ -d "$TARGET_DIR/$skill_name" ]; then
        echo "  ⏭  $skill_name (already exists, skipped)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo "  ✓  $skill_name"
    cp -r "$skill_dir" "$TARGET_DIR/$skill_name"
    INSTALLED=$((INSTALLED + 1))
done

echo ""
echo "[using-spec] Done."
echo "  Installed: $INSTALLED skills"
if [ "$SKIPPED" -gt 0 ]; then
    echo "  Skipped:   $SKIPPED skills (already existed)"
fi
echo ""
echo "  All skills are now available in $TARGET_DIR/"
echo "  Restart Qoder IDE or type / in chat to see loaded skills."
