#!/usr/bin/env bash
set -e

# 1. 强制修复options.json权限（HassOS可能动态重置权限，这里冗余处理）
if [ -f "/data/options.json" ]; then
  chmod 644 /data/options.json  # 临时赋予读权限（仅本次运行有效）
else
  echo "ERROR: /data/options.json not found! Using defaults."
fi

# 1. 直接从HassOS加载项配置文件读取参数（核心！不依赖环境变量）
# HassOS加载项的配置文件路径固定为 /data/options.json
OPTIONS=$(cat /data/options.json)
MAX_MEMORY=$(echo "$OPTIONS" | jq -r '.max_memory')
REQUIRE_PASS=$(echo "$OPTIONS" | jq -r '.require_pass')
APPENDONLY=$(echo "$OPTIONS" | jq -r '.appendonly')

# 2. 处理默认值
MAX_MEMORY=${MAX_MEMORY:-"128mb"}
APPENDONLY=${APPENDONLY:-"false"}

# 2. 目录检测与兜底（已验证有效）
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  echo "WARNING: /data/redis not found, use backup dir /opt/redis"
  REDIS_DIR="/opt/redis"
fi
REDIS_CONF="${REDIS_DIR}/redis.conf"

# 3. 处理appendonly格式（true/false → yes/no）# 4. 处理appendonly和密码
APPENDONLY_FLAG="no"
if [ "$APPENDONLY" = "true" ]; then
  APPENDONLY_FLAG="yes"
fi
REQUIRE_PASS_LINE=""
if [ -n "$REQUIRE_PASS" ]; then
  REQUIRE_PASS_LINE="requirepass $REQUIRE_PASS"
fi

# 5. 用sed替换模板中的占位符，生成最终配置
sed \
  -e "s|__REDIS_DIR__|$REDIS_DIR|g" \
  -e "s|__APPENDONLY__|$APPENDONLY_FLAG|g" \
  -e "s|__MAX_MEMORY__|$MAX_MEMORY|g" \
  -e "s|__REQUIRE_PASS__|$REQUIRE_PASS_LINE|g" \
  /redis.conf.template > "$REDIS_DIR/redis.conf"


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