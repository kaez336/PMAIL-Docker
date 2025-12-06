FROM debian:12

# -- install dependencies --
RUN apt update && apt install -y \
    wget \
    unzip \
    zip \
    libzip-dev \
    curl \
    nginx \
    openssl \
    supervisor \
    sqlite3 \
    python3 \
    python3-pip \
    python3-venv \
    dnsutils \
    netcat-traditional \
    procps \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# -- install certbot via pip (fixes AttributeError bug) --
RUN python3 -m venv /opt/certbot && \
    /opt/certbot/bin/pip install --upgrade pip && \
    /opt/certbot/bin/pip install certbot certbot-nginx && \
    ln -s /opt/certbot/bin/certbot /usr/bin/certbot

# -- prepare directories --
RUN mkdir -p /opt/pmail/config/dkim \
    /opt/pmail/config/ssl \
    /opt/pmail/config \
    /var/www/html/.well-known/acme-challenge \
    /etc/nginx/sites-available \
    /etc/nginx/sites-enabled

# -- remove default nginx config --
RUN rm -f /etc/nginx/sites-enabled/default

WORKDIR /opt/pmail

# -- download PMail IPv6 --
RUN wget https://github.com/kelvinzer0/PMail-IPv6/releases/download/v2.9.9/linux_amd64.zip \
    && mkdir -p /tmp/pmail \
    && unzip linux_amd64.zip -d /tmp/pmail \
    && mkdir -p /opt/pmail \
    && mv /tmp/pmail/pmail_linux_amd64 /opt/pmail/ \
    && mv /tmp/pmail/plugins /opt/pmail/ \
    && chmod +x /opt/pmail/pmail_linux_amd64 \
    && rm -rf linux_amd64.zip /tmp/pmail

# -- copy initdb --
COPY init_pmail.sql /opt/pmail/init_pmail.sql

# -- copy entrypoint --
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# expose SMTP + HTTP + HTTPS + other mail ports
EXPOSE 25 80 443 465 587 993 995

ENTRYPOINT ["/entrypoint.sh"]
