FROM python:3.10-slim-bookworm

RUN mkdir /app

COPY ./*.txt ./*.py ./*.sh ./*.onnx /app/

RUN cd /app \
    && apt-get update && apt-get install -y --no-install-recommends \
    build-essential python3-dev \
    && python3 -m pip install --upgrade pip \
    && pip3 install --no-cache-dir -r requirements.txt \
    && apt-get purge -y --auto-remove build-essential python3-dev \
    && rm -rf /tmp/* && rm -rf /root/.cache/* \
    && apt-get update && apt-get install -y libgl1 libglib2.0-0 jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["./run.sh"]
