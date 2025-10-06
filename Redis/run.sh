#!/usr/bin/env bash
set -e

# 1. 安全读取并校验 options.json（不修改权限，仅读取）
read_and_validate_options() {
  local options_file="/data/options.json"
  local retries=5
  local delay=2

  # 重试读取，等待文件生成
  for ((i=1; i<=retries; i++)); do
    if [ -f "$options_file" ] && [ -r "$options_file" ]; then
      # 读取文件内容
      local content=$(cat "$options_file")
      
      # 校验 JSON 格式（用 jq 测试解析）
      if echo "$content" | jq . >/dev/null 2>&1; then
        echo "$content"  # 格式正确，返回内容
        return 0
      else
        echo "WARNING: $options_file has invalid JSON (attempt $i/$retries)"
      fi
    fi
    sleep $delay
  done

  # 多次失败后返回安全默认配置
  echo '{"max_memory": "128mb", "require_pass": "", "appendonly": false}'
}

# 2. 解析配置（确保 jq 不会崩溃）
OPTIONS=$(read_and_validate_options)
MAX_MEMORY=$(echo "$OPTIONS" | jq -r '.max_memory // "128mb"')
REQUIRE_PASS=$(echo "$OPTIONS" | jq -r '.require_pass // ""')
APPENDONLY=$(echo "$OPTIONS" | jq -r '.appendonly // "false"')

# 3. 处理数据目录
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  echo "Using backup directory /opt/redis"
  REDIS_DIR="/opt/redis"
  mkdir -p "$REDIS_DIR"
fi

# 4. 启动 Redis 并动态应用配置
redis-server /redis.conf --dir "$REDIS_DIR" &
sleep 2  # 等待服务启动

# 动态设置参数（兼容各种场景）
redis-cli config set maxmemory "${MAX_MEMORY}"
[ "$APPENDONLY" = "true" ] && redis-cli config set appendonly yes
[ -n "$REQUIRE_PASS" ] && redis-cli config set requirepass "$REQUIRE_PASS"

# 5. 保持前台运行
wait