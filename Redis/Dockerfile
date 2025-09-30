# 使用官方 Redis 镜像（选择 alpine 版本减小体积）
FROM redis:7.2.4-alpine

# 标签信息
LABEL maintainer="1791539136@qq.com"
LABEL description="Redis server for Home Assistant"

# 安装必要工具（用于处理配置）
RUN apk add --no-cache bash

# 创建 Redis 数据目录（挂载到 HassOS 的数据卷）
RUN mkdir -p /data/redis && chown -R redis:redis /data/redis

# 复制启动脚本并赋予执行权限
COPY run.sh /
RUN chmod a+x /run.sh

# 切换到 redis 用户（非 root 运行，更安全）
USER redis

# 容器入口点（执行启动脚本）
ENTRYPOINT ["/run.sh"]