#!/bin/bash
# 文档库初始化脚本
# 封装GitLab Wiki仓库的初始化流程

set -euo pipefail

# 加载GitLab核心库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../gitlab/common.sh"
source "$SCRIPT_DIR/../gitlab/auth.sh"
source "$SCRIPT_DIR/../gitlab/wiki.sh"

# 初始化文档库
document_init() {
    local wiki_url="$1"
    local repo_path
    local config_dir

    log_info "开始初始化文档库: $wiki_url"

    # 1. 检查GitLab CLI
    check_glab_installed || return 1

    # 2. 认证检查
    log_info "检查GitLab认证..."
    if ! check_auth_status; then
        log_warn "需要GitLab认证"
        glab_auth_interactive || return 1
    fi

    # 3. 路径规范化
    repo_path=$(normalize_repo_path "$wiki_url")
    log_info "仓库路径: $repo_path"

    # 4. 检查网络连接
    local host
    host=$(echo "$repo_path" | cut -d'/' -f1)
    check_network "$host" || {
        log_warn "网络连接检查失败，继续本地初始化..."
    }

    # 5. 创建配置目录
    config_dir=$(check_config_dir)
    log_info "配置目录: $config_dir"

    # 6. 保存配置
    write_config "gitlab.repo" "$repo_path"
    write_config "gitlab.host" "$host"
    write_config "init.url" "$wiki_url"
    write_config "init.timestamp" "$(date -Iseconds)"
    write_config "version.current" "v1.0.0"

    # 7. 创建标准目录结构
    create_standard_directories

    # 8. 创建初始文档
    create_initial_documents "$repo_path"

    # 9. 测试连接和上传
    test_wiki_connection "$repo_path"

    log_info "✅ 文档库初始化完成"
    log_info "配置保存到: $config_dir/config.json"
    log_info "Wiki地址: https://$host/$repo_path/-/wikis/home"

    return 0
}

# 创建标准目录结构
create_standard_directories() {
    log_info "创建标准目录结构..."

    local base_dir=".sonli-spec-doc/content"
    mkdir -p "$base_dir"

    # 文档类型目录
    local directories=(
        "pm/prd"
        "dev/plans"
        "dev/tasks"
        "dev/test-report"
        "dev/review-report"
        "test/testcases"
        "test/test-report"
        "knowledge-base/compound"
    )

    for dir in "${directories[@]}"; do
        local full_path="$base_dir/$dir"
        mkdir -p "$full_path"

        # 创建README
        local readme_file="$full_path/README.md"
        if [ ! -f "$readme_file" ]; then
            cat > "$readme_file" << EOF
# ${dir##*/}

## 目录说明

此目录用于存放: ${dir##*/} 相关文档。

### 文件命名规范
- 使用小写字母、数字和连字符
- 版本格式: v1.0.0-描述.md
- 日期格式: YYYY-MM-DD-描述.md

### 文档模板
请参考 templates/ 目录下的相关模板。

---
*自动生成于 $(date)*
EOF
        fi
    done

    # 创建模板目录
    mkdir -p "$base_dir/templates"
    create_template_files "$base_dir/templates"

    log_info "目录结构创建完成"
}

# 创建模板文件
create_template_files() {
    local template_dir="$1"

    log_info "创建文档模板..."

    # PRD模板
    cat > "$template_dir/prd-template.md" << 'EOF'
# 产品需求文档

## 1. 需求背景
- **业务背景**:
- **问题描述**:
- **影响范围**:

## 2. 目标与范围
- **核心目标**:
- **成功标准**:
- **验收条件**:

## 3. 功能需求
### 3.1 功能点1
- **描述**:
- **用户故事**:
- **验收标准**:

### 3.2 功能点2
- **描述**:
- **用户故事**:
- **验收标准**:

## 4. 非功能需求
- **性能要求**:
- **安全要求**:
- **兼容性要求**:

## 5. 交付计划
- **关键里程碑**:
- **资源需求**:
- **风险管控**:

## 6. 术语定义
- **业务术语**:
- **技术术语**:

---
版本: v1.0.0
创建时间: $(date)
EOF

    # 设计文档模板
    cat > "$template_dir/design-template.md" << 'EOF'
# 功能设计文档

## 1. 设计目标
- **解决问题**:
- **预期效果**:

## 2. 系统架构
### 2.1 模块划分
- 模块1:
- 模块2:

### 2.2 数据流图
[数据流程图描述]

## 3. 详细设计
### 3.1 关键算法
- 算法1:
- 算法2:

### 3.2 数据结构
- 结构1:
- 结构2:

### 3.3 状态流转
[状态图描述]

## 4. 接口规范
### 4.1 API设计
- 接口1:
- 接口2:

### 4.2 数据格式
- 格式1:
- 格式2:

### 4.3 错误处理
- 错误码:
- 异常处理:

## 5. 部署方案
- **环境要求**:
- **部署步骤**:
- **监控指标**:

---
版本: v1.0.0
创建时间: $(date)
EOF

    # 测试用例模板
    cat > "$template_dir/test-template.md" << 'EOF'
# 测试用例文档

## 测试场景
- **场景描述**:
- **测试目标**:

## 测试用例
### 用例1: 功能验证
- **前置条件**:
- **测试步骤**:
  1.
  2.
  3.
- **预期结果**:
- **实际结果**:

### 用例2: 边界测试
- **前置条件**:
- **测试步骤**:
  1.
  2.
  3.
- **预期结果**:
- **实际结果**:

### 用例3: 异常测试
- **前置条件**:
- **测试步骤**:
  1.
  2.
  3.
- **预期结果**:
- **实际结果**:

## 测试报告
- **通过率**:
- **失败用例**:
- **建议**:

---
版本: v1.0.0
创建时间: $(date)
EOF

    log_info "模板文件创建完成"
}

# 创建初始文档
create_initial_documents() {
    local repo_path="$1"
    local base_dir=".sonli-spec-doc/content"

    log_info "创建初始文档..."

    # 项目概览
    cat > "$base_dir/overview.md" << EOF
# 项目进度报告

## 项目概览
- **项目名称**: $(echo "$repo_path" | cut -d'/' -f2-)
- **开始时间**: $(date +%Y-%m-%d)
- **当前进度**: 0%
- **仓库地址**: https://$(echo "$repo_path" | cut -d'/' -f1)/$repo_path

## 本周完成
- [ ] 需求澄清
- [ ] PRD编写
- [ ] 环境搭建

## 下周计划
- [ ] 需求拆解
- [ ] 功能设计
- [ ] 技术评审

## 团队成员
- 产品经理:
- 技术负责人:
- 开发人员:

## 风险清单
| 风险 | 级别 | 应对措施 |
|------|------|----------|
| 需求不明确 | 高 | 加强沟通，明确验收标准 |
| 技术难度 | 中 | 技术预研，风险评估 |

---
*自动生成于 $(date)*
EOF

    # 设计规范
    cat > "$base_dir/DESIGN.md" << 'EOF'
# UI/UX设计规范

## 设计原则
1. **一致性原则**: 保持界面和交互的一致性
2. **简洁性原则**: 简化操作流程，减少用户认知负担
3. **易用性原则**: 界面直观，操作简单

## 组件规范
### 按钮规范
- 主要按钮: #1890ff
- 次要按钮: 默认样式
- 危险操作: #ff4d4f

### 表单规范
- 标签对齐: 左对齐
- 输入框大小: 中等
- 验证提示: 即时反馈

### 布局规范
- 栅格系统: 24列
- 间距: 8px基数
- 响应式: 支持移动端

## 颜色规范
- 主色调: #1890ff
- 辅助色: #52c41a, #faad14, #f5222d
- 中性色: #000000, #595959, #bfbfbf, #f0f0f0, #ffffff

## 字体规范
- 字体家族: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto
- 字号: 12px, 14px, 16px, 20px, 24px, 30px
- 字重: 400, 500, 600

---
版本: v1.0.0
创建时间: $(date)
EOF

    # 变更日志
    cat > "$base_dir/CHANGELOG.md" << EOF
# 项目变更日志

## v1.0.0 ($(date +%Y-%m-%d))
### 新增
- 初始化文档库结构
- 创建基础模板文件
- 配置GitLab Wiki集成

### 配置
- GitLab仓库: $repo_path
- 目录结构: 标准化
- 文档模板: PRD/设计/测试

### 下一步
1. 完善需求文档
2. 进行技术设计
3. 制定开发计划

---
*文档系统初始化完成*
EOF

    log_info "初始文档创建完成"
}

# 测试Wiki连接
test_wiki_connection() {
    local repo_path="$1"

    log_info "测试Wiki连接..."

    # 检查仓库是否存在
    if glab repo view "$repo_path" &> /dev/null; then
        log_info "仓库访问正常: $repo_path"
    else
        log_warn "仓库访问失败，可能需要创建Wiki"
        return 0  # 不是致命错误
    fi

    # 检查Wiki是否启用
    log_info "检查Wiki功能..."
    if glab repo wiki list &> /dev/null; then
        log_info "Wiki功能正常"
    else
        log_warn "Wiki功能可能未启用或权限不足"
    fi

    log_info "Wiki连接测试完成"
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        log_error "使用方法: $0 <gitlab-wiki-url>"
        log_info "示例: $0 https://gitlab.com/团队/wit-parking-wiki"
        exit 1
    fi

    local wiki_url="$1"
    document_init "$wiki_url"
}

# 脚本执行
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    main "$@"
fi