# gstack 完整集成说明（Full Integration）

本文档说明 **spec-kit ↔ gstack** 完整集成（Option Y）的构成、安装、使用与回滚方式。

## 1. 集成范围

本仓库已从上游 [garrytan/gstack@main](https://github.com/garrytan/gstack) 移植以下能力，使 `/qa` 和 `/browse` 具备 gstack 原版的完整工作流：

| 子系统 | 位置 | 说明 |
|---|---|---|
| **bin 脚本**（13 个） | `bin/gstack-*` | 配置/slug/timeline/learnings/diff-scope 等基础设施 |
| **browse 子系统** | `browse/` | headless 浏览器 daemon，约 46 个 TS（~19k 行）+ 39 个测试 |
| **/qa 技能** | `skills/qa/SKILL.md` | gstack v2.0.0 原版（1567 行，含 spec-kit 路径 shim） |
| **/browse 技能** | `skills/browse/SKILL.md` | gstack v1.1.0 镜像（839 行，含 spec-kit 路径 shim） |
| **安装脚本** | `scripts/install-gstack-full.sh` | bun/chromium 检测 + 依赖安装 + 编译 |
| **运行时状态** | `~/.gstack/` | 用户级目录，已在 `.gitignore` 中声明 |

完整依赖清单（`bun install` 时下载，约 500MB–2GB）：

- `playwright` ^1.58.2
- `puppeteer-core` ^24.40.0
- `@huggingface/transformers` ^4.1.0
- `@ngrok/ngrok` ^1.7.0
- `marked` ^18.0.2
- `diff` ^7.0.0

## 2. 快速开始

```bash
# 1) 一次性安装（交互式）
./scripts/install-gstack-full.sh

# 非交互式：
./scripts/install-gstack-full.sh --yes

# 2) 在 Claude Code 中使用
/qa           # gstack v2 完整 Test→Fix→Verify 循环
/browse       # 浏览器 daemon，100ms/命令
```

## 3. 路径适配机制

gstack 原版假设安装在 `~/.claude/skills/gstack/`。spec-kit 集成场景下，脚本位于 repo 根的 `bin/`，因此所有 SKILL.md 的 Preamble 使用如下解析优先级：

```
$GSTACK_BIN (env override)
  → <git-root>/bin              # spec-kit 集成
  → ~/.claude/skills/gstack/bin # gstack 原版全局安装
  → .claude/skills/gstack/bin   # vendored 安装
```

同样逻辑出现在以下位置：

- `browse/src/project-slug.ts`：查找 `gstack-slug` 二进制
- `browse/src/server.ts`：welcome.html 回退路径
- `browse/bin/find-browse`：browse daemon 发现链

## 4. 回滚方式

集成前打了 tag：

```bash
git log pre-gstack-full-integration..HEAD --oneline
```

如需回滚：

```bash
git reset --hard pre-gstack-full-integration
rm -rf ~/.gstack      # 可选：清理运行时状态
```

## 5. 与 upstream superpowers 的兼容性

**本集成与 upstream `obra/superpowers` 的 zero-dependency 原则直接冲突**：

- 引入 bun / playwright / puppeteer 等运行时依赖
- 引入 ~29MB 的 browse 源码
- 改写 `/qa` 到外部脚本绑定形式（`$GSTACK_BIN/...`）

因此本分支**不应 PR 回 upstream**，只能作为独立 fork / 内部分支保留。

## 6. Commit 清单

Phase 1：基线

- `pre-gstack-full-integration`（tag） — 回滚点

Phase 2（3 commits）：bin 脚本移植

- `feat(bin): port gstack core scripts (config/slug/repo-mode/settings-hook)`
- `feat(bin): port gstack timeline + learnings scripts`
- `feat(bin): port gstack auxiliary scripts (diff-scope/open-url/question/session-update)`

Phase 3（1 commit）：browse 子系统

- `feat(browse): port gstack browse subsystem with spec-kit path adaptation`

Phase 4（1 commit）：/qa 技能重写

- `feat(qa): rewrite skills/qa to gstack v2.0.0 verbatim form`

Phase 5（1 commit）：/browse 技能 + install 脚本

- `feat(skills+scripts): register /browse skill and install-gstack-full.sh`

Phase 6（本 commit）：文档

- `docs: add gstack full integration guide`

## 7. 已知限制与后续步骤

- `bun install` 未自动执行，留给 operator 按需启动
- `/browse` 端到端验证需要 Chromium + Playwright bundled browser 真实启动
- `browse/test/` 39 个 bun test 需要 `bun install` 后再跑
- 回归测试：`bun run browse:test`

## 8. 相关文档

- `skills/qa/SKILL.md` — /qa 完整工作流（1567 行）
- `skills/qa/references/issue-taxonomy.md` — 缺陷分类法（含 CLI vs Browser 边界）
- `skills/qa/references/fix-loop-checklist.md` — Fix Loop 自检清单
- `skills/qa/templates/qa-report-template.md` — QA 报告模板
- `skills/browse/SKILL.md` — /browse 命令参考
- `browse/SKILL.md` — browse daemon 开发者文档（与 skills/browse/ 同步）
