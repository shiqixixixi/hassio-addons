ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.3
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

ARG BUILD_ARCH

# Copy Node-RED package.json
COPY package.json /opt/

# Set workdir
WORKDIR /opt

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Setup base
RUN \
    apk add --no-cache --virtual .build-dependencies \
    build-base \
    linux-headers \
    py3-pip \
    python3-dev \
    \
    && apk add --no-cache \
    git \
    icu-data-full \
    nginx \
    openssh-client-default \
    \
    # Alpine's nodejs crashes with SIGILL under QEMU aarch64 emulation,
    # use official Node.js binary (glibc) with gcompat for aarch64.
    && if [ "${BUILD_ARCH}" = "aarch64" ]; then \
        apk add --no-cache gcompat libstdc++ curl \
        && curl -fsSL https://nodejs.org/dist/v22.12.0/node-v22.12.0-linux-arm64.tar.xz \
        | tar -xJ -C /usr/local --strip-components=1 \
        && ln -sf /usr/local/bin/node /usr/bin/node \
        && ln -sf /usr/local/bin/npm /usr/bin/npm; \
    else \
        apk add --no-cache nodejs npm; \
    fi \
    \
    && npm install \
    --no-audit \
    --no-fund \
    --no-update-notifier \
    --omit=dev \
    && npm rebuild --build-from-source @serialport/bindings-cpp \
    \
    && npm cache clear --force \
    \
    && echo -e "StrictHostKeyChecking no" >> /etc/ssh/ssh_config \
    \
    && apk del --no-cache --purge .build-dependencies \
    && rm -fr \
    /etc/nginx \
    /root/.cache \
    /root/.npm \
    /root/.nrpmrc \
    /tmp/*


# Copy root filesystem
COPY rootfs /

# 权限处理
RUN find /etc/s6-overlay/s6-rc.d -name "run" -exec chmod +x {} \; && \
    chown -R root:root /etc/s6-overlay/s6-rc.d/

# Health check
HEALTHCHECK --start-period=10m \
    CMD curl --fail http://127.0.0.1:46836 || exit 1

# Build arguments
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
    maintainer="Franck Nijhof <opensource@frenck.dev>" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="Home Assistant Community Apps" \
    org.opencontainers.image.authors="Franck Nijhof <opensource@frenck.dev>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://frenck.dev/home-assistant-apps" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
