ARG BUILD_FROM=ghcr.io/hassio-addons/base:18.2.0
FROM ${BUILD_FROM}

COPY package.json /opt/
COPY node-red-dashboard-show-dashboard.patch /tmp/

WORKDIR /opt
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# 更换国内源并安装依赖
RUN echo "https://mirrors.aliyun.com/alpine/v3.22/main/" > /etc/apk/repositories && \
    echo "https://mirrors.aliyun.com/alpine/v3.22/community/" >> /etc/apk/repositories && \
    apk add --no-cache --virtual .build-dependencies \
        build-base \
        linux-headers \
        py3-pip \
        python3-dev \
    && apk add --no-cache \
        git \
        icu-data-full \
        nginx \
        nodejs \
        npm \
        openssh-client \
        patch \
    && npm config set registry https://registry.npmmirror.com \
    && npm install \
        --no-audit \
        --no-fund \
        --no-update-notifier \
        --omit=dev \
        --unsafe-perm \
    && npm rebuild --build-from-source @serialport/bindings-cpp \
    && npm cache clear --force \
    && echo -e "StrictHostKeyChecking no" >> /etc/ssh/ssh_config \
    && if [ ! -f "/tmp/node-red-dashboard-show-dashboard.patch" ]; then \
        echo "Error: Patch file not found!"; exit 1; \
      fi \
    && if [ ! -d "/opt/node_modules/node-red-dashboard" ]; then \
        echo "Error: node-red-dashboard not installed!"; exit 1; \
      fi \
    && patch -d /opt/node_modules/node-red-dashboard -p1 \
             -i /tmp/node-red-dashboard-show-dashboard.patch \
    && apk del --no-cache --purge .build-dependencies \
    && rm -fr /etc/nginx /root/.cache /root/.npm /root/.nrpmrc /tmp/*

COPY rootfs /

# 权限处理
RUN find /etc/s6-overlay/s6-rc.d -name "run" -exec chmod +x {} \; && \
    chown -R root:root /etc/s6-overlay/s6-rc.d/

HEALTHCHECK --start-period=10m \
    CMD curl --fail http://127.0.0.1:46836 || exit 1

# 标签部分保持不变

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
