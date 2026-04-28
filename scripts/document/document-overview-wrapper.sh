#!/bin/bash
# document-overview GitLab CLI集成封装脚本
# 使用标准化的GitLab操作库

set -euo pipefail

# 加载GitLab核心库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../gitlab/common.sh"
source "$SCRIPT_DIR/../gitlab/auth.sh"
source "$SCRIPT_DIR/../gitlab/wiki.sh"

# document-overview特定配置
CONFIG_FILE=".sonli-spec-doc/config.json"
SKILL_NAME="document-overview"

# 初始化函数
init_document-overview() {
    log_info "初始化document-overview技能..."

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

# 生成/更新项目概览
generate_overview() {
    local version="${1:-v1.0.0}"
    local target_path="${2:-overview}"

    log_info "生成项目概览: $version"

    # 初始化检查
    init_document-overview || return 1

    # 生成概览内容
    local content="# 项目进度报告

## 项目概览
- **项目名称**: $(read_config "gitlab.repo" | cut -d'/' -f2-)
- **生成时间**: $(date +%Y-%m-%d)
- **当前版本**: $version
- **仓库地址**: https://$(read_config "gitlab.host" "gitlab.com")/$(read_config "gitlab.repo")

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
*自动生成于 $(date)*"

    # 上传概览
    local wiki_prefix
    wiki_prefix=$(get_wiki_prefix)
    local full_path="$wiki_prefix/$target_path"
    wiki_create "$full_path" "$content" "项目概览 $version"

    log_info "✅ 项目概览生成完成: $full_path"
    return 0
}

# 查看项目概览
view_overview() {
    local version="${1:-latest}"
    local target_path="${2:-overview}"

    log_info "查看项目概览: $version"

    # 初始化检查
    init_document-overview || return 1

    # 查看概览
    local wiki_prefix
    wiki_prefix=$(get_wiki_prefix)
    local full_path="$wiki_prefix/$target_path"
    wiki_view "$full_path"

    return $?
}

# 主函数
main() {
    local command="${1:-help}"

    case "$command" in
        "generate")
            generate_overview "${@:2}"
            ;;
        "view")
            view_overview "${@:2}"
            ;;
        "init")
            init_document-overview
            ;;
        "help")
            echo "使用方法: $0 <command>"
            echo "命令:"
            echo "  generate [版本] [路径] - 生成/更新项目概览"
            echo "  view [版本] [路径] - 查看项目概览"
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