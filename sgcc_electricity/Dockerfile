FROM python:3.8-slim-buster

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

WORKDIR /app

RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list \
    && apt-get --allow-releaseinfo-change update \
    && apt-get install -y --no-install-recommends jq chromium chromium-driver \
    && rm -rf /var/lib/apt/lists/* \
    && PIP_ROOT_USER_ACTION=ignore pip install \
    --disable-pip-version-check \
    --no-cache-dir \
    -i https://pypi.douban.com/simple \
    requests selenium==4.5.0 schedule==1.1.0 ddddocr==1.4.7 undetected_chromedriver==3.1.6

ENV TZ=Asia/Shanghai

COPY ./*.py ./*.sh /app/

CMD ["./run.sh"]
