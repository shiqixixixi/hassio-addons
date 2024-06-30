ARG BUILD_FROM
FROM $BUILD_FROM

RUN rm -rf /opt/bitnami/scripts/*

RUN cp -r /bitnami/* /opt/bitnami/scripts/

WORKDIR /opt/bitnami/scripts/redis

RUN ls
RUN pwd

CMD [ "/opt/bitnami/scripts/redis/run.sh" ]
ENTRYPOINT [ "/opt/bitnami/scripts/redis/entrypoint.sh" ]
#ENV ALLOW_EMPTY_PASSWORD no
#ENV REDIS_PASSWORD "123456"
