#!/usr/bin/env bash
set -e

# 直接读取容器环境变量（无需读options.json），并设置默认值
MAX_MEMORY="${REDIS_MAX_MEMORY:-128mb}"
REQUIRE_PASS="${REDIS_REQUIRE_PASS:-}"
APPENDONLY="${REDIS_APPENDONLY:-false}"

# 调试打印：确认环境变量是否注入成功
echo "=== 调试：注入的环境变量 ==="
echo "MAX_MEMORY: $MAX_MEMORY"
echo "APPENDONLY: $APPENDONLY"
echo "REQUIRE_PASS: $REQUIRE_PASS"
echo "=========================="

# 后续目录处理、启动Redis、动态配置逻辑不变...
REDIS_DIR="/data/redis"
[ ! -d "$REDIS_DIR" ] && REDIS_DIR="/opt/redis"
mkdir -p "$REDIS_DIR"

redis-server /redis.conf --dir "$REDIS_DIR" &
sleep 2

if redis-cli ping >/dev/null 2>&1; then
  redis-cli config set maxmemory "$MAX_MEMORY"
  [ "$APPENDONLY" = "true" ] && redis-cli config set appendonly yes
  [ -n "$REQUIRE_PASS" ] && redis-cli config set requirepass "$REQUIRE_PASS"
else
  echo "ERROR: Redis启动失败"
  exit 1
fi

wait