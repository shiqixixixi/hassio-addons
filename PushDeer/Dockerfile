ARG BUILD_FROM
FROM $BUILD_FROM

ENV DB_HOST=10.10.10.166
ENV DB_PORT=3306
ENV DB_USERNAME=pushdeer
ENV DB_DATABASE=pushdeer
ENV DB_PASSWORD=pushdeer
ENV DB_TIMEZONE=+08:00
ENV GO_PUSH_IOS_TOPIC=com.pushdeer.self.ios
ENV GO_PUSH_IOS_CLIP_TOPIC=com.pushdeer.self.ios.Clip
ENV APP_DEBUG=false
ENV WEB_PHP_SOCKET=127.0.0.1:8000

COPY ./app/dcoker/web/gorush /data/
RUN chmod +x /data/gorush 