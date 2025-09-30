FROM redis:7.2.4-alpine

LABEL maintainer="1791539136@qq.com"
LABEL description="Redis server for Home Assistant"

# 以 root 身份安装工具并创建目录
RUN apk add --no-cache bash \
    && mkdir -p /data/redis \  
    && chown -R redis:redis /data/redis 

# 复制启动脚本（root 身份确保可执行）
COPY run.sh /
RUN chmod a+x /run.sh

# 最后切换到 redis 用户（非 root 运行）
USER redis

ENTRYPOINT ["/run.sh"]