#!/usr/bin/env bash
#
# setup-claude-code.sh
#
# 初始化 Claude Code 配置：
#   1. 将 ~/.claude.json 中的 hasCompletedOnboarding 设为 true（跳过欢迎引导）
#   2. 依次询问 Base URL 和 API Key，写入 ~/.claude/settings.json 的 env 字段
#      并默认开启 Agent Teams / 1h 缓存 / Tool Search
#
# 依赖：jq

set -euo pipefail

# --- 调色板 ---
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; CYAN=$'\033[36m'
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; RESET=$'\033[0m'
else
  BOLD=''; DIM=''; CYAN=''; GREEN=''; YELLOW=''; RED=''; RESET=''
fi
RULE="${DIM}  ────────────────────────────────────────────${RESET}"

step()  { printf '\n%s %s\n' "${CYAN}[$1]${RESET}" "${BOLD}$2${RESET}"; }
ok()    { printf '   %s %s\n' "${GREEN}✓${RESET}" "$*"; }
hint()  { printf '   %s%s%s\n' "${DIM}· " "$*" "${RESET}"; }
warn()  { printf '   %s %s%s\n' "${YELLOW}!${RESET}" "${YELLOW}$*" "${RESET}"; }
error() { printf '%s %s\n' "${RED}✗ 错误:${RESET}" "$*" >&2; }
kv()    { printf '   %s %-36s %s %s\n' "${GREEN}•${RESET}" "$1" "${DIM}→${RESET}" "$2"; }
tilde() { printf '%s' "~${1#$HOME}"; }

# --- 横幅 ---
printf '\n%s\n%s\n' "${CYAN}${BOLD}  ⚡ Claude Code 配置向导${RESET}" "$RULE"

# --- 依赖检查 ---
if ! command -v jq >/dev/null 2>&1; then
  printf '\n'
  error "未找到 jq，请先安装：${BOLD}brew install jq${RESET}"
  exit 1
fi

CLAUDE_JSON="$HOME/.claude.json"
SETTINGS_DIR="$HOME/.claude"
SETTINGS_JSON="$SETTINGS_DIR/settings.json"

# 原子写入 JSON：将 stdin 写入临时文件再替换目标，避免写一半损坏
write_json() {
  local target="$1" tmp
  tmp="$(mktemp "${target}.XXXXXX")"
  cat > "$tmp"
  mv "$tmp" "$target"
}

# --- 1. hasCompletedOnboarding = true ---
step "1/3" "跳过欢迎引导"
hint "$(tilde "$CLAUDE_JSON")"
if [ -f "$CLAUDE_JSON" ]; then
  if ! jq empty "$CLAUDE_JSON" >/dev/null 2>&1; then
    error "${CLAUDE_JSON} 不是合法的 JSON，已中止以免覆盖损坏文件。"
    exit 1
  fi
  jq '.hasCompletedOnboarding = true' "$CLAUDE_JSON" | write_json "$CLAUDE_JSON"
else
  echo '{}' | jq '.hasCompletedOnboarding = true' | write_json "$CLAUDE_JSON"
fi
ok "hasCompletedOnboarding = true"

# --- 2. 询问 Base URL 和 API Key ---
step "2/3" "填写 API 接入信息"
base_url=""
while [ -z "$base_url" ]; do
  printf '   %s %s' "${CYAN}❯${RESET}" "Base URL: "
  read -r base_url
  [ -z "$base_url" ] && warn "Base URL 不能为空，请重新输入。"
done

api_key=""
while [ -z "$api_key" ]; do
  printf '   %s %s' "${CYAN}❯${RESET}" "API Key:  "
  read -rs api_key
  printf '\n'
  [ -z "$api_key" ] && warn "API Key 不能为空，请重新输入。"
done

# --- 3. 写入 settings.json ---
step "3/3" "写入配置文件"
hint "$(tilde "$SETTINGS_JSON")"
mkdir -p "$SETTINGS_DIR"
if [ -f "$SETTINGS_JSON" ]; then
  if ! jq empty "$SETTINGS_JSON" >/dev/null 2>&1; then
    error "${SETTINGS_JSON} 不是合法的 JSON，已中止以免覆盖损坏文件。"
    exit 1
  fi
  current="$(cat "$SETTINGS_JSON")"
else
  current='{}'
fi

jq --arg url "$base_url" --arg key "$api_key" \
  '.env.ANTHROPIC_BASE_URL = $url
   | .env.ANTHROPIC_AUTH_TOKEN = $key
   | .env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"
   | .env.ENABLE_PROMPT_CACHING_1H = "1"
   | .env.ENABLE_TOOL_SEARCH = "true"' \
  <<<"$current" | write_json "$SETTINGS_JSON"
ok "已保存 5 个环境变量"

# --- 收尾面板 ---
printf '\n%s\n%s\n' "${GREEN}${BOLD}  ✓ 全部完成${RESET}" "$RULE"
kv "hasCompletedOnboarding"                "true"
kv "ANTHROPIC_BASE_URL"                    "$base_url"
kv "ANTHROPIC_AUTH_TOKEN"                  "${api_key:0:4}${DIM}****（已隐藏）${RESET}"
kv "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"  "1"
kv "ENABLE_PROMPT_CACHING_1H"              "1"
kv "ENABLE_TOOL_SEARCH"                    "true"
printf '\n%s\n\n' "${DIM}  重启 Claude Code 使配置生效。${RESET}"
