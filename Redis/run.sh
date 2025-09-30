#!/usr/bin/env bash
set -e

REDIS_CONF="/data/redis/redis.conf"

# 处理 appendonly 格式（将 true/false 转换为 yes/no）
if [ "$APPENDONLY" = "true" ]; then
  APPENDONLY="yes"
else
  APPENDONLY="no"
fi

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

exec redis-server "$REDIS_CONF"