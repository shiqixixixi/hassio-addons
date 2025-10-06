#!/usr/bin/env bash
set -e

# 1. 打印原始环境变量（用于调试）
echo "=== 容器原始环境变量 ==="
env | grep -E "REDIS_|TZ"
echo "======================"

# 1. 定义加载项数据目录（HassOS 中固定路径）
ADDON_DATA_DIR="/data"
OPTIONS_FILE="$ADDON_DATA_DIR/options.json"

# 2. 通过 Supervisor API 读取 options.json 内容（绕开文件权限）
# 超时时间 10 秒，重试 3 次
read_options_via_api() {
  local retries=3
  local delay=3
  local response

  for ((i=1; i<=retries; i++)); do
    # Supervisor API 地址固定，通过 SUPERVISOR_TOKEN 认证
    response=$(curl -s -w "%{http_code}" -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
      "http://supervisor/files/read?path=$OPTIONS_FILE")
    
    # 提取 HTTP 状态码（最后 3 位）和内容
    http_code="${response: -3}"
    content="${response%???}"

    if [ "$http_code" = "200" ] && [ -n "$content" ]; then
      echo "$content"
      return 0
    fi

    echo "WARNING: API 读取失败（尝试 $i/$retries），状态码: $http_code"
    sleep $delay
  done

  # 多次失败后返回默认配置
  echo '{"max_memory":"128mb","require_pass":"","appendonly":false}'
}

# 3. 执行 API 读取并解析配置
OPTIONS_JSON=$(read_options_via_api)
MAX_MEMORY=$(echo "$OPTIONS_JSON" | jq -r '.max_memory // "128mb"')
REQUIRE_PASS=$(echo "$OPTIONS_JSON" | jq -r '.require_pass // ""')
APPENDONLY=$(echo "$OPTIONS_JSON" | jq -r '.appendonly // "false"')

# 4. 打印配置验证
echo "=== 从 API 读取到的配置 ==="
echo "options.json 内容: $OPTIONS_JSON"
echo "内存限制: $MAX_MEMORY"
echo "AOF 持久化: $APPENDONLY"
echo "密码: ${REQUIRE_PASS:-(无密码)}"
echo "======================"

# 5. 处理数据目录
REDIS_DIR="/data/redis"
[ ! -d "$REDIS_DIR" ] && REDIS_DIR="/opt/redis"
mkdir -p "$REDIS_DIR"

# 6. 启动 Redis 并应用配置
redis-server /redis.conf --dir "$REDIS_DIR" &
sleep 2

if redis-cli ping >/dev/null 2>&1; then
  # 验证内存格式并应用
  if [[ "$MAX_MEMORY" =~ ^[0-9]+(mb|gb)$ ]]; then
    redis-cli config set maxmemory "$MAX_MEMORY"
  else
    echo "警告：内存格式无效，使用默认 128mb"
    redis-cli config set maxmemory "128mb"
  fi

  # 应用 AOF
  [ "$APPENDONLY" = "true" ] && redis-cli config set appendonly yes || redis-cli config set appendonly no

  # 应用密码
  [ -n "$REQUIRE_PASS" ] && redis-cli config set requirepass "$REQUIRE_PASS" || redis-cli config set requirepass ""

  echo "配置已成功应用到 Redis"
else
  echo "ERROR: Redis 启动失败"
  exit 1
fi

wait