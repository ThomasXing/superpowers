#!/bin/bash
# repo.sh - Git 仓库存储核心函数库
# 替代 scripts/gitlab/wiki.sh，所有文档存入仓库 docs/ 目录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../../.sonli-spec-doc/config.yaml"

# ── 配置读取 ────────────────────────────────────────────────

# 读取 config.yaml 中的 active_plan
get_active_plan() {
    if [ -f "$CONFIG_FILE" ]; then
        grep 'active_plan' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"'
    else
        echo ""
    fi
}

# 获取文档根目录（相对仓库根）
get_docs_root() {
    if [ -f "$CONFIG_FILE" ]; then
        grep 'docs_root' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"'
    else
        echo "docs/monthly"
    fi
}

# 获取知识库根目录
get_knowledge_base() {
    if [ -f "$CONFIG_FILE" ]; then
        grep 'knowledge_base' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"'
    else
        echo "docs/knowledge-base"
    fi
}

# 拼接当前活跃计划的文档路径
get_plan_path() {
    local subpath="${1:-}"
    local plan
    plan=$(get_active_plan)
    local root
    root=$(get_docs_root)

    if [ -n "$subpath" ]; then
        echo "${root}/${plan}/${subpath}"
    else
        echo "${root}/${plan}"
    fi
}

# ── Git 操作封装 ─────────────────────────────────────────────

# 确保目录存在（含 .gitkeep）
ensure_dir() {
    local dir="$1"
    mkdir -p "$dir"
    if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        touch "${dir}/.gitkeep"
    fi
}

# 将文件写入目标路径并 git commit
repo_save() {
    local src_file="$1"      # 源文件路径
    local dest_path="$2"     # 目标目录（相对仓库根）
    local commit_msg="$3"    # commit message

    if [ ! -f "$src_file" ]; then
        echo "[ERROR] 源文件不存在: $src_file" >&2
        return 1
    fi

    ensure_dir "$dest_path"
    cp "$src_file" "$dest_path/"

    git add "$dest_path/"
    git commit -m "$commit_msg"
    git push

    echo "[OK] 已提交: $dest_path/$(basename "$src_file")"
}

# 将内容字符串写入目标文件并 git commit
repo_write() {
    local content="$1"       # 文件内容
    local dest_file="$2"     # 目标文件路径（相对仓库根）
    local commit_msg="$3"    # commit message

    local dest_dir
    dest_dir="$(dirname "$dest_file")"
    ensure_dir "$dest_dir"

    echo "$content" > "$dest_file"

    git add "$dest_file"
    git commit -m "$commit_msg"
    git push

    echo "[OK] 已提交: $dest_file"
}

# 批量提交某目录下所有变更
repo_commit_dir() {
    local dir="$1"
    local commit_msg="$2"

    if [ ! -d "$dir" ]; then
        echo "[ERROR] 目录不存在: $dir" >&2
        return 1
    fi

    git add "$dir/"
    git commit -m "$commit_msg" || echo "[WARN] 无新变更，跳过 commit"
    git push

    echo "[OK] 已提交目录: $dir"
}

# 查看文件内容（cat）
repo_view() {
    local file_path="$1"

    if [ -f "$file_path" ]; then
        cat "$file_path"
    else
        echo "[ERROR] 文件不存在: $file_path" >&2
        return 1
    fi
}

# 列出目录内容
repo_list() {
    local dir="${1:-.}"
    ls -la "$dir" 2>/dev/null || echo "[INFO] 目录为空或不存在: $dir"
}

# ── 文档技能专用快捷函数 ─────────────────────────────────────

# 保存 PRD 文档
save_prd() {
    local file="$1"
    local dest
    dest=$(get_plan_path "pm/prd")
    repo_save "$file" "$dest" "docs(pm): add PRD - $(basename "$file" .md)"
}

# 保存功能设计文档
save_design() {
    local file="$1"
    local dest
    dest=$(get_plan_path "dev")
    repo_save "$file" "$dest" "docs(dev): add design - $(basename "$file" .md)"
}

# 保存测试用例
save_testcases() {
    local file="$1"
    local dest
    dest=$(get_plan_path "test/testcases")
    repo_save "$file" "$dest" "docs(test): add testcases - $(basename "$file" .md)"
}

# 保存测试报告
save_test_report() {
    local file="$1"
    local dest
    dest=$(get_plan_path "test/test-report")
    repo_save "$file" "$dest" "docs(test): add test report - $(basename "$file" .md)"
}

# 更新项目概览
save_overview() {
    local file="$1"
    local dest
    dest=$(get_plan_path)
    repo_save "$file" "$dest" "docs(overview): update project overview - $(date +%Y-%m-%d)"
}

# 保存经验总结到知识库
save_compound() {
    local file="$1"
    local kb
    kb=$(get_knowledge_base)
    repo_save "$file" "${kb}/compound" "docs(compound): add experience - $(basename "$file" .md)"
}
