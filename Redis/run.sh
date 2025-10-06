#!/usr/bin/env bash
set -e

# 1. 安全读取并校验配置（保留之前的容错逻辑）
read_and_validate_options() {
  local options_file="/data/options.json"
  local retries=5
  local delay=2
  for ((i=1; i<=retries; i++)); do
    if [ -f "$options_file" ] && [ -r "$options_file" ]; then
      local content=$(cat "$options_file")
      if echo "$content" | jq . >/dev/null 2>&1; then
        echo "$content"
        return 0
      fi
    fi
    sleep $delay
  done
  echo '{"max_memory": "128mb", "require_pass": "", "appendonly": false}'
}

# 2. 解析配置
OPTIONS=$(read_and_validate_options)
MAX_MEMORY=$(echo "$OPTIONS" | jq -r '.max_memory // "128mb"')
REQUIRE_PASS=$(echo "$OPTIONS" | jq -r '.require_pass // ""')
APPENDONLY=$(echo "$OPTIONS" | jq -r '.appendonly // "false"')

# 3. 确定数据目录并确保存在
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  echo "Using backup directory /opt/redis"
  REDIS_DIR="/opt/redis"
fi
mkdir -p "$REDIS_DIR"  # 强制创建目录（关键：确保目录存在）

# 4. 启动Redis时动态指定数据目录（覆盖配置文件中的dir指令）
# 注意：--dir参数会覆盖redis.conf中的dir配置
redis-server /redis.conf --dir "$REDIS_DIR" &
sleep 2  # 等待服务启动

# 5. 动态应用其他配置
if redis-cli ping >/dev/null 2>&1; then
  redis-cli config set maxmemory "$MAX_MEMORY"
  [ "$APPENDONLY" = "true" ] && redis-cli config set appendonly yes
  [ -n "$REQUIRE_PASS" ] && redis-cli config set requirepass "$REQUIRE_PASS"
else
  echo "ERROR: Redis failed to start"
  exit 1
fi

# 6. 保持前台运行
wait