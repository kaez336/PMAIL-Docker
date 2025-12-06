FROM debian:12

# -- install dependencies --
RUN apt update && apt install -y \
    wget \
    unzip \
    zip \
    libzip-dev \
    curl \
    nginx \
    certbot \
    openssl \
    supervisor \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# -- prepare directories --
RUN mkdir -p /opt/pmail/config/dkim \
    /opt/pmail/config/ssl \
    /opt/pmail/config \
    /var/www/html

WORKDIR /opt/pmail

# -- download PMail IPv6 --
RUN wget https://github.com/kelvinzer0/PMail-IPv6/releases/download/v2.9.9/linux_amd64.zip \
    && unzip linux_amd64.zip \
    && mv pmail_linux_amd64 /opt/pmail/pmail_linux_amd64 \
    && chmod +x /opt/pmail/pmail_linux_amd64 \
    && rm linux_amd64.zip

# -- copy entrypoint --
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# expose SMTP + HTTP + HTTPS
EXPOSE 25 80 443

ENTRYPOINT ["/entrypoint.sh"]
