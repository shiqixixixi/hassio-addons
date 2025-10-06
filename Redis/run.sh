#!/bin/bash
set -e

# -------------------------- 1. 读取 options.json（完全复用 Mopidy 解析方式） --------------------------
# 定义配置文件路径（HassOS 自动生成，与 Mopidy 路径一致）
OPTIONS_FILE="/data/options.json"

# 1. 解析普通字段：local_scan 对应 Redis 的基础配置（max_memory/require_pass/appendonly）
# 复用 Mopidy 的 "jq -r '.字段名 // 默认值'" 语法，确保字段不存在时兜底
max_memory=$(cat "$OPTIONS_FILE" | jq -r '.max_memory // "128mb"')
require_pass=$(cat "$OPTIONS_FILE" | jq -r '.require_pass // ""')
appendonly=$(cat "$OPTIONS_FILE" | jq -r '.appendonly // "false"')

# 2. （可选）若扩展嵌套数组配置（如自定义 Redis 命令行参数），复用 Mopidy 数组解析逻辑
# 示例：解析 "custom_args" 数组（格式同 Mopidy 的 "options" 数组：[{"name":"参数名","value":"参数值"}]）
# 逻辑完全一致：遍历数组→格式化为 "--参数名  参数值"→拼接为字符串
custom_args=$(cat "$OPTIONS_FILE" | jq -r '
  if .custom_args then 
    [.custom_args[] | "--" + .name + " " + .value ] | join(" ") 
  else 
    "" 
  end
')

# -------------------------- 2. 调试打印（参考 Mopidy 简洁风格） --------------------------
echo "=== Redis 配置解析结果 ==="
echo "内存限制: $max_memory"
echo "AOF 持久化: $appendonly"
echo "密码: ${require_pass:-(无密码)}"
echo "自定义参数: $custom_args"
echo "======================"

# -------------------------- 3. 数据目录处理（适配 Redis 需求） --------------------------
# 复用 Mopidy 目录容错逻辑，确保目录存在
redis_dir="/data/redis"
if [ ! -d "$redis_dir" ]; then
  echo "WARNING: $redis_dir 不存在，使用备用目录 /opt/redis"
  redis_dir="/opt/redis"
  mkdir -p "$redis_dir"
fi

# -------------------------- 4. 启动 Redis（复用 Mopidy "命令+参数" 拼接方式） --------------------------
# 转换 AOF 布尔值为 Redis 支持的 yes/no（Mopidy 无此需求，为 Redis 适配）
aof_flag="$([ "$appendonly" = "true" ] && echo "yes" || echo "no")"

# 拼接启动命令（同 Mopidy "应用+配置+参数" 结构，自定义参数直接追加）
exec redis-server \
  --dir "$redis_dir" \
  --maxmemory "$max_memory" \
  --appendonly "$aof_flag" \
  --requirepass "$require_pass" \
  --bind 0.0.0.0 \
  --protected-mode no \
  $custom_args