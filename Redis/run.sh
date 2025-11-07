#!/usr/bin/env bash
set -e

# 在脚本开头添加，打印所有环境变量
echo "=== 容器所有环境变量 ==="
echo "查看是否存在options.json文件:"
if [ -f "/data/options.json" ]; then
  echo "/data/options.json 文件存在"
  # 尝试打印文件内容（如果jq可用）
  if command -v jq &> /dev/null; then
    echo "options.json内容:" 
    cat /data/options.json | jq
  else
    echo "jq工具不可用，无法格式化显示options.json"
    echo "原始内容:" 
    cat /data/options.json
  fi
else
  echo "/data/options.json 文件不存在"
fi
echo "
环境变量:" 
env | grep -E "max_memory|require_pass|appendonly|TZ|ADDON_|redis"  # 过滤所有可能的配置变量
echo "======================"

# 1. 读取从 config.yaml 注入的配置选项
# 设置默认值
MAX_MEMORY="128mb"
REQUIRE_PASS=""
APPENDONLY="false"
TZ="${TZ:-UTC}"

# 首先尝试从 /data/options.json 文件读取配置（Home Assistant addon标准做法）
if [ -f "/data/options.json" ]; then
  echo "从 /data/options.json 读取配置..."
  # 使用jq工具解析JSON配置文件
  if command -v jq &> /dev/null; then
    # 读取各个配置项，如果存在则覆盖默认值
    if jq -e '.max_memory' /data/options.json &> /dev/null; then
      MAX_MEMORY=$(jq -r '.max_memory' /data/options.json)
      echo "从options.json读取到max_memory: $MAX_MEMORY"
    fi
    
    if jq -e '.require_pass' /data/options.json &> /dev/null; then
      REQUIRE_PASS=$(jq -r '.require_pass' /data/options.json)
      echo "从options.json读取到require_pass: ${REQUIRE_PASS:-(无密码)}"
    fi
    
    if jq -e '.appendonly' /data/options.json &> /dev/null; then
      APPENDONLY=$(jq -r '.appendonly' /data/options.json)
      echo "从options.json读取到appendonly: $APPENDONLY"
    fi
  else
    echo "警告: 未找到jq工具，无法解析options.json"
  fi
fi

# 如果从options.json未读取到配置，尝试从环境变量读取
if [ "$MAX_MEMORY" = "128mb" ]; then
  echo "尝试从环境变量读取配置..."
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

# 4. 启动Redis（动态指定目录）
echo "启动Redis服务器，数据目录: $REDIS_DIR"
echo "使用配置文件: /redis.conf"
echo "内存限制: $MAX_MEMORY"
echo "AOF持久化: ${APPENDONLY,,}"
echo "密码保护: ${REQUIRE_PASS:-(无密码)}"

# 启动Redis服务器（不使用exec，这样可以继续执行后续代码）
redis-server /redis.conf --dir "$REDIS_DIR" --maxmemory "$MAX_MEMORY" --appendonly "${APPENDONLY,,}" &
REDIS_PID=$!

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