#ARG BUILD_FROM
#FROM $BUILD_FROM
#ENV ALLOW_EMPTY_PASSWORD yes 
#RUN ["CMD", "redis-cli","ping"]
#FROM redis
FROM bitnami/redis
ENV ALLOW_EMPTY_PASSWORD yes 
#COPY redis.conf /usr/local/etc/redis/redis.conf
#CMD [ "redis-server", "/usr/local/etc/redis/redis.conf" ]
CMD  ["CMD", "redis-cli","ping"]