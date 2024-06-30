ARG BUILD_FROM
FROM $BUILD_FROM


COPY ./bitnami/scripts/redis-env.sh /opt/bitnami/scripts/redis-env.sh

WORKDIR /opt/bitnami/scripts/redis

RUN chmod +x /opt/bitnami/scripts/redis/run.sh
RUN chmod +x /opt/bitnami/scripts/redis/entrypoint.sh
RUN chmod +x /opt/bitnami/scripts/redis-env.sh

CMD [ "/opt/bitnami/scripts/redis/run.sh" ]
ENTRYPOINT [ "/opt/bitnami/scripts/redis/entrypoint.sh" ]
#ENV ALLOW_EMPTY_PASSWORD no
#ENV REDIS_PASSWORD "123456"
