# 基础镜像保持不变，但移除redis用户切换，适配HassOS默认abc用户
FROM redis:7.2.4-alpine

LABEL maintainer="1791539136@qq.com"
LABEL description="Redis server for Home Assistant (HassOS Add-on)"

# 1. 安装依赖+创建HassOS标准目录
RUN apk add --no-cache bash \
    && mkdir -p /data/redis /var/run/redis \  
    && chmod -R 777 /data/redis /var/run/redis  

# 2. 复制启动脚本并授权
COPY run.sh /
RUN chmod a+x /run.sh

# 3. 设置HassOS加载项必填环境变量（默认值，可在HassOS界面修改）
ENV APPENDONLY="false" \
    MAX_MEMORY="128mb" \
    REQUIRE_PASS="" \
    TZ="UTC"  

# 4. 暴露Redis端口（HassOS加载项需显式声明）
EXPOSE 6379

# 5. 关键：不指定USER，HassOS会自动以abc用户（UID=1000）启动，避免权限冲突
ENTRYPOINT ["/run.sh"]