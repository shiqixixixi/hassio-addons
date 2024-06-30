ARG BUILD_FROM
FROM $BUILD_FROM

COPY ./opt/bitnami/* /opt/bitnami/

WORKDIR /opt/bitnami/scripts/redis

CMD [ "/opt/bitnami/scripts/redis/run.sh" ]
ENTRYPOINT [ "/opt/bitnami/scripts/redis/entrypoint.sh" ]
#ENV ALLOW_EMPTY_PASSWORD no
#ENV REDIS_PASSWORD "123456"
