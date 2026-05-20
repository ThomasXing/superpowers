#!/bin/bash
# sync-to-remote.sh — 推送本地文档至 Spec Doc 远程仓库
# 核心机制：GitLab Commits API（批量原子提交，1 次调用推送所有文件）
# 依赖：GitLab HTTP + Token 鉴权（config.yaml 中的 gitlab.token）
# 使用：./sync-to-remote.sh [--dry-run] [--paths src[:dest]] [--dest path] [--message "msg"] [plan_name]
#   --dry-run         仅显示将要推送的文件，不实际上传
#   --paths src[:dest]  推送指定目录（逗号分隔）
#                      预定义目标：--paths "pm/prd,dev/api"
#                      自定义路径：--paths "dogfood-output"（自动查找本地目录）
#                      指定远程目标：--paths "dogfood-output:dev/test-report"
#   --dest path       自定义路径的远程目标目录（与 --paths 配合，如 --dest "dev/test-report"）
#   --message "msg"    自定义提交消息（默认自动生成）
#   plan_name         指定计划名（默认读取 config.yaml active_plan）

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
TARGET_PLAN=""
PATHS_FILTER=""
CUSTOM_MESSAGE=""
DEST_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --paths)
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ --paths 需要参数${NC}"
                exit 1
            fi
            PATHS_FILTER="$2"; shift 2 ;;
        --dest)
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ --dest 需要参数${NC}"
                exit 1
            fi
            DEST_PATH="$2"; shift 2 ;;
        --message)
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ --message 需要参数${NC}"
                exit 1
            fi
            CUSTOM_MESSAGE="$2"; shift 2 ;;
        *) TARGET_PLAN="$1"; shift ;;
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
SSH_URL=$(grep -E '^[[:space:]]*ssh_url:' "$CONFIG_FILE" | head -1 | cut -d: -f2- | tr -d ' "' | tr -d "'" | xargs)
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
LOCAL_PLAN_DIR="${LOCAL_ROOT}/${ACTIVE_PLAN}"

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
PROJECT_PATH=$(echo "$HTTP_URL" | sed 's|http[s]*://[^/]*/||' | sed 's|\.git$||')
PROJECT_ID=$(echo -n "$PROJECT_PATH" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))" 2>/dev/null || echo "$PROJECT_PATH" | sed 's|/|%2F|g')

# ── URL 编码辅助函数 ─────────────────────────────────────
url_encode() {
    echo -n "$1" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))"
}

# ── 获取远程已有文件列表 ────────────────────────────────────
# 辅助函数：扫描远程目录，提取文件路径追加到临时文件
scan_remote_dir() {
    local dir_path="$1"
    local page=1
    while true; do
        local tree_json
        tree_json=$(curl -s --connect-timeout 10 \
            --header "PRIVATE-TOKEN: ${TOKEN}" \
            "http://${HOSTNAME}/api/v4/projects/${PROJECT_ID}/repository/tree?path=${dir_path}&ref=main&recursive=true&per_page=100&page=${page}" 2>/dev/null || echo '[]')

        # 提取 blob 类型文件路径并追加到临时文件
        echo "$tree_json" | python3 -c "
import json, sys
try:
    items = json.load(sys.stdin)
    for i in items:
        if i.get('type') == 'blob' and i.get('name') != '.gitkeep':
            print(i['path'])
except: pass
" >> "$REMOTE_FILES_TEMP" 2>/dev/null

        # 判断是否还有下一页
        if echo "$tree_json" | python3 -c "import json,sys; data=json.load(sys.stdin); sys.exit(0 if isinstance(data,list) and len(data)>=100 else 1)" 2>/dev/null; then
            page=$((page + 1))
        else
            break
        fi
    done
}

echo -e "${CYAN}📂 扫描远程仓库已有文件…${NC}"
REMOTE_FILES_TEMP=$(mktemp)

# 扫描计划目录
scan_remote_dir "${ACTIVE_PLAN}"

# 扫描知识库目录
scan_remote_dir "knowledge-base/compound"

# 构建远程文件路径集合（用于判断 create/update）
REMOTE_FILE_SET=$(cat "$REMOTE_FILES_TEMP" | sort -u)
rm -f "$REMOTE_FILES_TEMP"

# ── 收集待推送文件 ──────────────────────────────────────
# 子模块目录列表
ALL_SYNC_TARGETS=(
    "pm/prd"
    "dev/plans"
    "dev/tasks"
    "dev/api"
    "dev/review-report"
    "dev/test-report"
    "test/testcases"
    "test/test-report"
)

# 根据 --paths 过滤同步目标
# 支持三种模式：
#   A) 预定义目标名（如 "dev/api", "test/test-report"）
#   B) 任意子路径（如 "dogfood-output", "dev/api/法定节假日"）
#   C) 源:目标 语法（如 "dogfood-output:dev/test-report"，将本地 dogfood-output 上传到远程 dev/test-report）
SYNC_TARGETS=()
CUSTOM_PATH_TARGETS=()  # 格式: "source_path:dest_path" 或 "source_path"
if [ -n "$PATHS_FILTER" ]; then
    IFS=',' read -ra FILTER_ARRAY <<< "$PATHS_FILTER"
    for filter_raw in "${FILTER_ARRAY[@]}"; do
        filter=$(echo "$filter_raw" | xargs)
        matched=false
        # 先尝试匹配预定义目标
        for target in "${ALL_SYNC_TARGETS[@]}"; do
            if [ "$target" = "$filter" ] || [[ "$target" == "$filter/"* ]] || [[ "$filter" == "$target/"* ]]; then
                # 避免重复
                already_in=false
                for existing in "${SYNC_TARGETS[@]:-}"; do
                    [ "$existing" = "$target" ] && already_in=true
                done
                $already_in || SYNC_TARGETS+=("$target")
                matched=true
                break
            fi
        done
        # 未匹配预定义目标 → 作为自定义路径处理
        if ! $matched; then
            if [ "$filter" = "knowledge-base" ] || [[ "$filter" == "knowledge-base/"* ]]; then
                # 知识库特殊处理
                INCLUDE_KB=true
            elif [ "$filter" = "overview" ]; then
                INCLUDE_OVERVIEW=true
            else
                # 检查是否有 source:dest 语法
                if [[ "$filter" == *":"* ]]; then
                    # source:dest 语法，直接使用
                    CUSTOM_PATH_TARGETS+=("$filter")
                else
                    # 只有 source，结合 --dest 或默认使用 source 作为 dest
                    if [ -n "$DEST_PATH" ]; then
                        CUSTOM_PATH_TARGETS+=("${filter}:${DEST_PATH}")
                    else
                        CUSTOM_PATH_TARGETS+=("${filter}:${filter}")
                    fi
                fi
            fi
        fi
    done
    INCLUDE_KB=${INCLUDE_KB:-false}
    INCLUDE_OVERVIEW=${INCLUDE_OVERVIEW:-false}
else
    SYNC_TARGETS=("${ALL_SYNC_TARGETS[@]}")
    INCLUDE_KB=true
    INCLUDE_OVERVIEW=true
fi

# 收集本地文件到临时文件（格式: ACTION|REMOTE_PATH|LOCAL_PATH）
TEMP_MANIFEST=$(mktemp)
_cleanup_temp() { rm -f "$TEMP_MANIFEST" "$COMMIT_JSON_TEMP" "$FALLBACK_JSON_TEMP" 2>/dev/null; }
trap _cleanup_temp EXIT

collect_files() {
    local local_subpath="$1"
    local remote_subpath="$2"
    local local_dir="${LOCAL_ROOT}/${local_subpath}"

    if [ ! -d "$local_dir" ]; then
        return 0
    fi

    find "$local_dir" -maxdepth 1 -type f ! -name '.gitkeep' ! -name '.DS_Store' | sort | while read -r local_file; do
        [ -z "$local_file" ] && continue
        local file_name
        file_name=$(basename "$local_file")
        local remote_path="${remote_subpath}/${file_name}"

        # 判断 create 或 update
        local action="create"
        if echo "$REMOTE_FILE_SET" | grep -qxF "$remote_path"; then
            action="update"
        fi

        echo "${action}|${remote_path}|${local_file}" >> "$TEMP_MANIFEST"
    done
}

# 递归收集文件（用于自定义路径，如 dogfood-output/）
# 参数：$1=本地绝对路径, $2=远程相对路径前缀
collect_files_recursive() {
    local base_dir="$1"
    local remote_prefix="$2"

    if [ ! -d "$base_dir" ]; then
        return 0
    fi

    find "$base_dir" -type f ! -name '.gitkeep' ! -name '.DS_Store' | sort | while read -r local_file; do
        [ -z "$local_file" ] && continue
        # 计算相对路径（相对于 base_dir）
        local rel_path
        rel_path=$(echo "$local_file" | sed "s|^${base_dir}/||")
        local remote_path="${remote_prefix}/${rel_path}"

        local action="create"
        if echo "$REMOTE_FILE_SET" | grep -qxF "$remote_path"; then
            action="update"
        fi

        echo "${action}|${remote_path}|${local_file}" >> "$TEMP_MANIFEST"
    done
}

# 收集计划子目录文件
echo -e "${CYAN}📦 收集待推送文件…${NC}"
for sub in "${SYNC_TARGETS[@]:-}"; do
    [ -z "$sub" ] && continue
    collect_files "${ACTIVE_PLAN}/${sub}" "${ACTIVE_PLAN}/${sub}"
done

# 收集知识库
if [ "${INCLUDE_KB:-false}" = "true" ]; then
    collect_files "knowledge-base/compound" "knowledge-base/compound"
fi

# 收集 overview
if [ "${INCLUDE_OVERVIEW:-false}" = "true" ]; then
    if [ -f "${LOCAL_PLAN_DIR}/overview.md" ]; then
        local_file="${LOCAL_PLAN_DIR}/overview.md"
        remote_path="${ACTIVE_PLAN}/overview.md"
        action="create"
        if echo "$REMOTE_FILE_SET" | grep -qxF "$remote_path"; then
            action="update"
        fi
        echo "${action}|${remote_path}|${local_file}" >> "$TEMP_MANIFEST"
    fi
fi

# 收集自定义路径文件（任意子路径，不受预定义目标限制）
# 格式: "source_path:dest_path" 或 "source_path"（dest 默认同 source）
# 查找优先级：① .sonli-spec-doc/<active_plan>/  ② .sonli-spec-doc/  ③ 项目 Git 根目录
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

for custom_entry in "${CUSTOM_PATH_TARGETS[@]:-}"; do
    [ -z "$custom_entry" ] && continue

    # 解析 source:dest 语法
    custom_source="$custom_entry"
    custom_dest=""
    if [[ "$custom_entry" == *":"* ]]; then
        custom_source="${custom_entry%%:*}"
        custom_dest="${custom_entry#*:}"
    fi
    # 如果没有指定 dest，默认使用 source
    if [ -z "$custom_dest" ]; then
        custom_dest="$custom_source"
    fi

    found=false

    # ① 在计划目录下查找 (.sonli-spec-doc/<active_plan>/<custom_source>)
    custom_local_dir="${LOCAL_PLAN_DIR}/${custom_source}"
    if [ -d "$custom_local_dir" ]; then
        collect_files "${ACTIVE_PLAN}/${custom_source}" "${ACTIVE_PLAN}/${custom_dest}"
        found=true
    fi
    # 也支持计划根目录下的直接文件
    custom_file="${LOCAL_PLAN_DIR}/${custom_source}"
    if [ -f "$custom_file" ]; then
        custom_remote_path="${ACTIVE_PLAN}/${custom_dest}"
        action="create"
        if echo "$REMOTE_FILE_SET" | grep -qxF "$custom_remote_path"; then
            action="update"
        fi
        echo "${action}|${custom_remote_path}|${custom_file}" >> "$TEMP_MANIFEST"
        found=true
    fi

    # ② 在 .sonli-spec-doc 根目录下查找 (如 knowledge-base)
    custom_spec_dir="${LOCAL_ROOT}/${custom_source}"
    if [ -d "$custom_spec_dir" ] && [ "$custom_spec_dir" != "$custom_local_dir" ]; then
        collect_files "${custom_source}" "${custom_dest}"
        found=true
    fi

    # ③ 在项目 Git 根目录下查找 (如 dogfood-output)
    if [ -n "$GIT_ROOT" ] && ! $found; then
        custom_git_dir="${GIT_ROOT}/${custom_source}"
        if [ -d "$custom_git_dir" ]; then
            collect_files_recursive "${custom_git_dir}" "${ACTIVE_PLAN}/${custom_dest}"
            found=true
        fi
        custom_git_file="${GIT_ROOT}/${custom_source}"
        if [ -f "$custom_git_file" ]; then
            custom_remote_path="${ACTIVE_PLAN}/${custom_dest}"
            action="create"
            if echo "$REMOTE_FILE_SET" | grep -qxF "$custom_remote_path"; then
                action="update"
            fi
            echo "${action}|${custom_remote_path}|${custom_git_file}" >> "$TEMP_MANIFEST"
            found=true
        fi
    fi

    ! $found && echo -e "   ${YELLOW}⚠ 自定义路径未找到: ${custom_source}${NC}"
done

# 统计
TOTAL_FILES=$(wc -l < "$TEMP_MANIFEST" | xargs)
CREATE_COUNT=$(grep -c "^create|" "$TEMP_MANIFEST" 2>/dev/null || echo 0)
UPDATE_COUNT=$(grep -c "^update|" "$TEMP_MANIFEST" 2>/dev/null || echo 0)

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo -e "${YELLOW}⚠ 无文件需要推送${NC}"
    exit 0
fi

echo -e "   共 ${GREEN}${TOTAL_FILES}${NC} 个文件（${GREEN}${CREATE_COUNT}${NC} 新增，${YELLOW}${UPDATE_COUNT}${NC} 更新）"

# ── DRY-RUN 模式 ─────────────────────────────────────────
if $DRY_RUN; then
    echo ""
    echo -e "${CYAN}🏁 DRY-RUN 模式（未实际上传）${NC}"
    echo -e "   将推送以下文件："
    while IFS='|' read -r action remote_path local_file; do
        if [ "$action" = "create" ]; then
            label="${GREEN}[新增]${NC}"
        else
            label="${YELLOW}[更新]${NC}"
        fi
        echo -e "   ${label} ${remote_path}"
    done < "$TEMP_MANIFEST"
    exit 0
fi

# ── 构建 Commits API 请求体 ──────────────────────────────
echo -e "${CYAN}🔧 构建 Commits API 请求…${NC}"

# 使用 python3 构建 JSON，直接写入临时文件（避免超大变量占用 shell 内存）
COMMIT_JSON_TEMP=$(mktemp)
MANIFEST_PATH="$TEMP_MANIFEST" COMMIT_JSON_TEMP="$COMMIT_JSON_TEMP" python3 << 'PYEOF'
import json, base64, sys, os

manifest_path = os.environ.get('MANIFEST_PATH', '')
commit_json_temp = os.environ.get('COMMIT_JSON_TEMP', '')
actions = []

with open(manifest_path, 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split('|', 2)
        if len(parts) != 3:
            continue
        action, remote_path, local_path = parts

        # 读取文件并 base64 编码
        try:
            with open(local_path, 'rb') as fh:
                content_b64 = base64.b64encode(fh.read()).decode('ascii')
        except Exception as e:
            print(f"WARN: 跳过无法读取的文件 {local_path}: {e}", file=sys.stderr)
            continue

        actions.append({
            "action": action,
            "file_path": remote_path,
            "content": content_b64,
            "encoding": "base64"
        })

if not actions:
    print("ERROR: 无有效的文件操作", file=sys.stderr)
    sys.exit(1)

# 自动生成提交消息
import subprocess
result = subprocess.run(['git', 'config', 'user.name'], capture_output=True, text=True)
author = result.stdout.strip() or 'spec-kit-agent'

body = {
    "branch": "main",
    "commit_message": "",  # 由调用方设置
    "author_name": author,
    "actions": actions
}

with open(commit_json_temp, 'w') as f:
    json.dump(body, f, ensure_ascii=False)
PYEOF

if [ $? -ne 0 ] || [ ! -s "$COMMIT_JSON_TEMP" ]; then
    echo -e "${RED}❌ 构建 JSON 请求体失败${NC}"
    exit 1
fi

# 设置提交消息
if [ -n "$CUSTOM_MESSAGE" ]; then
    COMMIT_MESSAGE="$CUSTOM_MESSAGE"
else
    COMMIT_MESSAGE="docs: ${ACTIVE_PLAN} +${CREATE_COUNT} ~${UPDATE_COUNT} files"
fi

# 注入 commit_message 到 JSON 临时文件
COMMIT_MSG="$COMMIT_MESSAGE" COMMIT_JSON_TEMP="$COMMIT_JSON_TEMP" python3 -c "
import json, os
commit_json_temp = os.environ['COMMIT_JSON_TEMP']
commit_msg = os.environ['COMMIT_MSG']
with open(commit_json_temp, 'r') as f:
    data = json.load(f)
data['commit_message'] = commit_msg
with open(commit_json_temp, 'w') as f:
    json.dump(data, f, ensure_ascii=False)
"

# ── 发送 Commits API 请求 ────────────────────────────────
echo ""
echo -e "${CYAN}📤 推送「${ACTIVE_PLAN}」文档至 Spec Doc 远程仓库…${NC}"
echo -e "   远端: ${HOSTNAME}/${PROJECT_PATH}"
echo -e "   本地: ${LOCAL_PLAN_DIR}"
echo -e "   鉴权: HTTP + Token"
echo -e "   模式: Commits API（原子提交）"
echo ""

RESULT=$(curl -s --connect-timeout 60 \
    --header "PRIVATE-TOKEN: ${TOKEN}" \
    --header "Content-Type: application/json" \
    -X POST \
    -d @"${COMMIT_JSON_TEMP}" \
    "http://${HOSTNAME}/api/v4/projects/${PROJECT_ID}/repository/commits" 2>/dev/null || echo '{"error":"curl failed"}')

# ── 解析响应 ─────────────────────────────────────────────
RESPONSE_PARSE=$(echo "$RESULT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except:
    print('PARSE_ERROR')
    sys.exit(0)
if 'id' in data and 'short_id' in data:
    short_id = data.get('short_id', '?')
    title = data.get('title', '')
    print(f'SUCCESS|{short_id}|{title}')
elif 'message' in data:
    msg = data.get('message', '')
    if isinstance(msg, list):
        msg = '; '.join(str(m) for m in msg)
    print(f'ERROR|{msg}')
else:
    print(f'ERROR|unknown')
")

if echo "$RESPONSE_PARSE" | grep -q "^SUCCESS|"; then
    SHORT_ID=$(echo "$RESPONSE_PARSE" | cut -d'|' -f2)
    echo -e "${GREEN}✅ 推送成功！${NC}"
    echo -e "   Commit: ${SHORT_ID}"
    echo -e "   消息: ${COMMIT_MESSAGE}"
    echo ""

    # 逐文件显示结果
    while IFS='|' read -r action remote_path local_file; do
        file_name=$(basename "$local_file")
        if [ "$action" = "create" ]; then
            echo -e "   ${GREEN}✅ 已create${NC}: ${file_name}"
        else
            echo -e "   ${GREEN}✅ 已update${NC}: ${file_name}"
        fi
    done < "$TEMP_MANIFEST"
elif echo "$RESPONSE_PARSE" | grep -q "^ERROR|"; then
    ERROR_MSG=$(echo "$RESPONSE_PARSE" | cut -d'|' -f2-)
    echo -e "${RED}❌ 推送失败${NC}"
    echo -e "   错误: ${ERROR_MSG}"

    # 如果是 action 错误（如 create 文件已存在），尝试回退：全用 update
    if echo "$ERROR_MSG" | grep -qi "already exists"; then
        echo -e "${YELLOW}   尝试回退：所有文件使用 update 操作…${NC}"
        # 回退：复用临时文件，所有 action 改为 update
        FALLBACK_JSON_TEMP=$(mktemp)
        COMMIT_JSON_TEMP="$COMMIT_JSON_TEMP" FALLBACK_JSON_TEMP="$FALLBACK_JSON_TEMP" python3 -c "
import json, os
src = os.environ['COMMIT_JSON_TEMP']
dst = os.environ['FALLBACK_JSON_TEMP']
with open(src, 'r') as f:
    data = json.load(f)
for action in data.get('actions', []):
    action['action'] = 'update'
data['commit_message'] = data.get('commit_message', '') + ' (fallback: force update)'
with open(dst, 'w') as f:
    json.dump(data, f, ensure_ascii=False)
"
        FALLBACK_RESULT=$(curl -s --connect-timeout 60 \
            --header "PRIVATE-TOKEN: ${TOKEN}" \
            --header "Content-Type: application/json" \
            -X POST \
            -d @"${FALLBACK_JSON_TEMP}" \
            "http://${HOSTNAME}/api/v4/projects/${PROJECT_ID}/repository/commits" 2>/dev/null || echo '{"error":"curl failed"}')
        rm -f "$FALLBACK_JSON_TEMP"

        FALLBACK_PARSE=$(echo "$FALLBACK_RESULT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except:
    print('PARSE_ERROR')
    sys.exit(0)
if 'id' in data and 'short_id' in data:
    print(f'SUCCESS|{data.get(\"short_id\", \"?\")}')
elif 'message' in data:
    msg = data.get('message', '')
    if isinstance(msg, list):
        msg = '; '.join(str(m) for m in msg)
    print(f'ERROR|{msg}')
else:
    print('ERROR|unknown')
")

        if echo "$FALLBACK_PARSE" | grep -q "^SUCCESS|"; then
            SHORT_ID=$(echo "$FALLBACK_PARSE" | cut -d'|' -f2)
            echo -e "${GREEN}✅ 回退推送成功！${NC}"
            echo -e "   Commit: ${SHORT_ID}"
            while IFS='|' read -r action remote_path local_file; do
                file_name=$(basename "$local_file")
                echo -e "   ${GREEN}✅ 已update${NC}: ${file_name}"
            done < "$TEMP_MANIFEST"
        else
            echo -e "${RED}❌ 回退推送也失败${NC}"
            echo "   响应: $FALLBACK_RESULT" | head -3
        fi
    fi
else
    echo -e "${RED}❌ 推送失败（无法解析响应）${NC}"
    echo "   响应: $RESULT" | head -3
fi

# ── 完成 ──────────────────────────────────────────────────
echo ""
echo -e "   活跃计划: ${ACTIVE_PLAN}"
echo -e "   本地路径: ${LOCAL_PLAN_DIR}"
