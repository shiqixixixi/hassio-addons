FROM redis:7.2.4-alpine

LABEL maintainer="1791539136@qq.com"
LABEL description="Redis server for Home Assistant (HassOS Add-on)"

# 安装必要工具（根据应用需求）
# bash：运行启动脚本；jq：解析JSON配置；curl：调用Supervisor API
RUN apk add --no-cache bash jq curl\
    && rm -rf /var/cache/apk/*

# 关键：使用 Bashio 官方安装脚本（自动处理路径和依赖，兼容性更高）
# 官方脚本会将 Bashio 安装到 /usr/lib/bashio，且确保文件完整
RUN curl -sL "https://raw.githubusercontent.com/hassio-addons/bashio/v0.14.3/install" | bash -s v0.14.3 \
    && chmod -R 755 /usr/lib/bashio  # 确保权限可执行

# 创建Redis数据目录并授权（HassOS默认用abc用户，UID=1000）
RUN mkdir -p /data/redis /opt/redis /var/run/redis \
    && chown -R 1000:1000 /data/redis /opt/redis /var/run/redis \
    && chmod -R 777 /data/redis /opt/redis /var/run/redis

# 复制加载项文件到容器（路径需与本地目录一致）
COPY run.sh /                  
COPY redis.conf /       

# 授权启动脚本（必须可执行）
RUN chmod a+x /run.sh \
    && chown 1000:1000 /run.sh /redis.conf

# 暴露端口（与config.yaml的ports对应，可选，Dockerfile仅声明）
EXPOSE 6379/tcp

# 切换到abc用户（非root，符合HassOS安全规范）
USER 1000

# 容器启动命令（执行启动脚本，必须保持前台运行）
ENTRYPOINT ["/run.sh"]