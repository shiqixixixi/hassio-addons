#ARG BUILD_FROM
#FROM $BUILD_FROM
FROM webdevops/php-apache:8.0
# 首先配置 vhost
COPY ./pushdeer/pushdeer/docker/web/vhost.conf /opt/docker/etc/httpd/vhost.conf
# COPY ./docker/web/web.vhost.conf /opt/docker/etc/httpd/vhost.common.d/

COPY ./pushdeer/pushdeer/docker/web/init.sh /opt/docker/provision/entrypoint.d/
#CMD chmod +x /opt/docker/provision/entrypoint.d/init.sh

WORKDIR /app
COPY ./pushdeer/pushdeer /app
#COPY ./app /app
#RUN chmod +x /app

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
# 然后运行初始化脚本
# https://dockerfile.readthedocs.io/en/latest/content/Customization/provisioning.html


RUN echo "session.save_handler = redis\n" >> /opt/docker/etc/php/php.webdevops.ini
RUN echo "session.save_path = 'tcp://b1af8335-redis:6379'\n" >> /opt/docker/etc/php/php.webdevops.ini
RUN echo "session.gc_maxlifetime = '259200'\n" >> /opt/docker/etc/php/php.webdevops.ini

RUN sed -i 's/redis:6379/b1af8335-redis:6379/g' /app/push/ios.yml && sed -i '/password: ""/password: "123456"/' /app/push/ios.yml
RUN sed -i 's/redis:6379/b1af8335-redis:6379/g' /app/push/clip.yml && sed -i '/password: ""/password: "123456"/' /app/push/clip.yml
#RUN sed -i '/password: ""/password: "123456"/' /app/push/ios.yml
#RUN sed -i '/password: ""/password: "123456"/' /app/push/clip.yml

RUN echo "if [ ! -S /data/log ]; then rm -f /data/log;" > /opt/docker/bin/service.d/syslog-ng.d/10-init.sh
# ADD supervisord-proxy.conf /opt/docker/etc/supervisor.d/prism-proxy.conf

#RUN mkdir /data
COPY ./pushdeer/pushdeer/docker/web/gorush /home
RUN chmod +x /home/gorush 

#RUN mkdir /opt/docker/etc/supervisor.d
ADD ./pushdeer/pushdeer/docker/web/supervisord-ios.conf /opt/docker/etc/supervisor.d/push-ios.conf
ADD ./pushdeer/pushdeer/docker/web/supervisord-clip.conf /opt/docker/etc/supervisor.d/push-clip.conf

RUN sed -i 's/data/home/g' /opt/docker/etc/supervisor.d/push-ios.conf
RUN sed -i 's/data/home/g' /opt/docker/etc/supervisor.d/push-clip.conf

RUN sed -i 's@dev/log@home/log@g' /etc/syslog-ng/syslog-ng.conf

ADD ./pushdeer/pushdeer/docker/web/larave-cron /etc/cron.d
RUN chmod +x /etc/cron.d/larave-cron 

# 配置 https
# 在本目录下创建ssl目录，放入证书（server.crt，server.key），然后去掉下一行的注释
# ADD ssl /app/ssl

EXPOSE 80