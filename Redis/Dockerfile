# 使用一个包含编译工具的基础镜像
FROM ubuntu:latest AS builder

# 安装编译 Redis 所需的依赖包
RUN apt-get update && \
    apt-get install -y \
    make \
    gcc \
    tcl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /Redis

RUN make && \
    make install

RUN cp src/redis-server /usr/local/bin/redis-server && \
    cp src/redis-cli /usr/local/bin/redis-cli

RUN mkdir -p /etc/redis

COPY redis.conf /etc/redis/redis.conf

ARG BUILD_FROM
FROM $BUILD_FROM
    