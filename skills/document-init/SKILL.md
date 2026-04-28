---
name: document-init
description: Use when setting up a new GitLab Wiki repository for team documentation, configuring the document management system for the first time, or when encountering "GitLab CLI not found" or "authentication failed" errors during initialization
---

# Document-Init - GitLab Wiki 仓库初始化与管理

> 顶层设计是统一的配置管理，抓手是 GitLab Wiki 集成，闭环是团队文档目录标准化。

**⚠️ 红牌警告**：没有完成配置就跳过初始化是技术债，必须清零。3.25必须对齐，owner意识要到位。

## 概述

`document-init` 是松立研发文档管理系统的核心配置模块，负责团队 GitLab Wiki 仓库的初始化、认证配置和目录结构标准化。作为其他 document 模块的基础设施，确保所有文档模块共享一致的配置和目录规范。

## 核心功能

### 1. GitLab Wiki 仓库关联
- **格式**：`/document-init <gitlab-wiki-url>`
- **功能**：关联团队的 GitLab Wiki 仓库到本地文档系统
- **兼容性**：同时支持 `/document init <gitlab-wiki-url>` 格式
- **配置存储**：创建 `.sonli-spec-doc/config.json` 存储配置信息

### 2. GitLab CLI 认证管理
- **自动检测**：检查 `glab` CLI 工具是否已安装
- **认证引导**：指导用户完成 GitLab 认证配置
- **权限验证**：验证用户对 Wiki 仓库的读写权限
- **环境检查**：检查网络连接和 API 访问状态

### 3. 目录结构标准化
```
wit-parking-wiki/              # GitLab Wiki项目协作文档目录
├── pm/
│   └── prd/                   # 产品需求文档
├── dev/
│   ├── plans/                # 需求拆解
│   ├── tasks/                # 任务分配
│   ├── test report/          # 测试验收报告
│   └── review report/        # 代码审查报告
├── test/
│   ├── testcases/            # 测试用例
│   └── test report/          # 测试验收报告
├── knowledge-base/
│   └── compound/             # 开发经验总结
├── DESIGN.md                 # UI/UX设计规范
├── overview.md               # 项目进度报告
└── CHANGELOG.md             # 项目变更日志
```

## 配置完整性检查表

**没有检查就是没有闭环，必须强制执行：**

- [ ] GitLab CLI 安装验证：调用 `scripts/gitlab/common.sh` 中的 `check_glab_installed()` 函数
- [ ] 认证状态检查：调用 `scripts/gitlab/auth.sh` 中的 `check_auth_status()` 函数
- [ ] 网络连接测试：调用 `scripts/gitlab/common.sh` 中的 `check_network()` 函数
- [ ] 仓库权限验证：使用脚本库的仓库验证功能
- [ ] 配置文件创建：调用 `scripts/gitlab/common.sh` 中的 `check_config_dir()` 和 `write_config()` 函数
- [ ] 目录结构创建：调用 `scripts/document/init.sh` 中的 `create_standard_directories()` 函数
- [ ] 连接健康检查：使用脚本库的健康检查功能
- [ ] 回滚机制：保存初始化前状态

**任何一项失败都必须修复，不能跳过。因为信任所以简单，但要先验证信任。**

## 使用说明

### 初始化命令
```bash
# 连字符格式（推荐）
/document-init https://gitlab.com/团队/wit-parking-wiki

# 空格格式（兼容）
/document init https://gitlab.com/团队/wit-parking-wiki
```

### 配置检查
```bash
# 查看当前配置
/document-init status

# 验证连接
/document-init verify

# 重置配置
/document-init reset
```

### 初始化流程
1. **环境检查** → 2. **认证配置** → 3. **仓库关联** → 4. **目录创建** → 5. **配置验证** → 6. **完整性检查**

**每一步必须完成，不能以"后面可以补"为借口跳过。中途失败必须从第一步重新开始，不能"差不多就行"。**

## 常见的理性化漏洞及防护

| 漏洞 | 防护措施 |
|------|----------|
| "GitLab CLI没装，先跳过吧" | **立即安装，没有跳过选项** |
| "认证太麻烦，后面再弄" | **立即引导认证，没有延迟选项** |
| "网络连不上，先本地存着" | **必须验证连接，否则提供真实错误** |
| "配置有点问题，先凑合用" | **强制修复，不能凑合** |
| "感觉可以了，不用再检查" | **强制完整性检查，不靠感觉** |

**理性化都是技术债的根源。今天不闭环，明天就难还债。**

## 目录结构规范

初始化后创建的目录结构：
```
wit-parking-wiki/              # GitLab Wiki项目协作文档目录
├── pm/
│   └── prd/                   # 产品需求文档
├── dev/
│   ├── plans/                # 需求拆解
│   ├── tasks/                # 任务分配
│   ├── test report/          # 测试验收报告
│   └── review report/        # 代码审查报告
├── test/
│   ├── testcases/            # 测试用例
│   └── test report/          # 测试验收报告
├── knowledge-base/
│   └── compound/             # 开发经验总结
├── DESIGN.md                 # UI/UX设计规范
├── overview.md               # 项目进度报告
└── CHANGELOG.md             # 项目变更日志
```

## 错误处理

### 常见错误及解决方案
1. **GitLab CLI未安装**：
   ```bash
   # 使用脚本库统一安装说明
   source scripts/gitlab/common.sh
   check_glab_installed  # 会自动显示安装命令
   ```

2. **认证失败**：
   ```bash
   # 使用脚本库交互式认证
   source scripts/gitlab/auth.sh
   glab_auth_interactive
   ```

3. **仓库不存在或无权限**：
   - 检查URL是否正确
   - 确认仓库访问权限
   - 提示用户创建仓库

4. **网络连接问题**：
   - 检查网络连接
   - 验证代理设置
   - 提供离线模式选项

### 降级策略
- **离线模式**：本地初始化，稍后同步
- **最小配置**：只创建必要目录结构
- **分步执行**：允许用户手动完成失败步骤

### 3. 脚本库集成使用（推荐）

**底层逻辑**：标准化操作，统一错误处理，提升可维护性。

#### 3.1 脚本库位置
```
scripts/
├── gitlab/                    # GitLab核心库
│   ├── common.sh             # 公共函数：环境检查、路径处理
│   ├── auth.sh               # 认证管理：登录、验证、令牌
│   └── wiki.sh               # Wiki操作：创建、更新、查看、删除
└── document/                 # 文档操作封装
    ├── init.sh              # 文档库初始化（推荐使用）
    └── *.sh                 # 其他技能封装脚本
```

#### 3.2 推荐使用方式
```bash
# 方式1：直接调用初始化脚本（最推荐）
./scripts/document/init.sh https://gitlab.com/团队/wit-parking-wiki

# 方式2：在技能中引用脚本库
source scripts/gitlab/common.sh
source scripts/gitlab/auth.sh
source scripts/document/init.sh

# 然后调用函数
document_init "https://gitlab.com/团队/wit-parking-wiki"
```

#### 3.3 脚本库核心函数
- `check_glab_installed()` - GitLab CLI环境检查
- `check_auth_status()` - 认证状态检查  
- `normalize_repo_path()` - URL路径规范化
- `document_init()` - 完整的文档库初始化
- `create_standard_directories()` - 创建标准目录结构

#### 3.4 向后兼容说明
- **旧方式**：手动执行glab命令（已过时）
- **新方式**：调用脚本库函数（推荐）
- **兼容层**：脚本库内部仍使用glab，但提供统一接口

## 集成接口

### 与其他子智能体集成
1. **配置共享**：通过`.sonli-spec-doc/config.json`共享配置
2. **状态同步**：初始化状态同步到其他智能体
3. **错误传播**：初始化失败时通知相关智能体

### 外部依赖
1. **GitLab CLI**：必须依赖，脚本库会自动检查
2. **脚本库**：必须依赖，提供标准化操作接口
3. **网络连接**：推荐但非必须
4. **本地存储**：必须

## 性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 初始化时间 | < 10秒 | 从接收到URL到完成初始化 |
| 成功率 | > 95% | 初始化成功比例 |
| 错误恢复率 | > 90% | 错误后自动恢复比例 |
| 配置完整性 | 100% | 所有配置项完整设置 |

## 测试用例

### 单元测试
1. **URL解析测试**：验证GitLab URL解析
2. **目录创建测试**：验证本地目录创建
3. **配置写入测试**：验证配置文件生成

### 集成测试  
1. **脚本库集成测试**：验证与脚本库的集成
2. **GitLab连接测试**：验证远程仓库连接
3. **多环境测试**：在不同环境中测试
4. **错误场景测试**：测试各种错误处理

### 用户验收测试
1. **端到端测试**：完整初始化流程
2. **兼容性测试**：新旧格式兼容
3. **性能测试**：响应时间和资源使用

---
**子智能体标识**：document-init-agent  
**版本**：1.0.0  
**创建时间**：2026-04-22  
**依赖**：GitLab CLI  
**状态**：就绪