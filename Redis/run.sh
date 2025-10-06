#!/usr/bin/env bash
set -e

# 1. 读取从config.yaml传递的环境变量（与HA加载项配置对应）
MAX_MEMORY=${MAX_MEMORY:-"128mb"}
APPENDONLY=${APPENDONLY:-"false"}
REQUIRE_PASS=${REQUIRE_PASS:-""}
TZ=${TZ:-"UTC"}

# 2. 关键：目录检测与兜底（解决HassOS挂载后目录丢失问题）
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  echo "WARNING: /data/redis not found (HassOS mount issue), use backup dir /opt/redis"
  REDIS_DIR="/opt/redis"  # 切换到备用目录
fi
REDIS_CONF="${REDIS_DIR}/redis.conf"  # 配置文件路径随目录切换

# 3. 处理appendonly格式（true/false → yes/no）
APPENDONLY_FLAG="no"
if [ "$APPENDONLY" = "true" ]; then
  APPENDONLY_FLAG="yes"
fi

# 4. 生成Redis配置（路径已确保存在，可正常写入）
cat > "$REDIS_CONF" <<EOL
daemonize no
pidfile /var/run/redis/redis.pid
port 6379
bind 0.0.0.0
timeout 0
tcp-keepalive 300
tz ${TZ}  # 继承HA时区

dir ${REDIS_DIR}  # 数据目录随检测结果切换（持久化或备用）
dbfilename dump.rdb
appendonly ${APPENDONLY_FLAG}
appendfilename "appendonly.aof"

maxmemory ${MAX_MEMORY}
maxmemory-policy allkeys-lru

$(if [ -n "${REQUIRE_PASS}" ]; then echo "requirepass ${REQUIRE_PASS}"; fi)
protected-mode no  # 允许HA内部组件访问
EOL

# 5. 打印日志（HA加载项日志中可查看，确认目录和配置）
echo "=== HassOS Redis Add-on Status ==="
echo "Using Redis dir: ${REDIS_DIR}"
echo "Generated Config:"
cat "$REDIS_CONF"
echo "=================================="

# 6. 启动Redis（用确认存在的配置文件路径）
exec redis-server "$REDIS_CONF"