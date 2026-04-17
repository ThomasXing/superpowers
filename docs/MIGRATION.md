# gstack → superpowers 技能迁移文档

## 概述

本文档记录了从gstack项目迁移ship、qa、review三个核心技能到superpowers项目的过程和结果。

## 迁移策略

采用**适配器模式**，创建轻量级桥接层来模拟gstack的二进制工具依赖，同时增强superpowers现有技能。

### 设计原则

1. **最小侵入性**：不修改superpowers核心架构
2. **功能保留**：保持gstack核心功能可用
3. **向后兼容**：已使用superpowers的用户无影响
4. **渐进增强**：适配器可选，无适配器时降级运行

## 迁移内容

### 适配器层

| 组件 | 功能 | 实现方式 |
|------|------|----------|
| gstack-config | 配置管理 | 环境变量 + 默认值 |
| gstack-slug | 项目标识 | Git仓库目录名 |
| gstack-repo-mode | 仓库模式 | Git contributors计数 |

### 技能增强

#### ship技能增强

- ✅ 测试失败分类（in-branch vs pre-existing）
- ✅ Pre-landing security review集成
- ✅ 智能版本管理
- ✅ gstack适配器集成

#### qa技能增强

- ✅ 测试框架自动检测（10+框架）
- ✅ 失败模式分析（语法/导入/断言/超时）
- ✅ 增强报告生成
- ✅ 基于模式的修复建议

#### review技能增强

- ✅ 安全检查清单迁移
- ✅ 两遍审查法（CRITICAL → INFORMATIONAL）
- ✅ 置信度校准系统

## 未迁移功能

以下gstack功能未迁移，原因如下：

| 功能 | 原因 |
|------|------|
| 遥测系统 | 隐私考量，superpowers无遥测 |
| 学习记录 | 需要持久化存储，与superpowers架构不符 |
| 模板生成系统 | 复杂度高，维护成本大 |
| 多主机支持 | superpowers聚焦Claude Code |
| 二进制工具链 | 用适配器模拟核心功能 |

## 使用指南

### 安装验证

```bash
cd superpowers
./tests/migration-test.sh
```

### 在技能中使用适配器

```bash
# 加载适配器
ADAPTER_DIR="${HOME}/.claude/skills/superpowers/gstack-adapter/bin"
if [[ -d "$ADAPTER_DIR" ]]; then
  eval "$($ADAPTER_DIR/gstack-repo-mode 2>/dev/null)" || true
  eval "$($ADAPTER_DIR/gstack-slug 2>/dev/null)" || true
fi

# 使用配置
PROACTIVE=$("$ADAPTER_DIR/gstack-config" get proactive)
```

### 环境变量配置

```bash
# 覆盖默认配置
export GSTACK_PROACTIVE=false
export GSTACK_SKILL_PREFIX=true
```

## 测试覆盖

- [x] 适配器基础功能测试
- [x] 技能文件存在性测试
- [x] 检查清单内容测试
- [ ] 端到端工作流测试（需在真实项目中验证）
- [ ] 性能基准测试

## 已知限制

1. **无持久化配置**：gstack-config的set操作不保存
2. **简化的仓库检测**：仅基于contributors数量
3. **无学习系统**：不会记录和复用项目知识

## 后续改进

1. [ ] 添加学习记录本地存储
2. [ ] 增强仓库模式检测准确性
3. [ ] 添加更多测试框架支持
4. [ ] 实现完整的端到端测试套件

## 贡献者

迁移完成时间：2026-04-17