#!/usr/bin/env bash
set -e

# 1. 读取配置参数（从options.json或环境变量，方法同前）
OPTIONS=$(cat /data/options.json 2>/dev/null)
MAX_MEMORY=$(echo "$OPTIONS" | jq -r '.max_memory // "128mb"')
REQUIRE_PASS=$(echo "$OPTIONS" | jq -r '.require_pass // ""')
APPENDONLY=$(echo "$OPTIONS" | jq -r '.appendonly // "false"')

# 2. 启动Redis（使用静态配置）
redis-server /redis.conf &  # 后台启动，等待初始化
sleep 2  # 等待服务启动

# 3. 动态修改配置（通过redis-cli执行命令）
redis-cli config set maxmemory "$MAX_MEMORY"
[ "$APPENDONLY" = "true" ] && redis-cli config set appendonly yes
[ -n "$REQUIRE_PASS" ] && redis-cli config set requirepass "$REQUIRE_PASS"

# 4. 前台运行Redis（接管进程）
wait  # 等待后台进程，确保不退出