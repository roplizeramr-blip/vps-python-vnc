# syntax=docker/dockerfile:1.7
FROM python:3.13-slim-noble

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Africa/Cairo

RUN apt-get update && \
    apt-get install -y --no-install-recommends openssl curl rsvg-convert \
    && rm -rf /var/lib/apt/lists/*

# noVNC bundle + websockify binary (static, no need to compile)
RUN mkdir -p /opt/novnc /tmp/ws && \
    curl -fsSL https://github.com/novnc/websockify/releases/download/0.9.0/websockify-0.9.0_linux_amd64.tar.gz \
        -o /tmp/ws.tgz && \
    tar -xzf /tmp/ws.tgz -C /tmp/ws && \
    cp /tmp/ws/websockify-0.9.0_linux_amd64/websockify /usr/local/bin/websockify && \
    chmod 755 /usr/local/bin/websockify && \
    cp -r /tmp/ws/websockify-0.9.0_linux_amd64/program.html /opt/novnc/index.html && \
    rm -rf /tmp/ws /tmp/ws.tgz

# nginx-light: public listener, Basic Auth, WS upgrade via nginx itself
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx-light \
    && rm -rf /var/lib/apt/lists/*

COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /start.sh
RUN chmod 755 /start.sh

# entrypoint: nginx + websockify, both foreground, no supervisor, no X server
ENTRYPOINT ["/start.sh"]
