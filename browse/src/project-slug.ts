/**
 * Project slug resolution for the browse daemon.
 *
 * Used by domain-skills (per-project storage) and sidebar prompt-context
 * injection. Cached after first call — slug is derived from the daemon's
 * git remote (or env override) and doesn't change between commands.
 */

import * as path from 'path';
import * as os from 'os';
import { execSync } from 'child_process';

let cachedSlug: string | null = null;

export function getCurrentProjectSlug(): string {
  if (cachedSlug) return cachedSlug;
  const explicit = process.env.GSTACK_PROJECT_SLUG;
  if (explicit) {
    cachedSlug = explicit;
    return explicit;
  }
  try {
    // Resolution order (spec-kit integration of gstack):
    //   1. $GSTACK_BIN_DIR/gstack-slug                    — explicit override
    //   2. <git-root>/bin/gstack-slug                     — spec-kit layout
    //   3. ~/.claude/skills/gstack/bin/gstack-slug        — upstream gstack
    let slugBin: string | null = null;
    const binDir = process.env.GSTACK_BIN_DIR;
    if (binDir) {
      slugBin = path.join(binDir, 'gstack-slug');
    } else {
      try {
        const gitRoot = execSync('git rev-parse --show-toplevel', { encoding: 'utf8', timeout: 1000 }).trim();
        const candidate = path.join(gitRoot, 'bin', 'gstack-slug');
        if (require('fs').existsSync(candidate)) slugBin = candidate;
      } catch { /* not in a git repo — fall through */ }
      if (!slugBin) {
        slugBin = path.join(os.homedir(), '.claude/skills/gstack/bin/gstack-slug');
      }
    }
    const out = execSync(slugBin, { encoding: 'utf8', timeout: 2000 }).trim();
    const m = out.match(/SLUG="?([^"\n]+)"?/);
    cachedSlug = m ? m[1]! : (out || 'unknown');
  } catch {
    cachedSlug = 'unknown';
  }
  return cachedSlug;
}

/** Reset cache; for tests only. */
export function _resetProjectSlugCache(): void {
  cachedSlug = null;
}
