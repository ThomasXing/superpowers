# gstack-adapter

轻量级适配器层，将gstack核心功能桥接到superpowers项目。

## 设计理念

gstack依赖17个二进制工具（`gstack-*`），superpowers采用纯技能架构。
适配器模拟gstack核心工具的接口，但使用纯bash实现，无需外部依赖。

## 适配器列表

| 工具 | 功能 | 实现状态 |
|------|------|----------|
| gstack-config | 配置管理 | ✅ 已实现 |
| gstack-slug | 项目slug生成 | ✅ 已实现 |
| gstack-repo-mode | 仓库模式检测 | ✅ 已实现 |

## 使用方法

在技能文件中调用：

```bash
# 获取配置值
~/.claude/skills/superpowers/gstack-adapter/bin/gstack-config get proactive

# 获取项目slug
~/.claude/skills/superpowers/gstack-adapter/bin/gstack-slug
```

## 与原生gstack的区别

1. **无全局状态**：不使用`~/.gstack/`目录，配置通过环境变量
2. **简化遥测**：不发送遥测数据
3. **无学习记录**：不持久化学习数据
