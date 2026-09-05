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
# 尝试多个可能的数据目录位置
for dir_candidate in "/data/redis" "/opt/redis" "/tmp/redis"; do
  if mkdir -p "$dir_candidate" && [ -w "$dir_candidate" ]; then
    REDIS_DIR="$dir_candidate"
    echo "选择数据目录: $REDIS_DIR"
    break
  fi
done

# 如果没有找到可写目录，使用当前目录作为最后的备选
if [ -z "$REDIS_DIR" ]; then
  REDIS_DIR="$(pwd)/redis"
  mkdir -p "$REDIS_DIR"
  echo "警告: 使用当前目录作为数据目录: $REDIS_DIR"
fi

# 5. 启动Redis（动态指定目录）
echo "启动Redis服务器，数据目录: $REDIS_DIR"
echo "使用配置文件: /redis.conf"
echo "内存限制: $MAX_MEMORY"
echo "AOF持久化: ${APPENDONLY,,}"
echo "密码保护: ${REQUIRE_PASS:-(无密码)}"

# 直接使用标准配置文件，通过命令行参数设置密码（如果有）
REDIS_CONF="/etc/redis/redis.conf"

# 直接以当前用户启动Redis，避免用户切换问题
echo "以当前用户启动Redis服务器"

# 将APPENDONLY转换为Redis期望的格式（yes/no）
if [[ "${APPENDONLY,,}" == "true" || "${APPENDONLY,,}" == "yes" ]]; then
  REDIS_APPENDONLY="yes"
else
  REDIS_APPENDONLY="no"
fi
echo "转换AOF持久化设置: 输入=$APPENDONLY, 输出=$REDIS_APPENDONLY"

# 确保/tmp目录存在并可写
mkdir -p /tmp

# 显示内存overcommit警告信息（容器环境中无法直接修改）
echo "⚠️ 警告: Redis建议启用内存overcommit"
echo "⚠️ 这是容器环境限制，不影响正常使用"
echo "⚠️ 如需解决此警告，请在宿主机上执行: sysctl vm.overcommit_memory=1"
echo "⚠️ 或在宿主机的/etc/sysctl.conf中添加: vm.overcommit_memory = 1"

# 前台运行 Redis（daemonize no），输出直接到容器日志
if [ -n "$REQUIRE_PASS" ]; then
  echo "将通过命令行参数设置Redis密码"
  exec redis-server "$REDIS_CONF" --dir "$REDIS_DIR" --maxmemory "$MAX_MEMORY" --appendonly "$REDIS_APPENDONLY" --requirepass "$REQUIRE_PASS"
else
  exec redis-server "$REDIS_CONF" --dir "$REDIS_DIR" --maxmemory "$MAX_MEMORY" --appendonly "$REDIS_APPENDONLY"
fi