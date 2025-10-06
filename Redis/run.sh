#!/usr/bin/env bash
set -e

# -------------------------- 1. 配置初始化（增强容错） --------------------------
OPTIONS_FILE="/data/options.json"

cat $OPTIONS_FILE
# 读取并修复options.json（核心：处理无效JSON）
read_options() {
  local retries=3
  local delay=2
  local raw_content
  local cleaned_content

  for ((i=1; i<=retries; i++)); do
    if [ -f "$OPTIONS_FILE" ] && [ -r "$OPTIONS_FILE" ]; then
      # 读取原始内容并清洗（移除非法字符，保留核心字段）
      raw_content=$(cat "$OPTIONS_FILE" 2>/dev/null)
      # 尝试保留有效字段，过滤非法字符（仅保留数字、字母、常见符号）
      cleaned_content=$(echo "$raw_content" | sed 's/[^\x20-\x7E]//g' | jq -r 'try . catch {}')
      
      # 若清洗后仍为空，手动构造默认JSON
      if [ -z "$cleaned_content" ] || [ "$cleaned_content" = "null" ]; then
        cleaned_content='{"max_memory":"128mb","require_pass":"","appendonly":false}'
      fi
      
      echo "$cleaned_content"
      return 0
    fi
    echo "WARNING: $OPTIONS_FILE not readable (attempt $i/$retries), waiting..."
    sleep $delay
  done

  # 最终兜底默认配置
  echo '{"max_memory":"128mb","require_pass":"","appendonly":false}'
}

# 解析配置（增加错误捕获）
OPTIONS_JSON=$(read_options)
# 用jq的try/catch确保解析失败时使用默认值
MAX_MEMORY=$(echo "$OPTIONS_JSON" | jq -r 'try .max_memory // "128mb" catch "128mb"')
REQUIRE_PASS=$(echo "$OPTIONS_JSON" | jq -r 'try .require_pass // "" catch ""')
APPENDONLY=$(echo "$OPTIONS_JSON" | jq -r 'try .appendonly // "false" catch "false"')
TZ="${TZ:-UTC}"

# 调试打印
echo "=== HassOS Redis Add-on Config ==="
echo "Cleaned Options JSON: $OPTIONS_JSON"
echo "Max Memory: $MAX_MEMORY"
echo "AOF Persistence: $APPENDONLY"
echo "Password: ${REQUIRE_PASS:-(No Password)}"
echo "Timezone: $TZ"
echo "==================================="

# -------------------------- 2. 应用准备 --------------------------
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  echo "WARNING: /data/redis not found, using backup directory /opt/redis"
  REDIS_DIR="/opt/redis"
  mkdir -p "$REDIS_DIR"
fi

# -------------------------- 3. 启动Redis --------------------------
exec redis-server \
  --dir "$REDIS_DIR" \
  --maxmemory "$MAX_MEMORY" \
  --appendonly "$([ "$APPENDONLY" = "true" ] && echo "yes" || echo "no")" \
  --requirepass "$REQUIRE_PASS" \
  --bind 0.0.0.0 \
  --protected-mode no