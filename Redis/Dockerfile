FROM redis:7.2.4-alpine

LABEL maintainer="1791539136@qq.com"
LABEL description="Redis server for Home Assistant (HassOS Add-on)"

# 安装必要工具（jq用于解析JSON）
RUN apk add --no-cache bash jq curl \
    && mkdir -p /data/redis /opt/redis /var/run/redis \
    && chown -R 1000:1000 /data/redis /opt/redis /var/run/redis \
    && chmod -R 777 /data/redis /opt/redis /var/run/redis

# 复制配置和脚本
COPY redis.conf /
COPY run.sh /
RUN chmod a+x /run.sh && chown 1000:1000 /run.sh /redis.conf

EXPOSE 6379
USER 1000
ENTRYPOINT ["/run.sh"]