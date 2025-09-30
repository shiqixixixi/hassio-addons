#!/usr/bin/env bash
set -e

# Redis 配置文件路径（容器内，目录已由 Dockerfile 创建）
REDIS_CONF="/data/redis/redis.conf"

# 处理 appendonly 格式（true/false → yes/no）
if [ "$APPENDONLY" = "true" ]; then
  APPENDONLY="yes"
else
  APPENDONLY="no"
fi

# 直接生成配置文件（此时 redis 用户有权限写入 /data/redis）
cat > "$REDIS_CONF" <<EOL
daemonize no
pidfile /var/run/redis.pid
port 6379
bind 0.0.0.0
timeout 0
tcp-keepalive 300

dir /data/redis
dbfilename dump.rdb
appendonly ${APPENDONLY}
appendfilename "appendonly.aof"

maxmemory ${MAX_MEMORY}
maxmemory-policy allkeys-lru

$(if [ -n "${REQUIRE_PASS}" ]; then echo "requirepass ${REQUIRE_PASS}"; fi)
EOL

echo "Redis configuration generated:"
cat "$REDIS_CONF"

# 启动 Redis 服务
exec redis-server "$REDIS_CONF"