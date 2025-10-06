#!/usr/bin/env bash
set -e

# 1. 适配HassOS环境变量：从HassOS加载项配置中读取参数（支持界面修改）
# 若未设置，使用默认值
MAX_MEMORY=${MAX_MEMORY:-"128mb"}
APPENDONLY=${APPENDONLY:-"false"}
REQUIRE_PASS=${REQUIRE_PASS:-""}

# 2. Redis配置文件路径（必须在/data目录下，HassOS才允许写入）
REDIS_CONF="/data/redis/redis.conf"

# 3. 处理appendonly格式（true/false → yes/no）
APPENDONLY_FLAG="no"
if [ "$APPENDONLY" = "true" ]; then
  APPENDONLY_FLAG="yes"
fi

# 4. 生成Redis配置（适配HassOS权限，避免路径错误）
cat > "$REDIS_CONF" <<EOL
daemonize no
pidfile /var/run/redis/redis.pid  # 临时目录，HassOS允许写入
port 6379
bind 0.0.0.0  # 允许HassOS内部其他组件访问
timeout 0
tcp-keepalive 300

dir /data/redis  # 数据持久化到HassOS的/data目录，重启不丢失
dbfilename dump.rdb
appendonly ${APPENDONLY_FLAG}
appendfilename "appendonly.aof"

maxmemory ${MAX_MEMORY}
maxmemory-policy allkeys-lru

# 密码配置（支持HassOS界面设置）
$(if [ -n "${REQUIRE_PASS}" ]; then echo "requirepass ${REQUIRE_PASS}"; fi)

# HassOS兼容：关闭保护模式（允许内部组件访问）
protected-mode no
EOL

# 5. 打印配置（HassOS加载项日志中可查看，方便调试）
echo "=== HassOS Redis Add-on Config ==="
cat "$REDIS_CONF"
echo "=================================="

# 6. 启动Redis（直接用HassOS分配的用户运行）
exec redis-server "$REDIS_CONF"