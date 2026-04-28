#!/bin/bash
# document-pm Git 仓库存储封装脚本
# 所有文档存入仓库 docs/ 目录，通过 git commit 管理版本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/repo.sh"

SKILL_NAME="document-pm"

# 初始化函数
init_document-pm() {
    echo "[INFO] 初始化 document-pm 技能..."

    # 检查 git 环境
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "[ERROR] 当前目录不是 git 仓库" >&2
        return 1
    fi

    # 检查活跃计划配置
    local plan
    plan=$(get_active_plan)
    if [ -z "$plan" ]; then
        echo "[ERROR] 未配置活跃计划，请检查 .sonli-spec-doc/config.yaml 中的 active_plan" >&2
        return 1
    fi

    local docs_path
    docs_path=$(get_plan_path "pm/prd")
    echo "[INFO] 活跃计划: $plan"
    echo "[INFO] PRD 存储路径: $docs_path"
    return 0
}

# 上传（提交）PRD 文档
upload_document-pm_document() {
    local document_file="$1"
    local _version="${2:-v1.0.0}"   # 保留参数兼容性，不再用于路径

    echo "[INFO] 提交 PRD 文档: $document_file"

    # 初始化检查
    init_document-pm || return 1

    if [ ! -f "$document_file" ]; then
        echo "[ERROR] 文档文件不存在: $document_file" >&2
        return 1
    fi

    save_prd "$document_file"
    echo "[OK] PRD 文档已提交到仓库"
    return 0
}

# 查看 PRD 文档
view_document-pm_document() {
    local _version="${1:-latest}"

    init_document-pm || return 1

    local docs_path
    docs_path=$(get_plan_path "pm/prd")
    repo_list "$docs_path"
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
            echo "  upload <文件> [版本] - 提交 PRD 文档到仓库"
            echo "  view [版本]          - 查看 PRD 文档列表"
            echo "  init                 - 初始化技能"
            echo "  help                 - 显示帮助"
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
