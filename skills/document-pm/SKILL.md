---
name: document-pm
description: Use when generating product requirement documents (PRD) for development projects, managing PRD versions, or when encountering ambiguous requirements that need clarification through brainstorming
---

# Document-PM - PRD文档管理独立技能

> 顶层设计是精准的需求表达，抓手是智能PRD生成，闭环是从需求澄清到文档上传的完整流程。

**⚠️ 需求不明确就是最大的技术债。颗粒度必须拉到函数级，不能模糊。**

## 概述

`document-pm` 是松立研发文档管理系统的产品需求文档管理模块，专门负责PRD（产品需求文档）的智能生成、质量评估、版本管理和文档中心同步。作为独立的技能模块，它专注于产品需求的文档化表达和团队协作。

## ⛳ 初始化配置前置检查（强制）

**执行任何 `/document-pm` 子命令前，必须先完成初始化检查**。未初始化时立即中止当前操作，引导用户执行 `/document-init`，严禁绕过。

### 必检项

- [ ] 当前处于 Git 仓库（`git rev-parse --show-toplevel` 可成功）
- [ ] `.sonli-spec-doc/config.yaml` 存在
- [ ] `storage.mode == git_repo`
- [ ] `directories.active_plan` 已设置（非空）
- [ ] `.sonli-spec-doc/<active_plan>/pm/prd/` 目录存在

### 检查脚本（AI 执行此逻辑）

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "❌ 当前不在 Git 仓库"; exit 1; }
cd "$REPO_ROOT"

CONFIG=".sonli-spec-doc/config.yaml"
[ -f "$CONFIG" ] || { echo "❌ 未检测到 $CONFIG，请先执行 /document-init '<月度计划名>'"; exit 1; }

ACTIVE_PLAN=$(grep -E '^[[:space:]]*active_plan:' "$CONFIG" | head -1 | cut -d: -f2- | cut -d'#' -f1 | tr -d '"' | tr -d "'" | xargs)
[ -n "$ACTIVE_PLAN" ] || { echo "❌ active_plan 未设置，请执行 /document-init plan '<月度计划名>'"; exit 1; }

[ -d ".sonli-spec-doc/$ACTIVE_PLAN/pm/prd" ] || { echo "❌ PRD 目录缺失：.sonli-spec-doc/$ACTIVE_PLAN/pm/prd，请重新执行 /document-init '$ACTIVE_PLAN'"; exit 1; }

echo "✅ PRD 初始化配置检查通过（活跃计划：$ACTIVE_PLAN）"
```

### 未通过时的统一响应

```
⚠️ 未检测到文档初始化配置（或活跃月度计划未设置）
原因：<config.yaml 缺失 | active_plan 未配置 | pm/prd 目录缺失>
建议：
  1. /document-init '2026年4月月度计划'   ← 首次初始化
  2. /document-init plan '2026年4月月度计划' ← 仅切换活跃计划
完成后请重新执行本命令。
```

### 理性化防护

| 漏洞 | 防护 |
|------|------|
| "先生成 PRD，事后再初始化" | 禁止：无 active_plan 时 PRD 路径无法归位 |
| "手动创建 config.yaml 绕过检查" | 禁止：必须通过 `/document-init` 保证配置闭环 |
| "把 PRD 放到任意目录" | 禁止：所有 PRD 必须归属某月度计划 `.sonli-spec-doc/<plan>/pm/prd/` |
| "需求很清楚，直接生成 PRD 就行" | 禁止：必须通过 brainstorming 澄清，避免隐性假设变成技术债 |
| "brainstorming 太慢，跳过吧" | 禁止：`<HARD-GATE>` 不可绕过。需求不明确就是最大的技术债 |
| "我已经做过头脑风暴了" | 仍需走 brainstorming 完整流程，在当前会话中呈现设计并获得批准 |

## 核心功能

### 1. 智能PRD生成（头脑风暴驱动）

<HARD-GATE>
当用户执行 `/document-pm 生成` 时，你 **必须先通过 Skill 工具调用 brainstorming 技能**，完成完整的需求澄清流程。
在 brainstorming 输出设计并获得用户批准之前，**严禁**直接生成 PRD 内容。
这是非协商的，不可绕过的。
</HARD-GATE>

**执行流程**（严格遵守）：
1. **Skill 调用**: 立即调用 `Skill` 工具加载 `brainstorming` 技能
2. **需求澄清**: 遵循 brainstorming 的完整流程（项目上下文 → 逐问题澄清 → 方案对比 → 设计呈现 → 用户批准）
3. **PRD 生成**: 仅在用户批准设计后，基于澄清结果生成完整 PRD
4. **存入目录**: 写入 `.sonli-spec-doc/<active_plan>/pm/prd/<功能名>.md`

- **格式**: `/document-pm 生成 "需求描述"`
- **自适应模板**: 基于澄清结果生成精准PRD
- **完整性检查**: 强制包含需求背景、目标、功能需求、验收标准等章节
- **兼容性**: 同时支持 `/document pm 生成 "需求描述"` 格式

### 2. PRD 上传管理（两阶段同步）
- **格式**: `/document-pm 上传 <项目文档路径>`
- **功能**: 将用户指定的 PRD 文档同步到远程文档中心仓库
- **两阶段同步流程**:
  1. **本地拷贝**：将 `<项目文档路径>` 下的 .md 文件拷贝到 `.sonli-spec-doc/<活跃计划>/pm/prd/`
  2. **远程同步**：执行 `.sonli-spec-doc/scripts/sync-to-remote.sh '<活跃计划>'`
- **命令示例**:
  ```bash
  ACTIVE_PLAN=$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)
  cp <用户指定的源路径>/*.md ".sonli-spec-doc/${ACTIVE_PLAN}/pm/prd/"
  ./.sonli-spec-doc/scripts/sync-to-remote.sh "$ACTIVE_PLAN"
  ```

### 3. PRD版本管理
- **格式**: `/document-pm 版本 [查看|回滚]`
- **功能**: 查看PRD历史版本，支持版本回滚
- **变更追踪**: 记录每次PRD变更内容和原因
- **审核追踪**: 记录评审意见和修改建议

### 4. PRD质量评估
- **格式**: `/document-pm 评估 [文档路径]`
- **功能**: 自动评估PRD完整性、一致性和可读性
- **评分体系**: 完整性评分、清晰度评分、可行性评分
- **改进建议**: 提供具体的改进建议和优化方向

## 智能降级策略

### 依赖技能不可用时的降级方案

**核心原则**: 不能因为依赖技能缺失而放弃核心功能。因为信任所以简单，但要先有底线功能。

| 依赖技能 | 降级方案 | 降级提示 |
|----------|----------|----------|
| `/brainstorming` 不可用 | **强制基础澄清**: 按 brainstorming checklist 逐项执行（项目上下文探索 → 问题澄清 → 方案对比 → 设计呈现），但提示 "brainstorming 技能未加载，使用基础需求澄清流程" |
| `/office-hours` 不可用 | **PM视角检查表**: 使用PM checklist替代 | "使用PM视角检查表，建议后续使用/office-hours更深入review" |
| `gstack` 不可用 | **技术可行性模板**: 使用通用技术评估模板 | "使用通用技术评估模板，建议后续集成gstack更精确评估" |
| 远程文档中心连接失败 | 无需网络：文档直接写入本地 `.sonli-spec-doc/` 目录，网络恢复后执行 `sync-to-remote.sh` | - |

## 脚本库集成使用（推荐）

### 推荐使用方式
```bash
# 生成 PRD 文档（AI 根据需求自动写入文件）
DOCS_PATH=".sonli-spec-doc/$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)/pm/prd"
mkdir -p "$DOCS_PATH"
# AI 将 PRD 内容写入 $DOCS_PATH/<功能名>.md

# 同步到远程文档中心仓库
./.sonli-spec-doc/scripts/sync-to-remote.sh "$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)"
```

---
**子智能体标识**: document-pm-agent  
**版本**: 3.1.0  
**创建时间**: 2026-04-22  
**依赖**: Git、远程文档中心仓库、brainstorming 技能（强制）、可选 superpowers 技能  
**状态**: 就绪  
**owner**: PRD产品经理
