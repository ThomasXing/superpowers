# Spec: 文档技能族声明式依赖编排

> 设计日期：2026-04-30 | 状态：已批准 | 方案：方案 A — 声明式依赖标记

## 背景

当前文档技能族（document-pm/dev/test/overview/compound）之间的依赖关系是隐式的——由每个技能的正文用自然语言描述"需要先执行 document-init"，AI 自行判断。这导致：
- `document-pm` 不会自动驱动 `brainstorming` 澄清需求
- 子技能可能跳过初始化检查，直接写文件到不存在的目录
- 依赖关系散落在正文中，缺乏统一的可解析声明

## 设计方案

### `requires` 字段规范

在 `SKILL.md` 的 YAML frontmatter 中新增 `requires` 字段，支持**全局级**和**子命令级**两层依赖声明：

```yaml
---
name: document-pm
requires:
  mandatory:                        # 全局强制依赖
    - document-init
  subcommand:                       # 子命令级依赖
    generate:
      mandatory:
        - brainstorming
      optional:
        - office-hours
    upload: []
    version: []
    evaluate: []
---
```

**字段约定**：
- `mandatory`：AI 必须在执行本技能前，通过 `Skill` 工具依次调用，失败则中止
- `optional`：AI 尝试调用，失败则按技能内降级策略处理
- `subcommand`：按子命令名匹配，未声明的子命令仅检查全局依赖
- 不声明 `requires` 的旧技能不受影响，向后兼容

### 依赖关系图

```
document-init                         ← 入口，无强依赖
  ├─ document-pm                      ← requires: [document-init]
  │   ├─ generate → [brainstorming]   ← 仅生成时需要
  │   └─ upload/version/evaluate → 无额外依赖
  ├─ document-dev                     ← requires: [document-init]
  ├─ document-test                    ← requires: [document-init]
  ├─ document-overview                ← requires: [document-init]
  └─ document-compound                ← requires: [document-init]
```

### 执行流程

```
1. 读取 SKILL.md frontmatter
2. 解析 requires.mandatory + requires.subcommand[子命令].mandatory
3. 按序检查并调用 Skill 工具：
   - document-init → 幂等检查（目录存在则跳过）
   - brainstorming  → Skill 工具加载，由其内部 HARD-GATE 控制
4. optional 依赖失败 → 降级处理
5. 依赖全部通过 → 执行本技能主流程
```

### 错误处理

| 场景 | 行为 |
|------|------|
| 强制依赖 skill 未安装 | 报错中止，引导安装 |
| 强制依赖 skill 调用失败 | 报错中止 |
| 可选依赖 skill 未安装 | 静默降级 |
| `document-init` 已完成 | 跳过，不重复 |

## 实施范围

| 文件 | 变更 |
|------|------|
| `skills/document-pm/SKILL.md` | 加 `requires`；移除手动 `<HARD-GATE>` 块 |
| `skills/document-dev/SKILL.md` | 加 `requires: [document-init]` |
| `skills/document-test/SKILL.md` | 加 `requires: [document-init]` |
| `skills/document-overview/SKILL.md` | 加 `requires: [document-init]` |
| `skills/document-compound/SKILL.md` | 加 `requires: [document-init]` |
| `.qoder/skills/` | 同步更新已安装副本 |

## 方案对比（已决策）

| 方案 | 决策 |
|------|------|
| A: 声明式依赖标记 | ✅ 选中 — 最小侵入、声明即文档、向后兼容 |
| B: 文档族编排器 | ❌ 多一个维护负担，与现有直接调用冲突 |
| C: 强化 HARD-GATE | ❌ 依赖关系散落，不统一 |
