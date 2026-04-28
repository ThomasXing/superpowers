#!/bin/bash
# document-pm GitLab CLI集成封装脚本
# 使用标准化的GitLab操作库

set -euo pipefail

# 加载GitLab核心库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../gitlab/common.sh"
source "$SCRIPT_DIR/../gitlab/auth.sh"
source "$SCRIPT_DIR/../gitlab/wiki.sh"

# document-pm特定配置
CONFIG_FILE=".sonli-spec-doc/config.json"
SKILL_NAME="document-pm"

# 初始化函数
init_document-pm() {
    log_info "初始化document-pm技能..."

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

# 上传函数
upload_document-pm_document() {
    local document_file="$1"
    local version="${2:-v1.0.0}"
    local target_path="${3:-}"

    log_info "上传document-pm文档: $document_file"

    # 初始化检查
    init_document-pm || return 1

    # 确定目标路径
    if [ -z "$target_path" ]; then
        local wiki_prefix
        wiki_prefix=$(get_wiki_prefix)
        case "$SKILL_NAME" in
            "document-pm")
                target_path="$wiki_prefix/pm/prd/$version"
                ;;
            "document-dev")
                target_path="$wiki_prefix/dev/design/$version"
                ;;
            "document-test")
                target_path="$wiki_prefix/test/cases/$version"
                ;;
            *)
                target_path="$wiki_prefix/${SKILL_NAME#document-}/$version"
                ;;
        esac
    fi

    # 上传文档
    if [ -f "$document_file" ]; then
        wiki_create "$target_path" "$document_file" "${SKILL_NAME#document-} $version"
    else
        log_error "文档文件不存在: $document_file"
        return 1
    fi

    log_info "✅ document-pm文档上传完成: $target_path"
    return 0
}

# 查看函数
view_document-pm_document() {
    local version="${1:-latest}"
    local target_path="${2:-}"

    log_info "查看document-pm文档: $version"

    # 初始化检查
    init_document-pm || return 1

    # 确定目标路径
    if [ -z "$target_path" ]; then
        local wiki_prefix
        wiki_prefix=$(get_wiki_prefix)
        case "$SKILL_NAME" in
            "document-pm")
                target_path="$wiki_prefix/pm/prd/$version"
                ;;
            "document-dev")
                target_path="$wiki_prefix/dev/design/$version"
                ;;
            "document-test")
                target_path="$wiki_prefix/test/cases/$version"
                ;;
            *)
                target_path="$wiki_prefix/${SKILL_NAME#document-}/$version"
                ;;
        esac
    fi

    # 查看文档
    wiki_view "$target_path"

    return $?
}

# 主函数
main() {
    local command="${1:-help}"

    case "$command" in
        "upload")
            upload_document-pm_document "${@:2}"
            ;;
        "view")
            view_document-pm_document "${@:2}"
            ;;
        "init")
            init_document-pm
            ;;
        "help")
            echo "使用方法: $0 <command>"
            echo "命令:"
            echo "  upload <文件> [版本] [路径] - 上传文档"
            echo "  view [版本] [路径] - 查看文档"
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
