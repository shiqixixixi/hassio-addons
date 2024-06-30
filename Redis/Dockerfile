ARG BUILD_FROM
FROM $BUILD_FROM

RUN rm -rf /opt/bitnami/scripts

COPY ./opt/bitnami/* /opt/bitnami/

WORKDIR /opt/bitnami/scripts/redis

RUN chmod +x /opt/bitnami/scripts/redis/run.sh

CMD [ "/opt/bitnami/scripts/redis/run.sh" ]
ENTRYPOINT [ "/opt/bitnami/scripts/redis/entrypoint.sh" ]
#ENV ALLOW_EMPTY_PASSWORD no
#ENV REDIS_PASSWORD "123456"
