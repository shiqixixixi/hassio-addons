ARG BUILD_FROM=ghcr.io/hassio-addons/base:19.0.0
FROM ${BUILD_FROM}

# Set workdir
WORKDIR /app

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install dependencies
RUN \
    apk add --no-cache \
        apache2=2.4.62-r3 \
        curl=8.11.0-r1 \
        git=2.49.1-r0 \
        mariadb-client=11.4.3-r0 \
        php83=8.3.10-r0 \
        php83-apache2=8.3.10-r0 \
        php83-bcmath=8.3.10-r0 \
        php83-ctype=8.3.10-r0 \
        php83-curl=8.3.10-r0 \
        php83-dom=8.3.10-r0 \
        php83-fileinfo=8.3.10-r0 \
        php83-gd=8.3.10-r0 \
        php83-iconv=8.3.10-r0 \
        php83-json=8.3.10-r0 \
        php83-mbstring=8.3.10-r0 \
        php83-mysqli=8.3.10-r0 \
        php83-openssl=8.3.10-r0 \
        php83-pdo=8.3.10-r0 \
        php83-pdo_mysql=8.3.10-r0 \
        php83-phar=8.3.10-r0 \
        php83-redis=6.0.2-r0 \
        php83-session=8.3.10-r0 \
        php83-simplexml=8.3.10-r0 \
        php83-sodium=8.3.10-r0 \
        php83-tokenizer=8.3.10-r0 \
        php83-xml=8.3.10-r0 \
        php83-xmlreader=8.3.10-r0 \
        php83-xmlwriter=8.3.10-r0 \
        php83-zip=8.3.10-r0 \
        redis=7.2.5-r0 \
        supervisor=4.2.5-r1

# Copy app files
COPY ./pushdeer/pushdeer /app

# Copy configuration files (if they exist)
RUN mkdir -p /etc

# Copy root filesystem
COPY rootfs /

# Set permissions
RUN \
    chown -R apache:apache /app \
    && chmod -R 755 /app/storage \
    && chmod -R 755 /app/bootstrap/cache \
    && find /etc/s6-overlay/s6-rc.d -name "run" -exec chmod +x {} \; \
    && chown -R root:root /etc/s6-overlay/s6-rc.d/

# Environment variables
ENV DB_HOST=core-mariadb
ENV DB_PORT=3306
ENV DB_USERNAME=pushdeer
ENV DB_DATABASE=pushdeer
ENV DB_PASSWORD=pushdeer
ENV GO_PUSH_IOS_TOPIC=com.pushdeer.self.ios
ENV GO_PUSH_IOS_CLIP_TOPIC=com.pushdeer.self.ios.Clip
ENV APP_DEBUG=false
ENV MQTT_API_KEY=9LKo3
ENV MQTT_ON=false

# Install composer dependencies
RUN \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && cd /app \
    && composer install --no-dev --optimize-autoloader

# Health check
HEALTHCHECK --start-period=30s \
    CMD curl --fail http://127.0.0.1:80 || exit 1

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
    maintainer="PushDeer Team" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="Home Assistant Community Add-ons" \
    org.opencontainers.image.authors="PushDeer Team" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://github.com/easychen/pushdeer" \
    org.opencontainers.image.source="https://github.com/easychen/pushdeer" \
    org.opencontainers.image.documentation="https://github.com/easychen/pushdeer/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}