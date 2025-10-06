#!/usr/bin/env bash
set -e

# 加载Bashio库（HA官方配置工具）
source /usr/lib/bashio/bashio

# -------------------------- 1. 读取配置（通过Bashio，自动处理options.json） --------------------------
# 读取max_memory（默认128mb）
MAX_MEMORY=$(bashio::config 'max_memory' '128mb')
# 读取密码（默认空）
REQUIRE_PASS=$(bashio::config 'require_pass' '')
# 读取AOF持久化开关（默认false）
APPENDONLY=$(bashio::config 'appendonly' 'false')
# 读取时区（继承HA系统时区）
TZ=$(bashio::config 'TZ' 'UTC')

# 调试打印配置
bashio::log.info "=== Redis配置参数 ==="
bashio::log.info "内存限制: $MAX_MEMORY"
bashio::log.info "AOF持久化: $APPENDONLY"
bashio::log.info "密码: $( [ -n "$REQUIRE_PASS" ] && echo "已设置" || echo "未设置" )"
bashio::log.info "时区: $TZ"

# -------------------------- 2. 处理数据目录 --------------------------
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  bashio::log.warning "/data/redis不存在，使用备用目录/opt/redis"
  REDIS_DIR="/opt/redis"
  mkdir -p "$REDIS_DIR"
fi

# -------------------------- 3. 启动Redis并应用配置 --------------------------
# 转换AOF开关为Redis支持的yes/no
AOF_FLAG="$([ "$APPENDONLY" = "true" ] && echo "yes" || echo "no")"

# 启动Redis（用exec确保进程为PID=1，HassOS可管理）
exec redis-server \
  --dir "$REDIS_DIR" \
  --maxmemory "$MAX_MEMORY" \
  --appendonly "$AOF_FLAG" \
  --requirepass "$REQUIRE_PASS" \
  --bind 0.0.0.0 \
  --protected-mode no