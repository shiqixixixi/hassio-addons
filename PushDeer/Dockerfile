ARG BUILD_FROM
FROM $BUILD_FROM

# 首先配置 vhost
COPY ./pushdeer/pushdeer/docker/web/vhost.conf /opt/docker/etc/httpd/vhost.conf

# 复制初始化脚本
COPY ./pushdeer/pushdeer/docker/web/init.sh /opt/docker/provision/entrypoint.d/
RUN chmod +x /opt/docker/provision/entrypoint.d/init.sh

# 设置工作目录
WORKDIR /app

# 复制应用程序文件
COPY ./pushdeer/pushdeer /app

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

# 配置Redis连接
RUN echo "session.save_handler = redis\n" >> /opt/docker/etc/php/php.webdevops.ini
RUN echo "session.save_path = 'tcp://core-redis:6379?auth='\n" >> /opt/docker/etc/php/php.webdevops.ini
RUN echo "session.gc_maxlifetime = '259200'\n" >> /opt/docker/etc/php/php.webdevops.ini

# 配置push配置文件
RUN sed -i 's/redis:6379/core-redis:6379/g' /app/push/ios.yml 
RUN sed -i 's/redis:6379/core-redis:6379/g' /app/push/clip.yml

# 复制gorush
COPY ./pushdeer/pushdeer/docker/web/gorush /home
RUN chmod +x /home/gorush 

# 复制supervisor配置
ADD ./pushdeer/pushdeer/docker/web/supervisord-ios.conf /opt/docker/etc/supervisor.d/push-ios.conf
ADD ./pushdeer/pushdeer/docker/web/supervisord-clip.conf /opt/docker/etc/supervisor.d/push-clip.conf

# 配置supervisor
RUN sed -i 's/data/home/g' /opt/docker/etc/supervisor.d/push-ios.conf
RUN sed -i 's/data/home/g' /opt/docker/etc/supervisor.d/push-clip.conf

# 配置cron
ADD ./pushdeer/pushdeer/docker/web/larave-cron /etc/cron.d
RUN chmod +x /etc/cron.d/larave-cron 

# 创建必要的目录
RUN mkdir -p /home/log /app/storage/logs

# 设置权限
RUN chown -R www-data:www-data /app && \
    chmod -R 755 /app/storage