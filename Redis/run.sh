#!/usr/bin/env bash
set -e

# 1. 从HassOS配置文件读取参数（路径固定）
OPTIONS=$(cat /data/options.json)
MAX_MEMORY=$(echo "$OPTIONS" | jq -r '.max_memory // "128mb"')  # 直接用jq设置默认值
REQUIRE_PASS=$(echo "$OPTIONS" | jq -r '.require_pass // ""')
APPENDONLY=$(echo "$OPTIONS" | jq -r '.appendonly // "false"')

# 2. 目录处理
REDIS_DIR="/data/redis"
[ ! -d "$REDIS_DIR" ] && REDIS_DIR="/opt/redis"

# 3. 拼接配置内容
CONFIG_CONTENT="daemonize no
pidfile /var/run/redis/redis.pid
port 6379
bind 0.0.0.0
timeout 0
tcp-keepalive 300
dir $REDIS_DIR
dbfilename dump.rdb
appendonly $( [ "$APPENDONLY" = "true" ] && echo "yes" || echo "no" )
appendfilename \"appendonly.aof\"
maxmemory $MAX_MEMORY
maxmemory-policy allkeys-lru
$( [ -n "$REQUIRE_PASS" ] && echo "requirepass $REQUIRE_PASS" )
protected-mode no"

# 4. 写入配置文件
echo "$CONFIG_CONTENT" > "$REDIS_DIR/redis.conf"

# 5. 启动Redis
exec redis-server "$REDIS_DIR/redis.conf"