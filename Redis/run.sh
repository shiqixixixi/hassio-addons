#!/usr/bin/env bash
set -e

# 1. 安全读取options.json（带重试和默认值，不修改权限）
read_options() {
  local retries=5
  local delay=2
  local options_file="/data/options.json"
  
  # 重试读取，应对挂载延迟导致的临时不可读
  for ((i=1; i<=retries; i++)); do
    if [ -f "$options_file" ] && [ -r "$options_file" ]; then
      # 成功读取，返回配置
      cat "$options_file"
      return 0
    fi
    echo "WARNING: $options_file not readable (attempt $i/$retries), waiting..."
    sleep $delay
  done
  
  # 多次失败后返回默认配置JSON
  echo '{"max_memory": "128mb", "require_pass": "", "appendonly": false}'
}

# 2. 解析配置（从读取结果中提取，确保有值）
OPTIONS=$(read_options)
MAX_MEMORY=$(echo "$OPTIONS" | jq -r '.max_memory')
REQUIRE_PASS=$(echo "$OPTIONS" | jq -r '.require_pass')
APPENDONLY=$(echo "$OPTIONS" | jq -r '.appendonly')

# 3. 目录处理（确保数据目录可用）
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  echo "Using backup directory /opt/redis"
  REDIS_DIR="/opt/redis"
  mkdir -p "$REDIS_DIR"  # 确保备用目录存在
fi

# 4. 启动Redis并动态配置（绕开配置文件变量）
# 先启动Redis（用基础配置）
redis-server /redis.conf --dir "$REDIS_DIR" &
sleep 2  # 等待服务就绪

# 动态应用配置（无论参数是否读取成功，均有默认值）
redis-cli config set maxmemory "${MAX_MEMORY:-128mb}"
[ "${APPENDONLY:-false}" = "true" ] && redis-cli config set appendonly yes
[ -n "${REQUIRE_PASS}" ] && redis-cli config set requirepass "${REQUIRE_PASS}"

# 5. 保持前台运行（HassOS要求）
wait