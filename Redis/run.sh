#!/usr/bin/env bash
set -e

# 在脚本开头添加，打印所有环境变量
echo "=== 容器所有环境变量 ==="
env | grep -E "max_memory|require_pass|appendonly|TZ|ADDON_"  # 过滤所有可能的配置变量
echo "======================"

# 1. 读取从 config.yaml 注入的配置选项
# Home Assistant addon系统会将options作为环境变量注入，使用直接名称或ADDON_前缀
# 尝试多种可能的命名格式以确保兼容性
MAX_MEMORY="${max_memory:-${MAX_MEMORY:-${ADDON_MAX_MEMORY:-128mb}}}"       # 对应 config.yaml 中的 max_memory
REQUIRE_PASS="${require_pass:-${REQUIRE_PASS:-${ADDON_REQUIRE_PASS:-}}}"    # 对应 config.yaml 中的 require_pass
APPENDONLY="${appendonly:-${APPENDONLY:-${ADDON_APPENDONLY:-false}}}"       # 对应 config.yaml 中的 appendonly
TZ="${TZ:-UTC}"                                                           # 时区设置

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
redis-server /redis.conf --dir "$REDIS_DIR" &
sleep 2  # 等待服务启动

# 5. 动态应用配置（将读取到的变量同步到Redis）
# 构建redis-cli命令，根据是否有密码添加认证参数
REDIS_CLI="redis-cli"
if [ -n "$REQUIRE_PASS" ]; then
  # 如果设置了密码，先不使用认证连接，因为密码还未设置
  # 先应用其他配置，最后设置密码
  if redis-cli ping >/dev/null 2>&1; then
    # 应用内存限制
    redis-cli config set maxmemory "$MAX_MEMORY"
    # 应用AOF持久化设置（true→yes，false→no）
    if [ "$APPENDONLY" = "true" ]; then
      redis-cli config set appendonly yes
    else
      redis-cli config set appendonly no
    fi
    # 最后设置密码
    redis-cli config set requirepass "$REQUIRE_PASS"
    echo "配置已成功应用到Redis（已设置密码）"
  else
    echo "ERROR: Redis启动失败，无法应用配置"
    exit 1
  fi
else
  # 没有密码时的处理
  if redis-cli ping >/dev/null 2>&1; then
    # 应用内存限制
    redis-cli config set maxmemory "$MAX_MEMORY"
    # 应用AOF持久化设置（true→yes，false→no）
    if [ "$APPENDONLY" = "true" ]; then
      redis-cli config set appendonly yes
    else
      redis-cli config set appendonly no
    fi
    # 确保密码为空
    redis-cli config set requirepass ""
    echo "配置已成功应用到Redis（无密码）"
  else
    echo "ERROR: Redis启动失败，无法应用配置"
    exit 1
  fi
fi

# 6. 保持前台运行（HassOS要求）
wait