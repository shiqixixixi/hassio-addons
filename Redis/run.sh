#!/usr/bin/env bash
set -e

CONFIG_PATH=/data/options.json
TARGET="$(bashio::config 'target')"
echo "$TARGET"

# 1. 打印原始环境变量（用于调试）
echo "=== 容器原始环境变量 ==="
env | grep -E "REDIS_|TZ"
echo "======================"

# 2. 读取/data/options.json作为备用配置源（关键：绕过模板解析问题）
# 即使权限受限，也用默认值兜底
OPTIONS_JSON=$(cat /data/options.json 2>/dev/null || echo '{"max_memory":"128mb","require_pass":"","appendonly":false}')

# 3. 从options.json提取实际值（覆盖环境变量中的模板语法）
# 若环境变量是模板（如{{ max_memory }}），则用options.json的值替换
MAX_MEMORY_FROM_JSON=$(echo "$OPTIONS_JSON" | jq -r '.max_memory')
REQUIRE_PASS_FROM_JSON=$(echo "$OPTIONS_JSON" | jq -r '.require_pass')
APPENDONLY_FROM_JSON=$(echo "$OPTIONS_JSON" | jq -r '.appendonly')

# 4. 处理环境变量：若为模板语法，则用JSON中的值覆盖
if [[ "$REDIS_MAX_MEMORY" == *"{{"* ]]; then
  MAX_MEMORY="$MAX_MEMORY_FROM_JSON"
else
  MAX_MEMORY="${REDIS_MAX_MEMORY:-128mb}"
fi

if [[ "$REDIS_REQUIRE_PASS" == *"{{"* ]]; then
  REQUIRE_PASS="$REQUIRE_PASS_FROM_JSON"
else
  REQUIRE_PASS="${REDIS_REQUIRE_PASS:-}"
fi

if [[ "$REDIS_APPENDONLY" == *"{{"* ]]; then
  APPENDONLY="$APPENDONLY_FROM_JSON"
else
  APPENDONLY="${REDIS_APPENDONLY:-false}"
fi

TZ="${TZ:-UTC}"

# 5. 打印最终生效的变量（验证是否替换成功）
echo "=== 最终生效的环境变量 ==="
echo "内存限制 (MAX_MEMORY): $MAX_MEMORY"
echo "AOF持久化 (APPENDONLY): $APPENDONLY"
echo "密码 (REQUIRE_PASS): ${REQUIRE_PASS:-(无密码)}"
echo "时区 (TZ): $TZ"
echo "======================"

# 6. 处理数据目录
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  echo "使用备用目录 /opt/redis"
  REDIS_DIR="/opt/redis"
fi
mkdir -p "$REDIS_DIR"

# 7. 启动Redis并动态配置
redis-server /redis.conf --dir "$REDIS_DIR" &
sleep 2

if redis-cli ping >/dev/null 2>&1; then
  # 应用内存限制（确保是有效格式，如128mb）
  if [[ "$MAX_MEMORY" =~ ^[0-9]+(mb|gb)$ ]]; then
    redis-cli config set maxmemory "$MAX_MEMORY"
    echo "已设置maxmemory: $MAX_MEMORY"
  else
    echo "警告：无效的内存格式，使用默认128mb"
    redis-cli config set maxmemory "128mb"
  fi

  # 应用AOF设置
  if [ "$APPENDONLY" = "true" ]; then
    redis-cli config set appendonly yes
    echo "已开启AOF持久化"
  else
    redis-cli config set appendonly no
    echo "已关闭AOF持久化"
  fi

  # 应用密码
  if [ -n "$REQUIRE_PASS" ]; then
    redis-cli config set requirepass "$REQUIRE_PASS"
    echo "已设置密码"
  else
    redis-cli config set requirepass ""
    echo "未设置密码"
  fi

  echo "配置已成功应用到Redis"
else
  echo "ERROR: Redis启动失败，无法应用配置"
  exit 1
fi

wait