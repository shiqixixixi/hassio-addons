#!/usr/bin/env bash
set -e

# 1. 从HassOS注入的环境变量中读取值（变量名与config.yaml对应）
# 若未获取到，使用默认值兜底
MAX_MEMORY="${HASS_MAX_MEMORY:-128mb}"
REQUIRE_PASS="${HASS_REQUIRE_PASS:-}"
APPENDONLY="${HASS_APPENDONLY:-false}"

# 2. 目录检测与兜底（已验证有效）
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  echo "WARNING: /data/redis not found, use backup dir /opt/redis"
  REDIS_DIR="/opt/redis"
fi
REDIS_CONF="${REDIS_DIR}/redis.conf"

# 3. 处理appendonly格式（true/false → yes/no）
APPENDONLY_FLAG="no"
if [ "$APPENDONLY" = "true" ]; then
  APPENDONLY_FLAG="yes"
fi

# 4. 生成Redis配置文件（绝对纯净，不带任何注释，避免语法错误）
cat > "$REDIS_CONF" <<EOL
daemonize no
pidfile /var/run/redis/redis.pid
port 6379
bind 0.0.0.0
timeout 0
tcp-keepalive 300
dir ${REDIS_DIR}
dbfilename dump.rdb
appendonly ${APPENDONLY_FLAG}
appendfilename "appendonly.aof"
maxmemory ${MAX_MEMORY}
maxmemory-policy allkeys-lru
$(if [ -n "${REQUIRE_PASS}" ]; then echo "requirepass ${REQUIRE_PASS}"; fi)
protected-mode no
EOL

# 5. 打印配置验证（确认变量已被替换）
echo "=== Generated Redis Config ==="
cat "$REDIS_CONF"
echo "=============================="

# 6. 启动Redis
exec redis-server "$REDIS_CONF"