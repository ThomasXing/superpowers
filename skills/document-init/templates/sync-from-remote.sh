#!/bin/bash
# sync-from-remote.sh — 从 Spec Doc 远程仓库拉取文档到本地工作区
# 依赖：GitLab API v4 + config.yaml 中的 gitlab.token
# 使用：./sync-from-remote.sh [--dry-run] [--force] [plan_name]
#   --dry-run  仅显示将要拉取的文件，不实际写入
#   --force   强制覆盖本地已有文件（默认跳过已存在的文件）
#   plan_name   指定计划名（默认读取 config.yaml active_plan）

# ── 版本自检（在 set -e 之前，优雅降级）─────────────────
SCRIPT_VERSION="3.1.0"
_self_update() {
    local script_name repo_root template template_version newer
    script_name="$(basename "${BASH_SOURCE[0]}")"
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
    # 优先 .qoder/skills/（Qoder 运行时），回退 skills/
    template="${repo_root}/.qoder/skills/document-init/templates/${script_name}"
    [ -f "$template" ] || template="${repo_root}/skills/document-init/templates/${script_name}"
    [ -f "$template" ] || return 0
    template_version=$(grep -m1 '^SCRIPT_VERSION=' "$template" 2>/dev/null | cut -d'"' -f2)
    [ -n "$template_version" ] || return 0
    [ "$template_version" != "$SCRIPT_VERSION" ] || return 0
    # 语义版本比较：模板版本 > 本地版本才提示
    newer=$(printf '%s\n%s\n' "$SCRIPT_VERSION" "$template_version" | sort -V | tail -1 2>/dev/null)
    [ "$newer" = "$template_version" ] || return 0

    echo ""
    echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;33m  🔄 ${script_name} 有可用更新\033[0m"
    echo -e "\033[0;37m  本地: v${SCRIPT_VERSION}  →  模板: v${template_version}\033[0m"
    echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    echo -n "  是否更新？[Y/n] "
    read -r answer
    case "$answer" in
        [Nn]*|[Nn][Oo]*)
            echo -e "\033[1;33m  ⚠️  已跳过，继续使用 v${SCRIPT_VERSION}\033[0m"
            echo ""
            ;;
        *)
            echo -e "\033[0;36m  📥 正在更新...\033[0m"
            cp "$template" "${BASH_SOURCE[0]}" || { echo -e "\033[0;31m  ❌ 更新失败\033[0m"; return 0; }
            echo -e "\033[0;32m  ✅ 已更新至 v${template_version}，重新执行\033[0m"
            echo ""
            exec bash "${BASH_SOURCE[0]}" "$@"
            return 0  # exec 失败时兜底，不阻断主流程
            ;;
    esac
}
_self_update "$@"

set -euo pipefail

# ── 依赖检查 ─────────────────────────────────────────────
command -v python3 >/dev/null 2>&1 || { echo "❌ 缺少依赖: python3 未安装或不在 PATH 中"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.yaml"

# ── 颜色 ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── 参数解析 ─────────────────────────────────────────────
DRY_RUN=false
FORCE=false
TARGET_PLAN=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --force) FORCE=true ;;
        *) TARGET_PLAN="$arg" ;;
    esac
done

# ── 配置读取 ─────────────────────────────────────────────
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ config.yaml 未找到：$CONFIG_FILE${NC}"
    echo "   请先执行 /document-init"
    exit 1
fi

TOKEN=$(grep -E '^[[:space:]]*token:' "$CONFIG_FILE" | head -1 | cut -d: -f2- | tr -d ' "' | tr -d "'" | xargs)
HOSTNAME=$(grep -E '^[[:space:]]*hostname:' "$CONFIG_FILE" | head -1 | cut -d: -f2- | tr -d ' "' | tr -d "'" | xargs)
HTTP_URL=$(grep -E '^[[:space:]]*http_url:' "$CONFIG_FILE" | head -1 | cut -d: -f2- | tr -d ' "' | tr -d "'" | xargs)
ACTIVE_PLAN="${TARGET_PLAN:-$(grep -E '^[[:space:]]*active_plan:' "$CONFIG_FILE" | head -1 | cut -d: -f2- | cut -d'#' -f1 | tr -d '"' | tr -d "'" | xargs)}"

if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ gitlab.token 为空，请先执行 /document-init 配置 Token${NC}"
    exit 1
fi

if [ -z "$HOSTNAME" ]; then
    echo -e "${RED}❌ gitlab.hostname 未配置${NC}"
    exit 1
fi

if [ -z "$ACTIVE_PLAN" ]; then
    echo -e "${RED}❌ active_plan 未设置${NC}"
    exit 1
fi

HTTP_URL="${HTTP_URL:-http://${HOSTNAME}}"
LOCAL_ROOT="${SCRIPT_DIR}/.."

# ── Token 校验 ────────────────────────────────────────────
echo -e "${CYAN}🔑 验证 GitLab Token...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 \
    --header "PRIVATE-TOKEN: ${TOKEN}" \
    "http://${HOSTNAME}/api/v4/user" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${RED}❌ Token 无效（HTTP $HTTP_CODE），请重新执行 /document-init 配置${NC}"
    exit 1
fi
echo -e "${GREEN}   Token 有效 ✓${NC}"

# ── 项目 ID 编码 ──────────────────────────────────────────
# 从 ssh_url 或 http_url 提取项目路径并 URL 编码
PROJECT_PATH=$(echo "$HTTP_URL" | sed 's|http[s]*://[^/]*/||' | sed 's|\.git$||')
PROJECT_ID=$(echo -n "$PROJECT_PATH" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))" 2>/dev/null || echo "$PROJECT_PATH" | sed 's|/|%2F|g')

# ── URL 编码辅助函数 ─────────────────────────────────────
url_encode() {
    echo -n "$1" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))"
}

# ── 同步单个目录 ─────────────────────────────────────────
# 参数：$1=远程子路径（如 monthly/2026年5月/...）, $2=本地子路径（如 2026年5月/...）
sync_dir() {
    local remote_path="$1"
    local local_subpath="$2"
    local local_dir="${LOCAL_ROOT}/${local_subpath}"

    local encoded_path
    encoded_path=$(url_encode "$remote_path")

    # 列出远程文件
    local files_json
    files_json=$(curl -s --connect-timeout 10 \
        --header "PRIVATE-TOKEN: ${TOKEN}" \
        "http://${HOSTNAME}/api/v4/projects/${PROJECT_ID}/repository/tree?path=${encoded_path}&ref=main&per_page=100" 2>/dev/null)

    if [ -z "$files_json" ] || echo "$files_json" | grep -q '"message"'; then
        # 目录不存在或无权限
        return 0
    fi

    # 解析文件列表，跳过 tree（子目录）和 .gitkeep
    echo "$files_json" | python3 -c "
import json, sys
try:
    items = json.load(sys.stdin)
    for i in items:
        if i['type'] == 'blob' and i['name'] != '.gitkeep':
            print(i['path'] + '|' + i['name'])
except: pass
" 2>/dev/null | while IFS='|' read -r file_path file_name; do
        [ -z "$file_path" ] && continue

        local dest_file="${local_dir}/${file_name}"

        # 检查本地是否已有（--force 时强制覆盖）
        if [ -f "$dest_file" ] && ! $FORCE; then
            echo -e "   ${YELLOW}⏭ 跳过（已存在）${NC}: ${file_name}"
            continue
        fi

        if [ -f "$dest_file" ] && $FORCE; then
            echo -e "   ${CYAN}🔄 强制覆盖${NC}: ${file_name}"
        fi

        if $DRY_RUN; then
            echo -e "   ${CYAN}[DRY-RUN] 将拉取${NC}: ${file_name}"
            continue
        fi

        # 下载文件
        local encoded_file
        encoded_file=$(url_encode "$file_path")
        local raw_content
        raw_content=$(curl -s --connect-timeout 10 \
            --header "PRIVATE-TOKEN: ${TOKEN}" \
            "http://${HOSTNAME}/api/v4/projects/${PROJECT_ID}/repository/files/${encoded_file}/raw?ref=main" 2>/dev/null)

        if [ -n "$raw_content" ] && ! echo "$raw_content" | grep -q '"message"'; then
            mkdir -p "$local_dir"
            echo "$raw_content" > "$dest_file"
            echo -e "   ${GREEN}✅ 已拉取${NC}: ${file_name}"
        else
            echo -e "   ${RED}❌ 拉取失败${NC}: ${file_name}"
        fi
    done
}

# ── 主流程 ────────────────────────────────────────────────
echo ""
echo -e "${CYAN}📥 从 Spec Doc 拉取「${ACTIVE_PLAN}」最新文档…${NC}"
echo -e "   远端: ${HOSTNAME}/${PROJECT_PATH}"
echo -e "   本地: ${LOCAL_ROOT}/${ACTIVE_PLAN}"
echo ""

# 远程路径可能有两种约定：
#   A) monthly/<plan>/...  （旧版，如 monthly/2026年5月月度计划/pm/prd/）
#   B) <plan>/...           （新版，如 2026年6月月度计划/pm/prd/）
# 两种都尝试

REMOTE_PLAN_A="monthly/${ACTIVE_PLAN}"
REMOTE_PLAN_B="${ACTIVE_PLAN}"

# 子模块目录列表
SYNC_TARGETS=(
    "pm/prd"
    "dev/plans"
    "dev/tasks"
    "dev/api"
    "dev/review-report"
    "dev/test-report"
    "test/testcases"
    "test/test-report"
)

PULLED_COUNT=0
SKIPPED_COUNT=0

for sub in "${SYNC_TARGETS[@]}"; do
    # 先试路径 B (直连)，再试路径 A (monthly 前缀)
    for remote_base in "$REMOTE_PLAN_B" "$REMOTE_PLAN_A"; do
        remote_path="${remote_base}/${sub}"
        local_path="${ACTIVE_PLAN}/${sub}"
        sync_dir "$remote_path" "$local_path"
    done
done

# ── 同步知识库 ────────────────────────────────────────────
echo ""
echo -e "${CYAN}📚 同步知识库…${NC}"
sync_dir "knowledge-base/compound" "knowledge-base/compound"

# ── 同步 overview ──────────────────────────────────────────
# overview 文件可能存在于计划根目录
for remote_base in "$REMOTE_PLAN_B" "$REMOTE_PLAN_A"; do
    sync_dir "$remote_base" "${ACTIVE_PLAN}"
done

echo ""
if $DRY_RUN; then
    echo -e "${CYAN}🏁 DRY-RUN 完成（未实际写入）${NC}"
else
    echo -e "${GREEN}🏁 同步完成！${NC}"
fi
echo -e "   活跃计划: ${ACTIVE_PLAN}"
echo -e "   本地路径: ${LOCAL_ROOT}/${ACTIVE_PLAN}"
