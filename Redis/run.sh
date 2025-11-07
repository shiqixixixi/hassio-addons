#!/usr/bin/env bash
set -e

# 1. 显示所有环境变量（用于调试）
echo "=== 容器所有环境变量 ==="
env | grep -E 'max_memory|require_pass|appendonly|TZ|ADDON_|redis'
echo "========================="

# 2. 检查options.json文件权限并打印内容
echo "=== 检查配置文件 /data/options.json 权限 ==="
ls -la /data 2>/dev/null || echo "警告: 无法访问 /data 目录"
if [ -e "/data/options.json" ]; then
  echo "配置文件存在，检查权限..."
  ls -la /data/options.json 2>/dev/null || echo "警告: 无法查看文件详细信息"
  
  echo "=== 配置文件 /data/options.json 内容 ==="
  if command -v jq &> /dev/null; then
    jq . /data/options.json 2>/dev/null || {
      echo "警告: jq解析失败，尝试直接读取..."
      cat /data/options.json 2>/dev/null || echo "错误: 无法读取文件内容"
    }
  else
    cat /data/options.json 2>/dev/null || echo "错误: 无法读取文件内容"
  fi
  echo "========================================"
else
  echo "警告: 配置文件 /data/options.json 不存在或无法访问"
fi

# 1. 读取从 config.yaml 注入的配置选项
# 设置默认值
MAX_MEMORY="128mb"
REQUIRE_PASS=""
APPENDONLY="false"
TZ="${TZ:-UTC}"
REDIS_DIR="/data/redis"

# 尝试以多种方式读取配置文件，确保权限安全
CONFIG_READ_SUCCEEDED=false

# 首先尝试从 /data/options.json 文件读取配置（Home Assistant addon标准做法）
if [ -e "/data/options.json" ]; then
  echo "尝试读取 /data/options.json 配置..."
  
  # 首先检查读取权限
  if [ -r "/data/options.json" ]; then
    echo "配置文件有读取权限，尝试解析..."
    # 使用jq工具解析JSON配置文件
    if command -v jq &> /dev/null; then
      # 安全读取配置，避免空值和错误
      MAX_MEMORY=$(jq -r '.max_memory // "128mb"' /data/options.json 2>/dev/null || echo "128mb")
      REQUIRE_PASS=$(jq -r '.require_pass // ""' /data/options.json 2>/dev/null || echo "")
      APPENDONLY=$(jq -r '.appendonly // "false"' /data/options.json 2>/dev/null || echo "false")
      
      echo "从options.json读取到max_memory: $MAX_MEMORY"
      echo "从options.json读取到require_pass: ${REQUIRE_PASS:-(无密码)}"
      echo "从options.json读取到appendonly: $APPENDONLY"
      
      CONFIG_READ_SUCCEEDED=true
    else
      echo "警告: 未找到jq工具，无法解析options.json"
    fi
  else
    echo "警告: 配置文件存在但没有读取权限，尝试其他方式..."
    # 尝试使用sudo或其他方式读取（如果可用）
    if command -v sudo &> /dev/null; then
      echo "尝试使用sudo读取配置..."
      MAX_MEMORY=$(sudo jq -r '.max_memory // "128mb"' /data/options.json 2>/dev/null || echo "128mb")
      REQUIRE_PASS=$(sudo jq -r '.require_pass // ""' /data/options.json 2>/dev/null || echo "")
      APPENDONLY=$(sudo jq -r '.appendonly // "false"' /data/options.json 2>/dev/null || echo "false")
      
      echo "从options.json读取到max_memory: $MAX_MEMORY"
      echo "从options.json读取到require_pass: ${REQUIRE_PASS:-(无密码)}"
      echo "从options.json读取到appendonly: $APPENDONLY"
      
      CONFIG_READ_SUCCEEDED=true
    fi
  fi
else
  echo "配置文件 /data/options.json 不存在或无法访问，将使用环境变量或默认值"
fi

if [ "$CONFIG_READ_SUCCEEDED" = true ]; then
  echo "配置读取成功"
else
  echo "配置读取失败，将尝试使用环境变量作为备选"
  # 从环境变量读取配置
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

# 确保数据目录权限正确
chown -R 1000:1000 "$REDIS_DIR" 2>/dev/null || echo "警告: 无法更改数据目录权限，但将继续尝试启动"
chmod -R 755 "$REDIS_DIR" 2>/dev/null || echo "警告: 无法设置数据目录权限，但将继续尝试启动"

# 启动Redis服务器，切换到用户1000（redis用户）以保证安全性
# 使用gosu可以更好地处理信号传递
if command -v gosu &> /dev/null; then
  echo "使用gosu切换到用户1000启动Redis"
  gosu 1000 redis-server /redis.conf --dir "$REDIS_DIR" --maxmemory "$MAX_MEMORY" --appendonly "${APPENDONLY,,}" &
else
  # 如果没有gosu，则尝试使用su
  if command -v su &> /dev/null; then
    echo "使用su切换到用户1000启动Redis"
    su -s /bin/sh -c "redis-server /redis.conf --dir '$REDIS_DIR' --maxmemory '$MAX_MEMORY' --appendonly '${APPENDONLY,,}'" 1000 &
  else
    # 如果都不可用，直接以当前用户运行
    echo "警告: 无法切换用户，将以当前用户启动Redis"
    redis-server /redis.conf --dir "$REDIS_DIR" --maxmemory "$MAX_MEMORY" --appendonly "${APPENDONLY,,}" &
  fi
fi
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