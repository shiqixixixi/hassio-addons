FROM python:3.10-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends jq chromium chromium-driver \
    build-essential python3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && pip install \
    --disable-pip-version-check \
    --no-cache-dir \
    requests selenium==4.5.0 schedule==1.1.0 ddddocr==1.4.7 undetected_chromedriver==3.1.6 \
    && apt-get purge -y --auto-remove build-essential python3-dev \
    && rm -rf /var/lib/apt/lists/*

ENV TZ=Asia/Shanghai

COPY ./*.py ./*.sh /app/

CMD ["./run.sh"]
