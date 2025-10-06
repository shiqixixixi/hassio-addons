#!/usr/bin/env bash
set -e

# 1. 读取从 config.yaml 的 environment 注入的环境变量
# 变量名与 environment 中定义的键完全一致（如 REDIS_MAX_MEMORY、TZ 等）
# 同时设置默认值，防止未注入时出错
MAX_MEMORY="${REDIS_MAX_MEMORY:-128mb}"       # 对应 REDIS_MAX_MEMORY: "{{ max_memory }}"
REQUIRE_PASS="${REDIS_REQUIRE_PASS:-}"        # 对应 REDIS_REQUIRE_PASS: "{{ require_pass }}"
APPENDONLY="${REDIS_APPENDONLY:-false}"       # 对应 REDIS_APPENDONLY: "{{ appendonly }}"
TZ="${TZ:-UTC}"                               # 对应 TZ: "{{ TZ }}"（继承HA时区）

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
if redis-cli ping >/dev/null 2>&1; then
  # 应用内存限制
  redis-cli config set maxmemory "$MAX_MEMORY"
  # 应用AOF持久化设置（true→yes，false→no）
  if [ "$APPENDONLY" = "true" ]; then
    redis-cli config set appendonly yes
  else
    redis-cli config set appendonly no
  fi
  # 应用密码（若有）
  if [ -n "$REQUIRE_PASS" ]; then
    redis-cli config set requirepass "$REQUIRE_PASS"
  else
    redis-cli config set requirepass ""  # 清空密码
  fi
  echo "配置已成功应用到Redis"
else
  echo "ERROR: Redis启动失败，无法应用配置"
  exit 1
fi

# 6. 保持前台运行（HassOS要求）
wait