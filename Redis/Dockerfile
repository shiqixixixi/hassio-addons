FROM redis:alpine

LABEL maintainer="1791539136@qq.com"
LABEL description="Redis server for Home Assistant (HassOS Add-on)"

# 安装必要工具（jq用于解析JSON，gosu用于正确切换用户）
RUN apk add --no-cache bash jq gosu \
    && mkdir -p /data/redis /opt/redis /var/run/redis \
    && chown -R redis:redis /data/redis /opt/redis /var/run/redis \
    && chmod -R 775 /data/redis /opt/redis /var/run/redis

# 复制配置和脚本
COPY redis.conf /
COPY run.sh /
# 确保脚本权限正确，允许执行
RUN chmod 755 /run.sh && chown root:root /run.sh /redis.conf

# 确保容器可以正确读取外部挂载的配置
# 不修改/data权限，由Home Assistant addon系统管理

# 确保Redis可以使用IPC_LOCK权限（用于内存管理）
RUN setcap 'cap_ipc_lock=+ep' /usr/local/bin/redis-server || true

EXPOSE 6379

# 使用root用户运行脚本，这样可以读取/data/options.json
# 在run.sh中会切换到redis用户运行Redis进程
ENTRYPOINT ["/run.sh"]