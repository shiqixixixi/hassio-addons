#!/usr/bin/env bash
set -e

# 1. 显示所有环境变量（用于调试）
echo "=== 容器所有环境变量 ==="
env | grep -E 'max_memory|require_pass|appendonly|TZ|ADDON_|redis'
echo "========================="

# 2. 检查options.json文件权限并打印内容
echo "=== 检查配置文件 /data/options.json 权限 ==="
# 简单检查文件是否存在和可读
if [ -f "/data/options.json" ] && [ -r "/data/options.json" ]; then
  echo "配置文件存在且可读"
  
  echo "=== 配置文件 /data/options.json 内容 ==="
  if command -v jq &> /dev/null; then
    jq . /data/options.json || echo "警告: jq解析出错，但将继续尝试读取"
  else
    echo "jq不可用，显示原始内容:"
    cat /data/options.json
  fi
  echo "========================================"
else
  echo "警告: 配置文件 /data/options.json 不存在或不可读"
fi

# 3. 读取配置（从options.json或环境变量）
# 设置默认值
MAX_MEMORY="128mb"
REQUIRE_PASS=""
APPENDONLY="false"
TZ="${TZ:-UTC}"
REDIS_DIR="/data/redis"

# 首先尝试从 /data/options.json 文件读取配置（Home Assistant addon标准做法）
if [ -f "/data/options.json" ] && [ -r "/data/options.json" ] && command -v jq &> /dev/null; then
  echo "从 /data/options.json 读取配置..."
  # 安全读取配置，避免空值和错误
  MAX_MEMORY=$(jq -r '.max_memory // "128mb"' /data/options.json 2>/dev/null || echo "128mb")
  REQUIRE_PASS=$(jq -r '.require_pass // ""' /data/options.json 2>/dev/null || echo "")
  APPENDONLY=$(jq -r '.appendonly // "false"' /data/options.json 2>/dev/null || echo "false")
  
  echo "从options.json读取到max_memory: $MAX_MEMORY"
  echo "从options.json读取到require_pass: ${REQUIRE_PASS:-(无密码)}"
  echo "从options.json读取到appendonly: $APPENDONLY"
else
  echo "从环境变量读取配置..."
  # 尝试多种可能的命名格式以确保兼容性
  MAX_MEMORY="${max_memory:-${MAX_MEMORY:-${ADDON_MAX_MEMORY:-128mb}}}"
  REQUIRE_PASS="${require_pass:-${REQUIRE_PASS:-${ADDON_REQUIRE_PASS:-}}}"
  APPENDONLY="${appendonly:-${APPENDONLY:-${ADDON_APPENDONLY:-false}}}"
fi

# 2. 调试打印：确认变量是否正确读取（建议保留，方便排查问题）
echo "=== 读取到的环境变量 ==="
echo "内存限制 (MAX_MEMORY): $MAX_MEMORY"
echo "AOF持久化 (APPENDONLY): $APPENDONLY"
echo "密码 (REQUIRE_PASS): ${REQUIRE_PASS:-(无密码)}"
echo "时区 (TZ): $TZ"
echo "======================"

# 3. 处理数据目录（确保存在）
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  echo "使用备用目录 /opt/redis"
  REDIS_DIR="/opt/redis"
fi
mkdir -p "$REDIS_DIR"  # 强制创建目录，避免路径错误

# 5. 启动Redis（动态指定目录）
echo "启动Redis服务器，数据目录: $REDIS_DIR"
echo "使用配置文件: /redis.conf"
echo "内存限制: $MAX_MEMORY"
echo "AOF持久化: ${APPENDONLY,,}"
echo "密码保护: ${REQUIRE_PASS:-(无密码)}"

# 确保数据目录存在且权限正确
mkdir -p "$REDIS_DIR"
chown -R redis:redis "$REDIS_DIR" 2>/dev/null || echo "警告: 无法更改数据目录权限，但将继续尝试启动"
chmod -R 755 "$REDIS_DIR" 2>/dev/null || echo "警告: 无法设置数据目录权限，但将继续尝试启动"

# 启动Redis服务器，使用redis用户运行以保证安全性
# gosu比su更好，因为它正确处理信号传递
if command -v gosu &> /dev/null; then
  echo "使用gosu切换到redis用户启动Redis"
  gosu redis redis-server /redis.conf --dir "$REDIS_DIR" --maxmemory "$MAX_MEMORY" --appendonly "${APPENDONLY,,}" &
  REDIS_PID=$!
else
  echo "警告: gosu不可用，将使用redis用户直接启动"
  # 直接以redis用户启动
  runuser -u redis -- redis-server /redis.conf --dir "$REDIS_DIR" --maxmemory "$MAX_MEMORY" --appendonly "${APPENDONLY,,}" &
  REDIS_PID=$!
fi

# 等待Redis启动
sleep 2

# 5. 设置密码（如果有）
if [ -n "$REQUIRE_PASS" ]; then
  echo "正在设置Redis密码..."
  # 使用redis-cli设置密码
  if redis-cli config set requirepass "$REQUIRE_PASS" >/dev/null 2>&1; then
    echo "密码设置成功"
  else
    echo "警告: 密码设置失败，但Redis仍将继续运行"
  fi
else
  echo "未设置密码，Redis将以无密码模式运行"
fi

# 6. 保持前台运行（HassOS要求）
echo "Redis服务器已启动，PID: $REDIS_PID"
# 使用wait命令等待Redis进程，确保容器不会退出
wait $REDIS_PID