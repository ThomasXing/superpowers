#!/usr/bin/env bash
# install-gstack-full.sh — Set up the gstack full-integration for spec-kit.
#
# What this script does:
#   1. Verify required runtimes: bun >= 1.0, node, chromium/chrome
#   2. Create ~/.gstack/ state directory
#   3. bun install inside browse/ (downloads playwright, puppeteer-core,
#      @huggingface/transformers, marked, diff, ngrok — ~500MB-2GB)
#   4. bun run build to compile browse/dist/browse (and find-browse) binaries
#   5. Optional: register the SessionStart hook via gstack-settings-hook
#
# Usage:
#   ./scripts/install-gstack-full.sh            # interactive, asks before heavy steps
#   ./scripts/install-gstack-full.sh --yes      # non-interactive, accept all defaults
#   ./scripts/install-gstack-full.sh --skip-build  # install deps only (no build)
#   ./scripts/install-gstack-full.sh --skip-deps   # build only (deps assumed present)
#
# Exit codes:
#   0 success
#   1 missing runtime
#   2 user aborted
#   3 install/build failed

set -euo pipefail

YES=0
SKIP_BUILD=0
SKIP_DEPS=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) YES=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --skip-deps) SKIP_DEPS=1 ;;
    --help|-h)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)
      echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

# ── Colors ──────────────────────────────────────
if [ -t 1 ]; then
  B="$(printf '\033[1m')"; G="$(printf '\033[32m')"; Y="$(printf '\033[33m')"
  R="$(printf '\033[31m')"; N="$(printf '\033[0m')"
else
  B=""; G=""; Y=""; R=""; N=""
fi

info()  { echo "${B}▸${N} $*"; }
ok()    { echo "${G}✓${N} $*"; }
warn()  { echo "${Y}!${N} $*"; }
fail()  { echo "${R}✗${N} $*" >&2; }

confirm() {
  local prompt="$1"
  if [ "$YES" -eq 1 ]; then return 0; fi
  read -r -p "$prompt [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# ── Step 1: runtime checks ─────────────────────
info "Step 1/5  checking required runtimes"

if ! command -v bun >/dev/null 2>&1; then
  fail "bun is required but not installed. Install: https://bun.sh"
  exit 1
fi
BUN_VER=$(bun --version 2>/dev/null || echo "0")
ok "bun $BUN_VER"

if ! command -v node >/dev/null 2>&1; then
  warn "node not found — some gstack helpers (gstack-settings-hook) will still work via bun"
else
  ok "node $(node --version)"
fi

# Chromium / Chrome — needed for browse end-to-end
CHROME_BIN=""
for cand in \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "$(command -v google-chrome 2>/dev/null)" \
  "$(command -v chromium 2>/dev/null)" \
  "$(command -v chromium-browser 2>/dev/null)"; do
  if [ -n "$cand" ] && [ -x "$cand" ]; then CHROME_BIN="$cand"; break; fi
done
if [ -z "$CHROME_BIN" ]; then
  warn "Chrome / Chromium not found. /browse will work in headless mode only via Playwright's bundled chromium (installed during bun install)."
else
  ok "chrome: $CHROME_BIN"
fi

# ── Step 2: state dir ──────────────────────────
info "Step 2/5  creating ~/.gstack state directory"
mkdir -p "$HOME/.gstack/sessions" "$HOME/.gstack/analytics" "$HOME/.gstack/projects"
ok "~/.gstack/ ready"

# ── Step 3: bun install ────────────────────────
if [ "$SKIP_DEPS" -eq 1 ]; then
  info "Step 3/5  skipping dependency install (--skip-deps)"
else
  info "Step 3/5  installing browse/ dependencies"
  warn "this downloads several hundred MB — playwright + puppeteer-core + transformers"
  if ! confirm "Proceed with bun install?"; then
    warn "aborted by user"; exit 2
  fi

  # gstack's package.json lives at repo root; but we only ported browse/.
  # If a top-level package.json isn't present, we create a minimal one that
  # scopes to browse/'s needs. This is a spec-kit adaptation.
  if [ ! -f package.json ]; then
    warn "no package.json at repo root — creating minimal browse-only package.json"
    cat > package.json <<'JSON'
{
  "name": "spec-kit-gstack-integration",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "browse:dev": "bun run browse/src/cli.ts",
    "browse:server": "bun run browse/src/server.ts",
    "browse:build": "bun build --compile browse/src/cli.ts --outfile browse/dist/browse && bun build --compile browse/src/find-browse.ts --outfile browse/dist/find-browse && chmod +x browse/dist/browse browse/dist/find-browse",
    "browse:test": "bun test browse/test/"
  },
  "dependencies": {
    "@huggingface/transformers": "^4.1.0",
    "@ngrok/ngrok": "^1.7.0",
    "diff": "^7.0.0",
    "marked": "^18.0.2",
    "playwright": "^1.58.2",
    "puppeteer-core": "^24.40.0"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "@types/node": "latest"
  }
}
JSON
  fi
  bun install || { fail "bun install failed"; exit 3; }
  ok "dependencies installed"
fi

# ── Step 4: bun run build ──────────────────────
if [ "$SKIP_BUILD" -eq 1 ]; then
  info "Step 4/5  skipping build (--skip-build)"
else
  info "Step 4/5  compiling browse/dist/ binaries"
  if ! confirm "Proceed with bun build (creates browse/dist/browse and find-browse)?"; then
    warn "aborted by user"; exit 2
  fi
  bun run browse:build || { fail "bun build failed"; exit 3; }
  ok "browse binaries built: $(ls -1 browse/dist/ 2>/dev/null | tr '\n' ' ')"
fi

# ── Step 5: verify end-to-end ──────────────────
info "Step 5/5  sanity checks"
if [ -x bin/gstack-slug ]; then
  ok "gstack-slug → $(./bin/gstack-slug | head -1)"
else
  fail "bin/gstack-slug missing — did the Phase 2 port run?"
fi

if [ -x browse/dist/browse ]; then
  ok "browse CLI ready: browse/dist/browse"
  echo
  echo "  Quick start:"
  echo "    ./browse/dist/browse launch"
  echo "    ./browse/dist/browse navigate https://example.com"
  echo "    ./browse/dist/browse snapshot"
else
  warn "browse binary not built (re-run without --skip-build to compile)"
fi

echo
ok "gstack full integration install complete."
echo "  Skills:  /qa  /browse"
echo "  Bin:     $(ls -1 bin/ 2>/dev/null | wc -l | tr -d ' ') gstack-* scripts"
echo "  State:   ~/.gstack/  (per-user, gitignored)"
echo "  Docs:    docs/gstack-full-integration.md"
