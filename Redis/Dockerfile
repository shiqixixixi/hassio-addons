ARG BUILD_FROM
FROM $BUILD_FROM

RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list \
    && apt-get --allow-releaseinfo-change update \
    && apt-get install -y --no-install-recommends jq chromium chromium-driver \
    && rm -rf /var/lib/apt/lists/*
    
COPY ./bitnami/scripts/redis-env.sh /opt/bitnami/scripts/redis-env.sh

WORKDIR /opt/bitnami/scripts/redis

CMD [ "/opt/bitnami/scripts/redis/run.sh" ]
ENTRYPOINT [ "/opt/bitnami/scripts/redis/entrypoint.sh" ]
#ENV ALLOW_EMPTY_PASSWORD no
#ENV REDIS_PASSWORD "123456"
