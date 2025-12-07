ARG BUILD_FROM=ghcr.io/hassio-addons/base:19.0.0
FROM ${BUILD_FROM}

# Set workdir
WORKDIR /app

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install dependencies
RUN \
    apk add --no-cache \
        apache2 \
        busybox-cron \
        curl \
        git \
        mariadb-client \
        php83 \
        php83-apache2 \
        php83-bcmath \
        php83-ctype \
        php83-curl \
        php83-dom \
        php83-fileinfo \
        php83-gd \
        php83-iconv \
        php83-json \
        php83-mbstring \
        php83-mysqli \
        php83-openssl \
        php83-pdo \
        php83-pdo_mysql \
        php83-phar \
        php83-redis \
        php83-session \
        php83-simplexml \
        php83-sodium \
        php83-tokenizer \
        php83-xml \
        php83-xmlreader \
        php83-xmlwriter \
        php83-zip \
        supervisor

# Force rebuild of COPY instructions
ARG CACHE_BUST=1

# Copy app files (only API directory)
COPY ./pushdeer/pushdeer/api /app

# Copy root filesystem
COPY rootfs /

# Copy configuration files (if they exist)
RUN mkdir -p /etc

# Create push directory if it doesn't exist
RUN mkdir -p /app/push

# Copy gorush binary
COPY ./pushdeer/pushdeer/docker/web/gorush /data/gorush
RUN chmod +x /data/gorush

# Set permissions - ensure directories exist before chmod, and ignore errors
RUN \
    chown -R apache:apache /app 2>/dev/null || true \
    && mkdir -p /app/storage /app/bootstrap/cache 2>/dev/null || true \
    && chmod -R 755 /app/storage 2>/dev/null || true \
    && chmod -R 755 /app/bootstrap/cache 2>/dev/null || true \
    && find /etc/s6-overlay/s6-rc.d -name "run" -exec chmod +x {} \; 2>/dev/null || true \
    && chown -R root:root /etc/s6-overlay/s6-rc.d/ 2>/dev/null || true

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
    && composer update --no-dev --optimize-autoloader

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