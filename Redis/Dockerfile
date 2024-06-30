ARG BUILD_FROM
FROM $BUILD_FROM

COPY ./opt/bitnami/* /opt/bitnami/

WORKDIR /opt/bitnami/scripts

CMD [ "run.sh" ]
ENTRYPOINT [ "entrypoint.sh" ]
#ENV ALLOW_EMPTY_PASSWORD no
#ENV REDIS_PASSWORD "123456"
