ARG BUILD_FROM=webdevops/php-apache:8.0
FROM ${BUILD_FROM}

# Set workdir
WORKDIR /app

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Force rebuild of COPY instructions
ARG CACHE_BUST=1

# Install additional dependencies
RUN \
    # Update apt sources to use archived Debian Buster repositories
    echo "deb http://archive.debian.org/debian buster main contrib non-free" > /etc/apt/sources.list \
    && echo "deb http://archive.debian.org/debian-security buster/updates main contrib non-free" >> /etc/apt/sources.list \
    && apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --no-install-recommends \
        git \
        mariadb-client \
        redis-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy app files (only API directory)
COPY ./pushdeer/pushdeer/api /app

# Copy root filesystem for s6-overlay
COPY rootfs /

# Create push directory if it doesn't exist
RUN mkdir -p /app/push

# Set permissions
RUN \
    chown -R www-data:www-data /app \
    && mkdir -p /app/storage /app/bootstrap/cache \
    && chmod -R 755 /app/storage \
    && chmod -R 755 /app/bootstrap/cache \
    && find /etc/s6-overlay/s6-rc.d -name "run" -exec chmod +x {} \;

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

# Configure PHP session to use Redis
RUN \
    echo "session.save_handler = redis" > /opt/docker/etc/php/php.webdevops.ini \
    && echo "session.save_path = 'tcp://${REDIS_HOST}:${REDIS_PORT}'" >> /opt/docker/etc/php/php.webdevops.ini \
    && echo "session.gc_maxlifetime = 259200" >> /opt/docker/etc/php/php.webdevops.ini

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

# Expose ports
EXPOSE 80

# Start the container using s6-overlay
ENTRYPOINT ["/init"]
