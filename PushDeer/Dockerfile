ARG BUILD_FROM
FROM $BUILD_FROM

# 安装必要的依赖
RUN apk add --no-cache \
    php8 \
    php8-apache2 \
    php8-mysqli \
    php8-pdo \
    php8-pdo_mysql \
    php8-redis \
    php8-session \
    php8-json \
    php8-openssl \
    php8-curl \
    php8-gd \
    php8-mbstring \
    php8-tokenizer \
    php8-xml \
    php8-zip \
    redis \
    supervisor \
    cron \
    bash

# 配置Apache
RUN sed -i 's/Listen 80/Listen 80/g' /etc/apache2/httpd.conf && \
    sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/g' /etc/apache2/httpd.conf && \
    sed -i 's/#LoadModule session_module/LoadModule session_module/g' /etc/apache2/httpd.conf && \
    sed -i 's/#LoadModule session_cookie_module/LoadModule session_cookie_module/g' /etc/apache2/httpd.conf && \
    sed -i 's/#LoadModule session_crypto_module/LoadModule session_crypto_module/g' /etc/apache2/httpd.conf && \
    sed -i 's/#LoadModule session_dbd_module/LoadModule session_dbd_module/g' /etc/apache2/httpd.conf

# 设置工作目录
WORKDIR /app

# 复制应用程序文件
COPY ./pushdeer/pushdeer /app

# 复制配置文件
COPY ./pushdeer/pushdeer/docker/web/vhost.conf /etc/apache2/conf.d/
COPY ./pushdeer/pushdeer/docker/web/init.sh /etc/init.d/
RUN chmod +x /etc/init.d/init.sh

# 复制supervisor配置
COPY ./pushdeer/pushdeer/docker/web/supervisord-ios.conf /etc/supervisor.d/push-ios.ini
COPY ./pushdeer/pushdeer/docker/web/supervisord-clip.conf /etc/supervisor.d/push-clip.ini

# 复制gorush
COPY ./pushdeer/pushdeer/docker/web/gorush /usr/local/bin/
RUN chmod +x /usr/local/bin/gorush

# 配置环境变量
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

# 配置PHP会话
RUN echo "session.save_handler = redis" >> /etc/php8/php.ini && \
    echo "session.save_path = 'tcp://localhost:6379'" >> /etc/php8/php.ini && \
    echo "session.gc_maxlifetime = 259200" >> /etc/php8/php.ini

# 配置push配置文件
RUN sed -i 's/redis:6379/localhost:6379/g' /app/push/ios.yml && \
    sed -i 's/redis:6379/localhost:6379/g' /app/push/clip.yml && \
    sed -i 's/password: ""/password: ""/g' /app/push/ios.yml && \
    sed -i 's/password: ""/password: ""/g' /app/push/clip.yml

# 配置cron
COPY ./pushdeer/pushdeer/docker/web/larave-cron /etc/cron.d/
RUN chmod +x /etc/cron.d/larave-cron

# 创建必要的目录
RUN mkdir -p /var/log/supervisor /var/run/redis /app/storage/logs

# 设置权限
RUN chown -R apache:apache /app && \
    chmod -R 755 /app/storage

# 启动命令
CMD ["bash", "-c", "redis-server --daemonize yes && supervisord -c /etc/supervisord.conf && apachectl -D FOREGROUND"]