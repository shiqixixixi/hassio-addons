FROM golang:1-alpine AS builder

COPY . /go/src/github.com/finb/bark-server

WORKDIR /go/src/github.com/finb/bark-server

RUN set -ex \
    && pwd \
    && ls -a \
    && cd ./bark-server \
    && apk add git gcc libc-dev \
    && BUILD_VERSION=v2.1.5-27-g2f24a8f \
    && BUILD_DATE=$(date "+%F %T") \
    && COMMIT_SHA1=f1c50cc1d941f07ea295d22d119b951d59c3f3b1 \
    && go install -trimpath -ldflags \
            "-X 'main.version=${BUILD_VERSION}' \
             -X 'main.buildDate=${BUILD_DATE}' \
             -X 'main.commitID=${COMMIT_SHA1}' \
             -w -s"



FROM alpine

LABEL maintainer="mritd <mritd@linux.com>"

# set up nsswitch.conf for Go's "netgo" implementation
# - https://github.com/golang/go/blob/go1.9.1/src/net/conf.go#L194-L275
# - docker run --rm debian:stretch grep '^hosts:' /etc/nsswitch.conf
RUN echo 'hosts: files dns' > /etc/nsswitch.conf

# default timezon
# override it with `--build-arg TIMEZONE=xxxx`
ARG TIMEZONE=Asia/Shanghai

ENV TZ ${TIMEZONE}

RUN set -ex \
    && apk upgrade \
    && apk add --no-cache bash ca-certificates tzdata \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

COPY --from=builder /go/bin/bark-server /usr/local/bin/bark-server

#COPY --from=builder ./bark-server_linux_amd64_v4 /usr/local/bin/bark-server

COPY --from=builder /go/src/github.com/finb/bark-server/bark-server/deploy/entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh

EXPOSE 8082

ENTRYPOINT ["/entrypoint.sh"]

#CMD ["bark-server"]
#CMD ["bark-server", "--addr", "0.0.0.0:8082", "--data", "/config/Bark/self build edit/"]
CMD ["bark-server", "--addr", "0.0.0.0:8082", "--dsn=barkedit:barkedit@tcp(10.10.10.166)/barkedit"]

