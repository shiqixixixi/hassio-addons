FROM redis:7.2.4-alpine

LABEL maintainer="1791539136@qq.com"
LABEL description="Redis server for Home Assistant (HassOS Add-on)"

# 关键1：安装必要工具（jq用于解析options.json，避免变量读取失败）
RUN apk add --no-cache bash jq \
    && mkdir -p /data/redis /opt/redis /var/run/redis \  
    && chmod -R 777 /data /opt/redis /var/run/redis \   
    && chown -R 1000:1000 /data /opt/redis /var/run/redis

# 复制静态配置模板和启动脚本
COPY redis.conf /  
COPY run.sh /

# 关键2：确保脚本和配置文件的权限适配abc用户
RUN chmod a+x /run.sh \
    && chown 1000:1000 /run.sh /redis.conf

# 暴露端口
EXPOSE 6379

# 使用HassOS默认用户（UID=1000）
USER 1000

ENTRYPOINT ["/run.sh"]