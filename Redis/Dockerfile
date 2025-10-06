FROM redis:7.2.4-alpine

LABEL maintainer="1791539136@qq.com"
LABEL description="Redis server for Home Assistant (HassOS Add-on)"

# 安装依赖+创建目录（适配abc用户）
RUN apk add --no-cache bash \
    && mkdir -p /data/redis /opt/redis /var/run/redis \
    && chmod -R 777 /data/redis /opt/redis /var/run/redis \
    && chown -R 1000:1000 /data/redis /opt/redis /var/run/redis

# 复制启动脚本
COPY run.sh /
RUN chmod a+x /run.sh && chown 1000:1000 /run.sh

# 暴露端口
EXPOSE 6379

# 使用HassOS默认用户（UID=1000）
USER 1000

ENTRYPOINT ["/run.sh"]