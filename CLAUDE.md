# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Superpowers is a plugin system for AI coding agents that provides structured development workflows through "skills". The core architecture revolves around:

- **Skills**: Modular behavior-shaping instructions in `/skills/` directory
- **Agents**: Pre-defined agent configurations in `/agents/`
- **Hooks**: Session lifecycle automation in `/hooks/`
- **Tests**: Integration tests that run real Claude Code sessions

## Core Development Workflows

### Skill Development
1. **Create new skill**: Use `superpowers:writing-skills` skill to ensure proper format and structure
2. **Test skill**: Integration tests in `/tests/claude-code/` require:
   ```bash
   cd /path/to/superpowers
   # Enable local development mode in ~/.claude/settings.json
   echo '{"enabledPlugins": {"superpowers@superpowers-dev": true}}' > ~/.claude/settings.local.json
   # Run skill test
   ./tests/claude-code/test-subagent-driven-development-integration.sh
   ```
3. **Evaluate skill changes**: Must use adversarial pressure testing across multiple sessions before submitting PRs

### Integration Testing
Tests execute real Claude Code sessions and verify:
- Skill tool was invoked correctly
- Subagents were properly dispatched
- TodoWrite tracking was used
- Implementation files were created
- Tests pass
- Git commit history shows correct workflow

**Key requirement**: Tests MUST run from the superpowers plugin directory (not temp directories).

### Token Analysis
After test runs, analyze token usage:
```bash
python3 tests/claude-code/analyze-token-usage.py ~/.claude/projects/<project-dir>/<session-id>.jsonl
```

## Key Architectural Concepts

### Skill Loading Mechanism
Skills auto-load based on file structure. Skills in `/skills/<skill-name>/SKILL.md` become available as slash commands.

### Subagent-Driven Development
The `subagent-driven-development` skill coordinates:
1. **Plan loading**: Reads plan once at beginning
2. **Full task text**: Provides complete descriptions to subagents (no file reading)
3. **Self-review**: Subagents review own work before reporting
4. **Review order**: Spec compliance review before code quality review
5. **Independent verification**: Reviewers read code independently

### Testing Philosophy
- **Zero dependencies**: Core superpowers has no external dependencies
- **Real sessions**: Tests run actual Claude Code with `--permission-mode bypassPermissions`
- **Transcript verification**: Parse `.jsonl` session files, not console output
- **Token transparency**: Show cost breakdown per subagent

## Common Development Tasks

### Running Tests
```bash
# Integration tests (10-30 minutes)
cd tests/claude-code
./test-subagent-driven-development-integration.sh

# Skill-specific tests
./test-document-review-system.sh

# All skill tests (if run-skill-tests.sh exists)
./run-skill-tests.sh
```

### Version Management
```bash
# Bump version
./scripts/bump-version.sh

# Sync to Codex plugin
./scripts/sync-to-codex-plugin.sh
```

### Local Development Setup
1. **Enable local plugin**: Add `"superpowers@superpowers-dev": true` to `~/.claude/settings.json`
2. **Run from project root**: All commands must execute from `/path/to/superpowers`
3. **Grant permissions**: Use `--permission-mode bypassPermissions` and `--add-dir` for test directories

## Project Structure

```
superpowers/
├── skills/                    # Core skill definitions
│   ├── brainstorming/        # Requirement gathering
│   ├── subagent-driven-development/  # Multi-agent coordination
│   ├── systematic-debugging/ # RCA methodology
│   ├── document/            # 松立研发文档管理 (custom skill)
│   └── ... 20+ skills
├── tests/
│   ├── claude-code/         # Integration tests
│   │   ├── test-helpers.sh
│   │   ├── analyze-token-usage.py
│   │   └── test-*.sh scripts
│   └── explicit-skill-requests/
├── docs/                    # Documentation
├── hooks/                   # Session lifecycle hooks
├── scripts/                 # Build/release scripts
└── .github/                # PR templates, issue templates
```

## 松立研发 Custom Skill: `document`
This custom skill implements GitLab Wiki-based document management:
- **Init**: `/document init <gitlab-wiki-url>`
- **PRD管理**: `/document:pm [生成|上传]`
- **功能设计**: `/document:dev [生成|上传]`
- **测试用例**: `/document:test [生成|上传]`
- **项目概览**: `/document:overview [生成|更新]`

**Testing this skill**:
```bash
# Run existing test scripts
./skills/document/test-skill.sh
./skills/document/test-workflow.sh

# Manual testing
echo "/document init https://gitlab.com/test/wiki" | claude --permission-mode bypassPermissions
```

## Critical Requirements for PRs

**Before submitting any PR, read the full contributor guidelines below. This project has a 94% PR rejection rate.**

### Mandatory Checks
1. **Real problem**: Must solve actual experienced issue, not theoretical improvements
2. **No third-party dependencies**: Core must remain zero-dependency
3. **Single focus**: One problem per PR, no bundled changes
4. **Human review**: Complete diff must be reviewed by human partner
5. **Existing PRs search**: Check both open AND closed PRs for duplicates

### Skill Changes
- **Evaluation required**: Use `superpowers:writing-skills` and show before/after results
- **No compliance rewrites**: Don't restructure skills to "comply" with external docs
- **Behavior preservation**: Don't modify carefully-tuned content without extensive evals

### What Will Be Rejected
- Domain-specific skills (should be separate plugins)
- Fork-specific changes
- Fabricated content or claims
- Bulk/spray-and-pray PRs
- Speculative or theoretical fixes

## Troubleshooting

### Skills Not Loading
```bash
# Check settings
cat ~/.claude/settings.json | grep superpowers

# Run from correct directory
pwd  # Must be /path/to/superpowers

# Use bare mode for debugging
claude --bare --permission-mode bypassPermissions
```

### Test Failures
```bash
# Increase timeout for long-running tests
timeout 1800 ./test-*.sh  # 30 minutes

# Check permissions
--permission-mode bypassPermissions --add-dir /path/to/test/dir

# Find session transcripts
find ~/.claude/projects -name "*.jsonl" -mmin -60
```

### Session File Analysis
```bash
# Decode project directory path
echo "/Users/thomasxing/workspace/2026/3月份计划/AI研发/superpowers" | sed 's/\//-/g' | sed 's/^-//'
# Result: -Users-thomasxing-workspace-2026-3月份计划-AI研发-superpowers

# Locate session file
SESSION_DIR="$HOME/.claude/projects/-Users-thomasxing-workspace-2026-3月份计划-AI研发-superpowers"
ls -lt "$SESSION_DIR"/*.jsonl | head -5
```

---

**The following section is the original contributor guidelines. Read it BEFORE making any changes:**

## Pull Request Requirements

**Every PR must fully complete the PR template.** No section may be left blank or filled with placeholder text. PRs that skip sections will be closed without review.

**Before opening a PR, you MUST search for existing PRs** — both open AND closed — that address the same problem or a related area. Reference what you found in the "Existing PRs" section. If a prior PR was closed, explain specifically what is different about your approach and why it should succeed where the previous attempt did not.

**PRs that show no evidence of human involvement will be closed.** A human must review the complete proposed diff before submission.

## What We Will Not Accept

### Third-party dependencies

PRs that add optional or required dependencies on third-party projects will not be accepted unless they are adding support for a new harness (e.g., a new IDE or CLI tool). Superpowers is a zero-dependency plugin by design. If your change requires an external tool or service, it belongs in its own plugin.

### "Compliance" changes to skills

Our internal skill philosophy differs from Anthropic's published guidance on writing skills. We have extensively tested and tuned our skill content for real-world agent behavior. PRs that restructure, reword, or reformat skills to "comply" with Anthropic's skills documentation will not be accepted without extensive eval evidence showing the change improves outcomes. The bar for modifying behavior-shaping content is very high.

### Project-specific or personal configuration

Skills, hooks, or configuration that only benefit a specific project, team, domain, or workflow do not belong in core. Publish these as a separate plugin.

### Bulk or spray-and-pray PRs

Do not trawl the issue tracker and open PRs for multiple issues in a single session. Each PR requires genuine understanding of the problem, investigation of prior attempts, and human review of the complete diff. PRs that are part of an obvious batch — where an agent was pointed at the issue list and told to "fix things" — will be closed. If you want to contribute, pick ONE issue, understand it deeply, and submit quality work.

### Speculative or theoretical fixes

Every PR must solve a real problem that someone actually experienced. "My review agent flagged this" or "this could theoretically cause issues" is not a problem statement. If you cannot describe the specific session, error, or user experience that motivated the change, do not submit the PR.

### Domain-specific skills

Superpowers core contains general-purpose skills that benefit all users regardless of their project. Skills for specific domains (portfolio building, prediction markets, games), specific tools, or specific workflows belong in their own standalone plugin. Ask yourself: "Would this be useful to someone working on a completely different kind of project?" If not, publish it separately.

### Fork-specific changes

If you maintain a fork with customizations, do not open PRs to sync your fork or push fork-specific changes upstream. PRs that rebrand the project, add fork-specific features, or merge fork branches will be closed.

### Fabricated content

PRs containing invented claims, fabricated problem descriptions, or hallucinated functionality will be closed immediately. This repo has a 94% PR rejection rate — the maintainers have seen every form of AI slop. They will notice.

### Bundled unrelated changes

PRs containing multiple unrelated changes will be closed. Split them into separate PRs.

## Skill Changes Require Evaluation

Skills are not prose — they are code that shapes agent behavior. If you modify skill content:

- Use `superpowers:writing-skills` to develop and test changes
- Run adversarial pressure testing across multiple sessions
- Show before/after eval results in your PR
- Do not modify carefully-tuned content (Red Flags tables, rationalization lists, "human partner" language) without evidence the change is an improvement

## Understand the Project Before Contributing

Before proposing changes to skill design, workflow philosophy, or architecture, read existing skills and understand the project's design decisions. Superpowers has its own tested philosophy about skill design, agent behavior shaping, and terminology (e.g., "your human partner" is deliberate, not interchangeable with "the user"). Changes that rewrite the project's voice or restructure its approach without understanding why it exists will be rejected.

## General

- Read `.github/PULL_REQUEST_TEMPLATE.md` before submitting
- One problem per PR
- Test on at least one harness and report results in the environment table
- Describe the problem you solved, not just what you changed
