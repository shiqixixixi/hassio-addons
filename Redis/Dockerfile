FROM redis:7.2.4-alpine

LABEL maintainer="1791539136@qq.com"
LABEL description="Redis server for Home Assistant (HassOS Add-on)"

# 1. 安装依赖 + 关键操作：创建2个目录（应对HassOS挂载覆盖问题）
# /data/redis：HassOS挂载目录（持久化），若挂载后目录丢失，用备用目录
# /opt/redis：备用目录（构建时创建，确保不会被覆盖）
RUN apk add --no-cache bash \
    && mkdir -p /data/redis /opt/redis /var/run/redis \
    && chmod -R 777 /data/redis /opt/redis /var/run/redis \ 
    && chown -R 1000:1000 /data/redis /opt/redis /var/run/redis  

# 2. 复制启动脚本并授权
COPY run.sh /
RUN chmod a+x /run.sh && chown 1000:1000 /run.sh  # 让abc用户拥有脚本所有权

# 3. 环境变量（与config.yaml映射对应）
ENV APPENDONLY="false" \
    MAX_MEMORY="128mb" \
    REQUIRE_PASS="" \
    TZ="UTC"

# 4. 暴露端口
EXPOSE 6379

# 5. 关键：指定用abc用户（UID=1000）启动，避免HassOS权限冲突
USER 1000

ENTRYPOINT ["/run.sh"]