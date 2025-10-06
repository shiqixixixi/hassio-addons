FROM redis:7.2.4-alpine

LABEL maintainer="1791539136@qq.com"
LABEL description="Redis server for Home Assistant (HassOS Add-on)"

# 1. 安装jq（用于解析options.json）+ 配置权限
RUN apk add --no-cache bash jq \
    && mkdir -p /data/redis /opt/redis /var/run/redis \
    && chmod -R 777 /data /opt/redis /var/run/redis \  
    && chown -R 1000:1000 /data /opt/redis /var/run/redis  

# 2. 复制启动脚本
COPY run.sh /
RUN chmod a+x /run.sh && chown 1000:1000 /run.sh

# 3. 暴露端口
EXPOSE 6379

# 4. 使用HassOS默认用户
USER 1000

ENTRYPOINT ["/run.sh"]