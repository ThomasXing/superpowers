# GitLab CLI使用指南

> GitLab CLI (glab) 是GitLab官方命令行工具，用于自动化GitLab操作。本文档详细介绍glab的安装、配置和在与document技能集成中的使用。

## 📦 安装与配置

### 1. 安装GitLab CLI

#### macOS (Homebrew)
```bash
brew install glab
```

#### Linux
```bash
# Ubuntu/Debian
curl -s https://gitlab.com/gitlab-org/cli/-/raw/main/scripts/install.sh | sudo sh

# 或者下载二进制
wget https://gitlab.com/gitlab-org/cli/-/releases/v1.34.0/downloads/glab_1.34.0_Linux_x86_64.tar.gz
tar -xzf glab_1.34.0_Linux_x86_64.tar.gz
sudo mv bin/glab /usr/local/bin/
```

#### Windows
```powershell
# 使用Scoop
scoop install glab

# 或者使用Chocolatey
choco install glab
```

### 2. 认证配置

#### 2.1 交互式认证
```bash
glab auth login
```
系统会提示：
1. 选择GitLab实例（默认gitlab.com）
2. 选择认证方式（浏览器/OAuth/令牌）
3. 输入令牌（如有）

#### 2.2 使用环境变量
```bash
# 设置环境变量（推荐用于CI/CD）
export GITLAB_TOKEN="your-personal-access-token"
export GITLAB_HOST="gitlab.example.com"  # 私有部署时需要
```

#### 2.3 生成访问令牌
1. 登录GitLab
2. 点击右上角头像 → Settings → Access Tokens
3. 创建新令牌，权限选择：
   - `api`：API访问
   - `read_repository`：读取仓库
   - `write_repository`：写入仓库
   - `read_api`：读取API
4. 复制令牌并保存

### 3. 验证配置
```bash
# 检查认证状态
glab auth status

# 测试连接
glab api /version
```

## 📚 核心命令

### Wiki相关命令

#### 创建Wiki页面
```bash
# 基本用法
glab repo wiki create "文档路径" --content "文档内容"

# 指定格式
glab repo wiki create "{根命名空间}/{活跃计划}/pm/prd/v1.0.0" \
  --content "$(cat prd.md)" \
  --format markdown

# 创建带标题的文档
glab repo wiki create "开发规范" \
  --title "开发规范" \
  --content "$(cat spec.md)"
```

#### 更新Wiki页面
```bash
# 更新内容
glab repo wiki update "{根命名空间}/{活跃计划}/pm/prd/v1.0.0" \
  --content "$(cat updated-prd.md)"

# 重命名页面
glab repo wiki update "旧路径" --rename "新路径"
```

#### 查看Wiki页面
```bash
# 列出所有Wiki页面
glab repo wiki list

# 查看特定页面
glab repo wiki view "{根命名空间}/{活跃计划}/pm/prd/v1.0.0"

# 查看原始内容
glab repo wiki view "路径" --raw
```

#### 删除Wiki页面
```bash
glab repo wiki delete "过时文档路径"
```

### 项目相关命令

#### 创建项目
```bash
# 创建新项目
glab repo create wit-parking-wiki \
  --description "松立研发项目协作文档" \
  --visibility public

# 创建Wiki仓库（特定用途）
glab repo create team-docs \
  --description "团队文档库" \
  --wiki-enabled
```

#### 克隆项目
```bash
# 克隆项目
glab repo clone 团队/wit-parking-wiki

# 只克隆Wiki
git clone git@gitlab.com:团队/wit-parking-wiki.wiki.git
```

### Issue相关命令（用于需求跟踪）

#### 创建Issue
```bash
# 创建需求Issue
glab issue create \
  --title "需求：用户注册功能" \
  --description "$(cat prd-summary.md)" \
  --label "需求,高优先级"

# 从模板创建
glab issue create \
  --title "$(head -1 prd-template.md)" \
  --description "$(cat prd-template.md)" \
  --assignee @username
```

#### 管理Issue
```bash
# 列出Issue
glab issue list --state open --label "需求"

# 查看Issue详情
glab issue view 123

# 关闭Issue
glab issue close 123 --comment "需求已实现"
```

## 🔧 与document技能集成

### 初始化脚本
```bash
#!/bin/bash
# document-init.sh

set -e

# 参数检查
if [ $# -eq 0 ]; then
    echo "用法: $0 <gitlab-wiki-url>"
    exit 1
fi

WIKI_URL="$1"
REPO_PATH="${WIKI_URL#*://}"
REPO_PATH="${REPO_PATH%.git}"
REPO_PATH="${REPO_PATH%.wiki}"

echo "正在初始化文档库: $REPO_PATH"

# 1. 检查glab安装
if ! command -v glab &> /dev/null; then
    echo "错误：未安装GitLab CLI"
    echo "请运行: brew install glab"
    exit 1
fi

# 2. 检查认证状态
if ! glab auth status &> /dev/null; then
    echo "需要GitLab认证"
    glab auth login
fi

# 3. 创建目录结构
echo "创建本地目录结构..."
mkdir -p .sonli-spec-doc
cd .sonli-spec-doc

# 4. 克隆Wiki仓库
echo "克隆Wiki仓库..."
if [ ! -d ".git" ]; then
    glab repo clone "$REPO_PATH.wiki" .
fi

# 5. 初始化目录
echo "初始化目录结构..."
mkdir -p "{根命名空间}/{活跃计划}/pm/prd"
mkdir -p "{根命名空间}/{活跃计划}/dev/plans"
mkdir -p "{根命名空间}/{活跃计划}/dev/tasks"
mkdir -p "{根命名空间}/{活跃计划}/dev/test report"
mkdir -p "{根命名空间}/{活跃计划}/dev/review report"
mkdir -p "{根命名空间}/{活跃计划}/test/testcases"
mkdir -p "{根命名空间}/{活跃计划}/test/test report"

# 6. 创建初始文档
echo "创建初始文档..."
cat > "{根命名空间}/{活跃计划}/README.md" << 'EOF'
# 产品中心月度计划

## 目录结构
- pm/prd/ - 产品需求文档
- dev/plans/ - 需求拆解
- dev/tasks/ - 任务分配
- dev/test report/ - 测试验收报告
- dev/review report/ - 代码审查报告
- test/testcases/ - 测试用例
- test/test report/ - 测试验收报告
EOF

cat > "DESIGN.md" << 'EOF'
# UI/UX设计规范

## 设计原则
1. 一致性原则
2. 简洁性原则
3. 易用性原则

## 组件规范
- 按钮规范
- 表单规范
- 布局规范
EOF

cat > "overview.md" << 'EOF'
# 项目进度报告

## 项目概览
- 项目名称：待填写
- 开始时间：YYYY-MM-DD
- 当前进度：0%

## 本周完成
- [ ] 需求澄清
- [ ] PRD编写

## 下周计划
- [ ] 需求拆解
- [ ] 功能设计
EOF

cat > "CHANGELOG.md" << 'EOF'
# 项目变更日志

## v1.0.0 (YYYY-MM-DD)
### 新增
- 初始化文档库结构
- 创建基础模板

### 配置
- GitLab Wiki集成
- 目录结构规范
EOF

# 7. 推送初始文档
echo "推送初始文档到Wiki..."
for file in $(find . -name "*.md"); do
    wiki_path="${file#./}"
    echo "上传: $wiki_path"
    glab repo wiki create "$wiki_path" \
      --content "$(cat "$file")" \
      --format markdown || true
done

echo "✅ 文档库初始化完成"
echo "Wiki地址: https://gitlab.com/$REPO_PATH/-/wikis/home"
```

### PRD上传脚本
```bash
#!/bin/bash
# document-pm-upload.sh

set -e

PRD_FILE="$1"
PRD_VERSION="${2:-v1.0.0}"
PRD_DATE=$(date +%Y-%m-%d)

# 检查文件存在
if [ ! -f "$PRD_FILE" ]; then
    echo "错误：PRD文件不存在: $PRD_FILE"
    exit 1
fi

# 上传到Wiki
WIKI_PATH="{根命名空间}/{活跃计划}/pm/prd/$PRD_VERSION"
echo "上传PRD: $WIKI_PATH"

glab repo wiki create "$WIKI_PATH" \
  --title "PRD $PRD_VERSION ($PRD_DATE)" \
  --content "$(cat "$PRD_FILE")" \
  --format markdown

# 更新PRD索引
INDEX_PATH="{根命名空间}/{活跃计划}/pm/prd/README.md"
if ! glab repo wiki view "$INDEX_PATH" &> /dev/null; then
    # 创建索引
    cat > /tmp/prd-index.md << EOF
# PRD文档索引

| 版本 | 日期 | 负责人 | 状态 | 链接 |
|------|------|--------|------|------|
| $PRD_VERSION | $PRD_DATE | 待填写 | 评审中 | [$PRD_VERSION]($PRD_VERSION) |
EOF
    glab repo wiki create "$INDEX_PATH" \
      --content "$(cat /tmp/prd-index.md)" \
      --format markdown
else
    # 更新索引
    glab repo wiki view "$INDEX_PATH" --raw > /tmp/prd-index.md
    echo "| $PRD_VERSION | $PRD_DATE | 待填写 | 评审中 | [$PRD_VERSION]($PRD_VERSION) |" >> /tmp/prd-index.md
    glab repo wiki update "$INDEX_PATH" \
      --content "$(cat /tmp/prd-index.md)"
fi

echo "✅ PRD上传完成: $WIKI_PATH"
```

### 项目概览更新脚本
```bash
#!/bin/bash
# document-overview-update.sh

set -e

OVERVIEW_FILE="$1"
DINGTALK_FORMAT="${2:-false}"

# 生成钉钉播报格式
if [ "$DINGTALK_FORMAT" = "true" ]; then
    # 提取关键信息
    PROJECT_NAME=$(grep -m1 "项目名称" "$OVERVIEW_FILE" | cut -d： -f2 | xargs)
    PROGRESS=$(grep -m1 "整体进度" "$OVERVIEW_FILE" | grep -o "[0-9]*%" || echo "0%")
    COMPLETED=$(sed -n '/本周完成/,/###/p' "$OVERVIEW_FILE" | grep -E "\[x\]|\[X\]" | wc -l)
    TOTAL=$(sed -n '/本周完成/,/###/p' "$OVERVIEW_FILE" | grep -E "\[.\]" | wc -l)
    RISKS=$(grep -c "高风险" "$OVERVIEW_FILE" 2>/dev/null || echo 0)
    
    # 生成钉钉消息
    cat > /tmp/dingtalk-msg.md << EOF
【项目进度播报】$(date +%Y-%m-%d)

📊 整体进度：$PROGRESS
🎯 本周完成：$COMPLETED/$TOTAL 项任务
⚠️ 当前风险：$RISKS 个高风险
👥 团队状态：请查看详细报告
📅 下周重点：$(grep -A2 "下周计划" "$OVERVIEW_FILE" | head -3 | tail -1 | sed 's/- \[ \] //')

详细报告：$(glab repo view --web)/-/wikis/overview
EOF
    
    echo "钉钉播报内容："
    echo "================"
    cat /tmp/dingtalk-msg.md
    echo "================"
fi

# 更新Wiki概览
echo "更新项目概览..."
glab repo wiki update "overview.md" \
  --content "$(cat "$OVERVIEW_FILE")" \
  --format markdown

echo "✅ 项目概览更新完成"
```

## 🚀 自动化工作流

### CI/CD集成示例
```yaml
# .gitlab-ci.yml
stages:
  - docs

generate-prd:
  stage: docs
  script:
    - |
      # 安装glab
      curl -s https://gitlab.com/gitlab-org/cli/-/raw/main/scripts/install.sh | sh
      
      # 配置认证
      export GITLAB_TOKEN="$GITLAB_TOKEN"
      
      # 生成PRD
      /document pm generate "用户注册功能"
      
      # 上传PRD
      /document pm upload
  only:
    - main
  when: manual

update-overview:
  stage: docs
  script:
    - |
      # 生成概览报告
      /document overview generate
      
      # 上传到Wiki
      /document overview upload
      
      # 发送钉钉通知
      /document overview --dingtalk
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
      when: always
    - if: '$CI_COMMIT_TAG'
      when: always
```

### 定时任务示例
```bash
# crontab - 每天17:00更新概览
0 17 * * * /usr/local/bin/document-overview-update.sh /path/to/overview.md true

# 每周一生成周报
0 9 * * 1 /usr/local/bin/document-weekly-report.sh
```

## 🔒 安全最佳实践

### 令牌管理
```bash
# 使用环境变量存储令牌
echo 'export GITLAB_TOKEN="your-token"' >> ~/.bashrc

# 限制令牌权限
# 只授予必要的最小权限：
# - read_repository (读取仓库)
# - write_repository (写入仓库)
# - read_api (读取API)
# 不要授予admin权限

# 定期轮换令牌（每90天）
```

### 访问控制
```bash
# 项目级权限控制
glab project member list  # 查看项目成员
glab project member add @username --role maintainer  # 添加成员

# 保护分支
glab repo protect-branch main  # 保护main分支
```

### 审计日志
```bash
# 查看操作日志
glab audit-log list --after "2024-01-01"

# 导出操作记录
glab audit-log list --format json > audit-$(date +%Y%m%d).json
```

## 🐛 故障排除

### 常见问题

#### 1. 认证失败
```bash
# 检查令牌有效性
curl -H "Authorization: Bearer $GITLAB_TOKEN" \
  https://gitlab.com/api/v4/user

# 重新认证
glab auth login --host gitlab.example.com
```

#### 2. 权限不足
```bash
# 检查项目权限
glab project view

# 检查令牌权限
echo $GITLAB_TOKEN | cut -c1-10
# 确保令牌有write_repository权限
```

#### 3. 网络问题
```bash
# 测试连接
curl -I https://gitlab.com

# 使用代理
export HTTPS_PROXY=http://proxy.example.com:8080
export HTTP_PROXY=http://proxy.example.com:8080
```

#### 4. 文件大小限制
```bash
# GitLab默认限制10MB
# 检查文件大小
ls -lh large-file.md

# 分割大文件
split -b 5M large-file.md large-file-part-
```

### 调试模式
```bash
# 启用调试
export GLAB_DEBUG=true
glab repo wiki create "test" --content "test"

# 查看详细日志
glab --verbose repo wiki list

# 检查配置文件
cat ~/.config/glab-cli/config.yml
```

## 📊 监控与统计

### 文档统计脚本
```bash
#!/bin/bash
# document-stats.sh

# 统计文档数量
DOC_COUNT=$(glab repo wiki list | wc -l)
echo "Wiki文档总数: $DOC_COUNT"

# 统计各类型文档
PRD_COUNT=$(glab repo wiki list | grep -c "prd/" || true)
DESIGN_COUNT=$(glab repo wiki list | grep -c "dev/plans/" || true)
TEST_COUNT=$(glab repo wiki list | grep -c "test/" || true)

echo "PRD文档: $PRD_COUNT"
echo "设计文档: $DESIGN_COUNT"
echo "测试文档: $TEST_COUNT"

# 统计更新频率
RECENT_UPDATES=$(glab api "/projects/:id/wikis" --paginate | jq '.[] | select(.updated_at > "'$(date -d "30 days ago" +%Y-%m-%d)'")' | jq -s length)
echo "最近30天更新文档: $RECENT_UPDATES"
```

### 使用情况报告
```bash
# 生成月度报告
glab api "/projects/:id/wikis" \
  --paginate \
  | jq '.[] | {title: .title, updated_at: .updated_at, slug: .slug}' \
  > wiki-report-$(date +%Y%m).json
```

---

## 📚 参考资料

- [GitLab CLI官方文档](https://gitlab.com/gitlab-org/cli)
- [GitLab API文档](https://docs.gitlab.com/ee/api/)
- [GitLab Wiki文档](https://docs.gitlab.com/ee/user/project/wiki/)
- [GitLab权限说明](https://docs.gitlab.com/ee/user/permissions.html)

## 🆘 获取帮助

```bash
# 查看帮助
glab --help
glab repo wiki --help

# 查看版本
glab --version

# 提交问题
glab issue create --title "CLI问题：无法上传文档" --label bug
```

---

> 本指南为document技能提供完整的GitLab CLI集成方案，确保团队能够高效管理和同步Spec开发文档。所有操作都遵循最小权限原则，保障系统安全。