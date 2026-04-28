#!/bin/bash
# document-compound GitLab CLI集成封装脚本
# 使用标准化的GitLab操作库

set -euo pipefail

# 加载GitLab核心库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../gitlab/common.sh"
source "$SCRIPT_DIR/../gitlab/auth.sh"
source "$SCRIPT_DIR/../gitlab/wiki.sh"

# document-compound特定配置
CONFIG_FILE=".sonli-spec-doc/config.json"
SKILL_NAME="document-compound"

# 初始化函数
init_document-compound() {
    log_info "初始化document-compound技能..."

    # 检查GitLab CLI
    check_glab_installed || return 1

    # 认证检查
    if ! check_auth_status; then
        log_warn "需要GitLab认证"
        glab_auth_interactive || return 1
    fi

    # 读取配置
    local repo
    repo=$(read_config "gitlab.repo")
    if [ -z "$repo" ]; then
        log_error "未配置GitLab仓库"
        log_info "请先运行: /document-init <gitlab-wiki-url>"
        return 1
    fi

    log_info "配置仓库: $repo"
    return 0
}

# 生成经验总结
generate_compound() {
    local title="$1"
    local content="${2:-}"
    local version="${3:-v1.0.0}"
    local target_path="${4:-knowledge-base/compound}"

    log_info "生成经验总结: $title"

    # 初始化检查
    init_document-compound || return 1

    # 如果内容为空，生成模板
    if [ -z "$content" ]; then
        content="# $title

## 背景与问题
- **发生时间**:
- **涉及系统**:
- **问题现象**:
- **影响范围**:

## 根因分析
### 技术层面
- 原因1:
- 原因2:

### 流程层面
- 原因1:
- 原因2:

## 解决方案
### 技术方案
1. 步骤1:
2. 步骤2:

### 流程改进
1. 改进1:
2. 改进2:

## 效果评估
### 技术效果
- 解决前:
- 解决后:

### 业务效果
- 解决前:
- 解决后:

## 经验沉淀
### 可复用的经验
1. 经验1:
2. 经验2:

### 避免的坑
1. 坑1:
2. 坑2:

## 相关文档
- [PRD]()
- [设计文档]()
- [测试报告]()

---
版本: $version
生成时间: $(date)"
    fi

    # 生成文件名
    local filename=$(echo "$title" | tr ' ' '-' | tr -cd '[:alnum:]-').md
    local full_path="$target_path/$filename"

    # 上传经验总结
    wiki_create "$full_path" "$content" "$title $version"

    log_info "✅ 经验总结生成完成: $full_path"
    return 0
}

# 查看经验总结
view_compound() {
    local title="$1"
    local target_path="${2:-knowledge-base/compound}"

    log_info "查看经验总结: $title"

    # 初始化检查
    init_document-compound || return 1

    # 生成文件名
    local filename=$(echo "$title" | tr ' ' '-' | tr -cd '[:alnum:]-').md
    local full_path="$target_path/$filename"

    # 查看经验总结
    wiki_view "$full_path"

    return $?
}

# 列出所有经验总结
list_compound() {
    local target_path="${1:-knowledge-base/compound}"

    log_info "列出经验总结..."

    # 初始化检查
    init_document-compound || return 1

    # 列出Wiki页面
    wiki_list "$target_path"

    return $?
}

# 主函数
main() {
    local command="${1:-help}"

    case "$command" in
        "generate")
            generate_compound "${@:2}"
            ;;
        "view")
            view_compound "${@:2}"
            ;;
        "list")
            list_compound "${@:2}"
            ;;
        "init")
            init_document-compound
            ;;
        "help")
            echo "使用方法: $0 <command>"
            echo "命令:"
            echo "  generate <标题> [内容] [版本] [路径] - 生成经验总结"
            echo "  view <标题> [路径] - 查看经验总结"
            echo "  list [路径] - 列出所有经验总结"
            echo "  init - 初始化技能"
            echo "  help - 显示帮助"
            ;;
        *)
            echo "未知命令: $command"
            echo "使用: $0 help 查看帮助"
            return 1
            ;;
    esac
}

# 脚本执行
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    main "$@"
fi