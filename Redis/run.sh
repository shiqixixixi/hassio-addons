#!/usr/bin/env bash
set -e  # 出错时退出

# 关键：创建 Redis 数据目录（确保父目录存在）
mkdir -p /data/redis && chown -R redis:redis /data/redis

# Redis 配置文件路径（容器内）
REDIS_CONF="/data/redis/redis.conf"

# 处理 appendonly 格式（将 true/false 转换为 yes/no）
if [ "$APPENDONLY" = "true" ]; then
  APPENDONLY="yes"
else
  APPENDONLY="no"
fi

# 创建配置文件（基于用户配置动态生成）
cat > "$REDIS_CONF" <<EOL
# 基础配置
daemonize no
pidfile /var/run/redis.pid
port 6379
bind 0.0.0.0  # 允许所有网络访问（HassOS 内部网络隔离）
timeout 0
tcp-keepalive 300

# 数据持久化
dir /data/redis
dbfilename dump.rdb
appendonly ${APPENDONLY}
appendfilename "appendonly.aof"

# 内存限制
maxmemory ${MAX_MEMORY}
maxmemory-policy allkeys-lru  # 内存满时删除最少使用的键

# 安全配置（如果用户设置了密码）
$(if [ -n "${REQUIRE_PASS}" ]; then echo "requirepass ${REQUIRE_PASS}"; fi)
EOL

# 打印配置信息（方便调试）
echo "Redis configuration generated:"
cat "$REDIS_CONF"

# 启动 Redis 服务（使用生成的配置）
exec redis-server "$REDIS_CONF"