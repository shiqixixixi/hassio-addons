FROM redis:7.2.4-alpine

LABEL maintainer="1791539136@qq.com"
LABEL description="Redis server for Home Assistant"

# 以 root 身份安装工具、创建目录并授权
RUN apk add --no-cache bash \
    && mkdir -p /data/redis \  
    && chown -R redis:redis /data/redis 

# 复制启动脚本并赋予执行权限
COPY run.sh /
RUN chmod a+x /run.sh

# 关键：设置环境变量默认值（避免变量未定义导致脚本失败）
ENV APPENDONLY="false" \          
    MAX_MEMORY="128mb" \          
    REQUIRE_PASS="" 

# 切换到非root用户运行
USER redis

ENTRYPOINT ["/run.sh"]