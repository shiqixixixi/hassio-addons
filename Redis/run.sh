#!/usr/bin/env bash
set -e

# Redis 配置文件路径
REDIS_CONF="/data/redis/redis.conf"

# 关键修复：确保父目录存在并设置权限
mkdir -p /data/redis  # 创建目录（-p 确保多级目录都能创建，且已存在时不报错）
chmod 755 /data/redis  # 赋予读写执行权限（适配容器内用户）

# 处理 appendonly 格式（true/false → yes/no）
if [ "$APPENDONLY" = "true" ]; then
  APPENDONLY="yes"
else
  APPENDONLY="no"
fi

# 生成配置文件（此时目录已存在，可正常写入）
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