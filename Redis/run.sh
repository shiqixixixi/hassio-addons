#!/usr/bin/env bash
set -e  # 脚本出错时立即退出（避免后续逻辑异常）

# -------------------------- 1. 配置初始化（核心：获取HA用户配置） --------------------------
# 定义配置文件路径（HassOS自动生成，存储用户在HA界面的配置）
OPTIONS_FILE="/data/options.json"

# 读取options.json（容错：文件不存在或权限不足时用默认值）
read_options() {
  local retries=3  # 重试3次（应对Supervisor挂载延迟）
  local delay=2
  local options_json

  for ((i=1; i<=retries; i++)); do
    if [ -f "$OPTIONS_FILE" ] && [ -r "$OPTIONS_FILE" ]; then
      # 读取并验证JSON格式（用jq解析，避免格式错误）
      options_json=$(cat "$OPTIONS_FILE" | jq . 2>/dev/null)
      if [ -n "$options_json" ]; then
        echo "$options_json"
        return 0
      fi
    fi
    echo "WARNING: $OPTIONS_FILE not readable (attempt $i/$retries), waiting..."
    sleep $delay
  done

  # 多次失败后返回默认配置（确保应用能启动）
  echo '{"max_memory":"128mb","require_pass":"","appendonly":false}'
}

# 解析配置（用jq提取参数，设置默认值兜底）
OPTIONS_JSON=$(read_options)
MAX_MEMORY=$(echo "$OPTIONS_JSON" | jq -r '.max_memory // "128mb"')
REQUIRE_PASS=$(echo "$OPTIONS_JSON" | jq -r '.require_pass // ""')
APPENDONLY=$(echo "$OPTIONS_JSON" | jq -r '.appendonly // "false"')
TZ="${TZ:-UTC}"  # 继承环境变量的时区，默认UTC

# 调试：打印配置（HA日志中查看，确认参数正确）
echo "=== HassOS Redis Add-on Config ==="
echo "Options JSON: $OPTIONS_JSON"
echo "Max Memory: $MAX_MEMORY"
echo "AOF Persistence: $APPENDONLY"
echo "Password: ${REQUIRE_PASS:-(No Password)}"
echo "Timezone: $TZ"
echo "==================================="

# -------------------------- 2. 应用准备（目录、权限、配置模板） --------------------------
# 处理Redis数据目录（优先用/data/redis，失败则用/opt/redis）
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  echo "WARNING: /data/redis not found, using backup directory /opt/redis"
  REDIS_DIR="/opt/redis"
  mkdir -p "$REDIS_DIR"  # 强制创建目录，避免启动失败
fi

# 生成Redis配置文件（动态替换模板，避免硬编码）
# 若本地有redis.conf模板，可通过sed替换占位符（示例）
# sed -i "s|__MAX_MEMORY__|$MAX_MEMORY|g" /redis.conf
# sed -i "s|__APPENDONLY__|$([ "$APPENDONLY" = "true" ] && echo "yes" || echo "no")|g" /redis.conf

# -------------------------- 3. 启动应用（必须保持前台运行） --------------------------
# 启动Redis（动态指定参数，覆盖默认配置）
# 关键：用exec启动，确保Redis进程成为容器PID=1的进程（HA能正确管理生命周期）
exec redis-server \
  --dir "$REDIS_DIR" \                  # 数据目录
  --maxmemory "$MAX_MEMORY" \           # 内存限制
  --appendonly "$([ "$APPENDONLY" = "true" ] && echo "yes" || echo "no")" \  # AOF持久化
  --requirepass "$REQUIRE_PASS" \       # 密码
  --bind 0.0.0.0 \                      # 允许所有IP访问（HA内部网络安全）
  --protected-mode no                   # 关闭保护模式（HA内部使用，无需外部防护）