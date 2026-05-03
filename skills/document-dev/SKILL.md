---
name: document-dev
description: Use when designing technical implementation details from PRD requirements, creating architecture specifications, or when encountering design ambiguity that requires systematic-debugging or code-review skills for validation
---

# Document-Dev - 功能设计文档管理独立技能

> 顶层设计是技术实现的蓝图，抓手是标准化设计模板，闭环是从PRD到详细设计的完整技术路径。

**⚠️ 设计不清晰就是技术债的源头。架构要拉通，边界要对齐。**

## 概述

`document-dev` 是松立研发文档管理系统的功能设计模块，负责将PRD需求转换为技术实现方案，创建详细的功能设计文档、架构规范和开发指南。作为工程流程的关键环节，确保技术实现与业务需求对齐。

## ⛳ 初始化配置前置检查（强制）

**执行任何 `/document-dev` 子命令前，必须先完成初始化检查**。未初始化时立即中止当前操作，引导用户执行 `/document-init`，严禁绕过。

### 必检项

- [ ] 当前处于 Git 仓库（`git rev-parse --show-toplevel` 可成功）
- [ ] `.sonli-spec-doc/config.yaml` 存在
- [ ] `storage.mode == git_repo`
- [ ] `directories.active_plan` 已设置（非空）
- [ ] `.sonli-spec-doc/<active_plan>/dev/{plans,api,tasks,review-report,test-report}/` 目录存在

### 检查脚本（AI 执行此逻辑）

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "❌ 当前不在 Git 仓库"; exit 1; }
cd "$REPO_ROOT"

CONFIG=".sonli-spec-doc/config.yaml"
[ -f "$CONFIG" ] || { echo "❌ 未检测到 $CONFIG，请先执行 /document-init '<月度计划名>'"; exit 1; }

ACTIVE_PLAN=$(grep -E '^[[:space:]]*active_plan:' "$CONFIG" | head -1 | cut -d: -f2- | cut -d'#' -f1 | tr -d '"' | tr -d "'" | xargs)
[ -n "$ACTIVE_PLAN" ] || { echo "❌ active_plan 未设置，请执行 /document-init plan '<月度计划名>'"; exit 1; }

for sub in plans api tasks review-report test-report; do
  [ -d ".sonli-spec-doc/$ACTIVE_PLAN/dev/$sub" ] || { echo "❌ 设计目录缺失：.sonli-spec-doc/$ACTIVE_PLAN/dev/$sub，请重新执行 /document-init '$ACTIVE_PLAN'"; exit 1; }
done

echo "✅ Dev 初始化配置检查通过（活跃计划：$ACTIVE_PLAN）"
```

### 未通过时的统一响应

```
⚠️ 未检测到文档初始化配置（或活跃月度计划未设置）
原因：<config.yaml 缺失 | active_plan 未配置 | dev 子目录缺失>
建议：
  1. /document-init '2026年4月月度计划'   ← 首次初始化
  2. /document-init plan '2026年4月月度计划' ← 仅切换活跃计划
完成后请重新执行本命令。
```

### 理性化防护

| 漏洞 | 防护 |
|------|------|
| "先写设计文档，事后再初始化" | 禁止：无 active_plan 时设计文档无法关联月度计划 |
| "手动创建 config.yaml 绕过检查" | 禁止：必须通过 `/document-init` 保证配置闭环 |
| "设计放在 PRD 同目录下" | 禁止：设计必须进 `dev/plans`，API 文档进 `dev/api`，便于评审和追溯 |

## 核心功能

### 1. 功能设计生成
- **格式**: `/document-dev 生成 "功能描述"`
- **输入依赖**: 自动读取相关PRD文档作为输入
- **架构设计**: 设计系统架构、模块划分、数据流图
- **详细设计**: 设计关键算法、数据结构、接口规范
- **兼容性**: 同时支持 `/document dev 生成 "功能描述"` 格式

### 2. 子文档管理
- **格式**: `/document-dev 计划|任务|报告 [子命令]`
- **需求拆解(plans)**: 将PRD拆解为可执行的技术任务
- **API接口文档(api)**: ★ 生成和管理 API 接口文档
- **任务分配(tasks)**: 创建开发任务和分配计划
- **测试验收报告(test report)**: 生成测试验收标准和报告模板
- **代码审查报告(review report)**: 生成代码审查标准和报告模板

### 3. 设计文档上传（两阶段同步）
- **格式**: `/document-dev 上传 <项目文档路径> --target <plans|api|tasks|review-report|test-report>`
- **功能**: 将用户指定的设计文档同步到远程文档中心仓库
- **两阶段同步流程**:
  1. **本地拷贝**：将 `<项目文档路径>` 下的 .md 文件拷贝到 `.sonli-spec-doc/<活跃计划>/dev/<目标子目录>/`
  2. **远程同步**：执行 `.sonli-spec-doc/scripts/sync-to-remote.sh '<活跃计划>'`
- **命令示例**:
  ```bash
  ACTIVE_PLAN=$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)
  # 上传设计文档到 dev/plans/
  cp <用户指定的源路径>/*.md ".sonli-spec-doc/${ACTIVE_PLAN}/dev/plans/"
  ./.sonli-spec-doc/scripts/sync-to-remote.sh "$ACTIVE_PLAN"
  
  # 上传 API 文档到 dev/api/
  cp <用户指定的源路径>/*.md ".sonli-spec-doc/${ACTIVE_PLAN}/dev/api/"
  ./.sonli-spec-doc/scripts/sync-to-remote.sh "$ACTIVE_PLAN"
  ```

### 4. 设计评审集成
- **格式**: `/document-dev 评审 [设计文档]`
- **代码审查集成**: 与现有代码审查技能集成
- **技术评审**: 组织技术评审会议和记录评审意见
- **设计优化**: 根据评审意见优化设计文档

## 两阶段同步使用方式

```bash
# 生成设计文档（AI 写入对应目录）
DEV_PATH=".sonli-spec-doc/$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)/dev"

# 同步设计文档到远程文档中心仓库
./.sonli-spec-doc/scripts/sync-to-remote.sh "$(grep 'active_plan:' .sonli-spec-doc/config.yaml | head -1 | cut -d: -f2- | tr -d '"' | tr -d "'" | xargs)"
```

---
**子智能体标识**: document-dev-agent  
**版本**: 3.0.0  
**创建时间**: 2026-04-22  
**依赖**: Git、远程文档中心仓库、PRD文档、superpowers技能集  
**状态**: 就绪  
**owner**: 架构师/技术负责人
