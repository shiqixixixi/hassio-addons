FROM redis:alpine

LABEL maintainer="1791539136@qq.com"
LABEL description="Redis server for Home Assistant (HassOS Add-on)"

# 安装必要工具（jq用于解析JSON，gosu用于正确切换用户）
RUN apk add --no-cache bash jq gosu \
    && mkdir -p /data /opt/redis /tmp/redis \
    && chmod -R 777 /data /opt/redis /tmp/redis

# 创建配置目录并复制配置和脚本
RUN mkdir -p /etc/redis
COPY redis.conf /etc/redis/redis.conf
COPY run.sh /run.sh
# 确保脚本权限正确，允许执行
RUN chmod +x /run.sh

# 添加数据卷
VOLUME /data

EXPOSE 6379

# 使用当前用户运行脚本
ENTRYPOINT ["/run.sh"]