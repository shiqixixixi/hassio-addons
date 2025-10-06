#!/usr/bin/env bash
set -e  # 脚本出错时立即退出，避免后续逻辑异常

# -------------------------- 1. 解析配置文件（核心：用jq读取options.json） --------------------------
# HassOS自动将用户配置生成到/data/options.json，无需手动创建
CONFIG_PATH="/data/options.json"

# 容错读取：处理文件不存在、权限不足、JSON格式错误三种情况
# 若解析失败，自动使用默认配置（确保Redis能启动）
read_options() {
  local retries=3  # 重试3次（应对HassOS挂载目录延迟）
  local delay=2    # 每次重试间隔2秒
  local options_json

  for ((i=1; i<=retries; i++)); do
    # 检查文件是否存在且可读
    if [ -f "$CONFIG_PATH" ] && [ -r "$CONFIG_PATH" ]; then
      # 用jq验证JSON格式，格式错误则返回空
      options_json=$(cat "$CONFIG_PATH" | jq . 2>/dev/null)
      # 若解析结果非空，返回有效JSON
      if [ -n "$options_json" ] && [ "$options_json" != "null" ]; then
        echo "$options_json"
        return 0
      fi
      echo "WARNING: $CONFIG_PATH 格式错误（尝试 $i/$retries）"
    else
      echo "WARNING: $CONFIG_PATH 不存在或不可读（尝试 $i/$retries）"
    fi
    sleep $delay
  done

  # 多次失败后，返回默认配置（确保Redis能启动）
  echo '{"max_memory":"128mb","require_pass":"","appendonly":false,"TZ":"UTC"}'
}

# 执行读取逻辑，获取有效配置
OPTIONS_JSON=$(read_options)

# 解析具体配置项（// 用于设置默认值，避免字段缺失）
MAX_MEMORY=$(echo "$OPTIONS_JSON" | jq -r '.max_memory // "128mb"')
REQUIRE_PASS=$(echo "$OPTIONS_JSON" | jq -r '.require_pass // ""')
APPENDONLY=$(echo "$OPTIONS_JSON" | jq -r '.appendonly // "false"')
TZ=$(echo "$OPTIONS_JSON" | jq -r '.TZ // "UTC"')  # 继承HA系统时区

# -------------------------- 2. 调试打印（确认配置正确，便于排查问题） --------------------------
echo "=== Redis Add-on 配置信息 ==="
echo "配置文件内容: $OPTIONS_JSON"
echo "内存限制: $MAX_MEMORY"
echo "AOF持久化: $APPENDONLY"
echo "访问密码: ${REQUIRE_PASS:-(未设置密码)}"
echo "系统时区: $TZ"
echo "============================="

# -------------------------- 3. 处理数据目录（确保目录存在，避免启动失败） --------------------------
REDIS_DIR="/data/redis"
if [ ! -d "$REDIS_DIR" ]; then
  echo "WARNING: 主数据目录 $REDIS_DIR 不存在，使用备用目录 /opt/redis"
  REDIS_DIR="/opt/redis"
  # 强制创建备用目录（防止目录未生成）
  mkdir -p "$REDIS_DIR"
fi

# -------------------------- 4. 启动Redis（动态应用配置，保持前台运行） --------------------------
# 转换AOF参数：Redis要求yes/no，HA界面配置是true/false
AOF_FLAG="$([ "$APPENDONLY" = "true" ] && echo "yes" || echo "no")"

# 验证内存格式（确保是数字+mb/gb，避免Redis启动报错）
if ! [[ "$MAX_MEMORY" =~ ^[0-9]+(mb|gb)$ ]]; then
  echo "WARNING: 内存格式无效（$MAX_MEMORY），使用默认值 128mb"
  MAX_MEMORY="128mb"
fi

# 用exec启动Redis，确保进程为容器PID=1（HassOS能正确管理启动/停止）
exec redis-server \
  --dir "$REDIS_DIR" \                  # 数据存储目录
  --maxmemory "$MAX_MEMORY" \           # 内存限制
  --appendonly "$AOF_FLAG" \            # AOF持久化
  --requirepass "$REQUIRE_PASS" \       # 访问密码
  --bind 0.0.0.0 \                      # 允许所有IP访问（HA内部网络安全）
  --protected-mode no \                 # 关闭保护模式（HA内部使用）
  --loglevel notice \                   # 日志级别（避免冗余日志）
  --logfile /dev/stdout                 # 日志输出到stdout（HassOS能捕获日志）