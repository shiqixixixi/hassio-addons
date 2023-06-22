#ARG BUILD_FROM
#FROM $BUILD_FROM
FROM webdevops/php-apache:8.0
# 首先配置 vhost
COPY ./docker/web/vhost.conf /opt/docker/etc/httpd/vhost.conf
# COPY ./docker/web/web.vhost.conf /opt/docker/etc/httpd/vhost.common.d/

ENV DB_HOST=10.10.10.166
ENV DB_PORT=3306
ENV DB_USERNAME=pushdeer
ENV DB_DATABASE=pushdeer
ENV DB_PASSWORD=pushdeer
ENV GO_PUSH_IOS_TOPIC=com.pushdeer.self.ios
ENV GO_PUSH_IOS_CLIP_TOPIC=com.pushdeer.self.ios.Clip
ENV APP_DEBUG=false
ENV MQTT_API_KEY=9LKo3
ENV MQTT_ON=false
# 然后运行初始化脚本
# https://dockerfile.readthedocs.io/en/latest/content/Customization/provisioning.html
COPY ./docker/web/init.sh /opt/docker/provision/entrypoint.d/
#CMD chmod +x /opt/docker/provision/entrypoint.d/init.sh
RUN echo "session.save_handler = redis\n" >> /opt/docker/etc/php/php.webdevops.ini
RUN echo "session.save_path = 'tcp://10.10.10.166:6379'\n" >> /opt/docker/etc/php/php.webdevops.ini
RUN echo "session.gc_maxlifetime = '259200'\n" >> /opt/docker/etc/php/php.webdevops.ini

# ADD supervisord-proxy.conf /opt/docker/etc/supervisor.d/prism-proxy.conf
RUN mkdir /data
COPY ./docker/web/gorush /data/
RUN chmod +x /data/gorush 

#RUN mkdir /opt/docker/etc/supervisor.d
ADD ./docker/web/supervisord-ios.conf /opt/docker/etc/supervisor.d/push-ios.conf
ADD ./docker/web/supervisord-clip.conf /opt/docker/etc/supervisor.d/push-clip.conf
RUN chmod +x /opt/docker/etc/supervisor.d/push-ios.conf
RUN chmod +x /opt/docker/etc/supervisor.d/push-clip.conf

ADD ./docker/web/larave-cron /etc/cron.d
RUN chmod +x /etc/cron.d/larave-cron 

# 配置 https
# 在本目录下创建ssl目录，放入证书（server.crt，server.key），然后去掉下一行的注释
# ADD ssl /app/ssl

WORKDIR /app
COPY  ./app /app
RUN chmod +x /app/*

EXPOSE 80 