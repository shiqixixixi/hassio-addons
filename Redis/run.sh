#!/usr/bin/env bash
set -e

# 1. 读取从config.yaml传递的环境变量（确保变量名与config.yaml的environment映射一致）
MAX_MEMORY="${MAX_MEMORY:-128mb}"  # 注意：这里必须用双引号，避免变量为空时语法错误
APPENDONLY="${APPENDONLY:-false}"
REQUIRE_PASS="${REQUIRE_PASS:-}"  # 允许空密码
TZ="${TZ:-UTC}"

# 2. 目录检测与兜底（保持不变，已生效）
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  echo "WARNING: /data/redis not found (HassOS mount issue), use backup dir /opt/redis"
  REDIS_DIR="/opt/redis"
fi
REDIS_CONF="${REDIS_DIR}/redis.conf"

# 3. 处理appendonly格式（true/false → yes/no）
APPENDONLY_FLAG="no"
if [ "$APPENDONLY" = "true" ]; then
  APPENDONLY_FLAG="yes"
fi

# 4. 生成Redis配置（删除tz指令，修正环境变量替换）
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

maxmemory ${MAX_MEMORY}  # 这里用的是脚本中定义的变量（已从config.yaml映射）
maxmemory-policy allkeys-lru

$(if [ -n "${REQUIRE_PASS}" ]; then echo "requirepass ${REQUIRE_PASS}"; fi)
protected-mode no
EOL

# 5. 打印日志验证
echo "=== HassOS Redis Add-on Status ==="
echo "Using Redis dir: ${REDIS_DIR}"
echo "Generated Config:"
cat "$REDIS_CONF"
echo "=================================="

# 6. 启动Redis
exec redis-server "$REDIS_CONF"