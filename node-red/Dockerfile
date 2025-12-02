ARG BUILD_FROM=ghcr.io/hassio-addons/base:19.0.0
FROM ${BUILD_FROM}

COPY package.json /opt/
COPY node-red-dashboard-show-dashboard.patch /tmp/

WORKDIR /opt
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# 更换国内源并安装依赖（整合镜像精简优化）
RUN echo "https://mirrors.aliyun.com/alpine/v3.22/main/" > /etc/apk/repositories && \
    echo "https://mirrors.aliyun.com/alpine/v3.22/community/" >> /etc/apk/repositories && \
    # 安装构建依赖和运行时依赖
    apk add --no-cache --virtual .build-dependencies \
        build-base=0.5-r3 \
        linux-headers=6.14.2-r0 \
        py3-pip=25.1.1-r0 \
        python3-dev=3.12.12-r0 \
    && apk add --no-cache \
        git=2.49.1-r0 \
        icu-data-full=76.1-r1 \
        nginx=1.28.0-r3 \
        nodejs=22.16.0-r2 \
        npm=11.3.0-r1 \
        openssh-client=10.0_p1-r9 \
        patch=2.8-r0 \
    # 使用 npm ci 替代 install，更严格且无冗余，合并缓存清理
    && npm ci \
        --no-audit \
        --no-fund \
        --no-update-notifier \
        --omit=dev \
        --unsafe-perm \
    && npm rebuild --build-from-source @serialport/bindings-cpp \
    && npm cache clear --force \
    # SSH 配置优化
    && echo -e "StrictHostKeyChecking no" >> /etc/ssh/ssh_config \
    # 应用补丁
    && patch -d /opt/node_modules/node-red-dashboard -p1 \
             -i /tmp/node-red-dashboard-show-dashboard.patch \
    # 删除构建依赖，清理冗余文件（新增 Node-RED 无用文件清理）
    && apk del --no-cache --purge .build-dependencies \
    && rm -fr \
        /etc/nginx \
        /root/.cache \
        /root/.npm \
        /root/.nrpmrc \
        /tmp/* \
        # 清理 Node-RED 示例、文档、测试文件
        /opt/node_modules/node-red/examples \
        /opt/node_modules/node-red/docs \
        /opt/node_modules/*/.git \
        /opt/node_modules/*/test \
        /opt/node_modules/*/tests \
        # 清理 npm 残留缓存
        /opt/node_modules/.cache

COPY rootfs /

# 权限处理
RUN find /etc/s6-overlay/s6-rc.d -name "run" -exec chmod +x {} \; && \
    chown -R root:root /etc/s6-overlay/s6-rc.d/

HEALTHCHECK --start-period=10m \
    CMD curl --fail http://127.0.0.1:46836 || exit 1

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="Franck Nijhof <frenck@addons.community>" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="Home Assistant Community Add-ons" \
    org.opencontainers.image.authors="Franck Nijhof <frenck@addons.community>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://addons.community" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
