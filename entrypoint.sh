#!/bin/bash
set -e

DOMAIN=${DOMAIN}
WEB_DOMAIN=${WEB_DOMAIN}
DKIM_SELECTOR=${DKIM_SELECTOR:-default}

#############################################
# 0. Validate ENV
#############################################
if [ -z "$DOMAIN" ] || [ -z "$WEB_DOMAIN" ]; then
  echo "ERROR: ENV DOMAIN and WEB_DOMAIN must be set"
  exit 1
fi

echo "========================================="
echo "PMail Initialization Script"
echo "========================================="
echo "Mail Domain: $DOMAIN"
echo "Web Domain:  $WEB_DOMAIN"
echo "========================================="


#############################################
# 1. DKIM Key
#############################################
echo "==> Checking DKIM key..."
mkdir -p config/dkim
if [ ! -f "config/dkim/dkim.priv" ]; then
    echo "==> Generating DKIM key..."
    openssl genrsa -out config/dkim/dkim.priv 2048
    openssl rsa -in config/dkim/dkim.priv -pubout -out config/dkim/dkim.pub
    echo "✓ DKIM key generated"
else
    echo "✓ DKIM key already exists"
fi


#############################################
# 2. Generate / Renew SSL (ONLY ONCE)
#############################################
echo "==> Checking SSL certificate..."
LE_PATH="/etc/letsencrypt/live/$DOMAIN"

if [ ! -d "$LE_PATH" ]; then
    echo "==> SSL not found, requesting new certificate..."

    # Temporary Nginx for certbot
    mkdir -p /var/www/html
    cat > /etc/nginx/sites-available/pmail-certbot <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name $DOMAIN $WEB_DOMAIN;

    root /var/www/html;

    location ^~ /.well-known/acme-challenge/ {
        default_type "text/plain";
        root /var/www/html;
        allow all;
    }

    location / {
        return 200 "PMail - Ready for certificate generation\n";
        add_header Content-Type text/plain;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/pmail-certbot /etc/nginx/sites-enabled/pmail-certbot
    nginx -t
    nginx
    sleep 3

    # Certbot request
    certbot --nginx \
        -d "$DOMAIN" \
        -d "$WEB_DOMAIN" \
        --email "admin@$DOMAIN" \
        --agree-tos \
        --non-interactive \
        --redirect \
        --keep-until-expiring \
        || {
            echo "⚠️ Certbot failed, generating fallback self-signed cert..."
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout /tmp/selfsigned.key \
                -out /tmp/selfsigned.crt \
                -subj "/C=US/ST=State/L=City/O=PMail/CN=$DOMAIN"

            mkdir -p "$LE_PATH"
            cp /tmp/selfsigned.key $LE_PATH/privkey.pem
            cp /tmp/selfsigned.crt $LE_PATH/fullchain.pem
        }

    echo "✓ SSL generated"
else
    echo "✓ SSL already exists, skipping generation"
fi

nginx -s stop || true


#############################################
# 3. Copy cert to PMail config (prevent overwrite)
#############################################
echo "==> Checking PMail SSL files..."
mkdir -p config/ssl

if [ ! -f "config/ssl/private.key" ] || [ ! -f "config/ssl/public.crt" ]; then
    echo "==> Copying certificates to PMail config..."
    cp $LE_PATH/privkey.pem config/ssl/private.key
    cp $LE_PATH/fullchain.pem config/ssl/public.crt
    echo "✓ Certificates copied"
else
    echo "✓ SSL files already exist, skipping copy"
fi


#############################################
# 4. Database init (prevent recreate)
#############################################
DB_PATH="/opt/pmail/config/pmail.db"
INIT_SQL="/opt/pmail/init_pmail.sql"

echo "==> Checking database..."
mkdir -p /opt/pmail/config

if [ ! -f "$DB_PATH" ]; then
    echo "==> Creating SQLite database..."
    sqlite3 "$DB_PATH" < "$INIT_SQL"
    echo "✓ Database created"
else
    echo "✓ Database already exists, skipping"
fi


#############################################
# 5. config.json — prevent overwrite
#############################################
echo "==> Checking config.json..."
if [ ! -f "config/config.json" ]; then
cat <<EOF > config/config.json
{
  "logLevel": "info",
  "domain": "$DOMAIN",
  "webDomain": "$WEB_DOMAIN",
  "dkimPrivateKeyPath": "config/dkim/dkim.priv",
  "sslType": "1",
  "SSLPrivateKeyPath": "config/ssl/private.key",
  "SSLPublicKeyPath": "config/ssl/public.crt",
  "dbDSN": "./config/pmail.db",
  "dbType": "sqlite",
  "httpsEnabled": 0,
  "httpPort": 80,
  "httpsPort": 443,
  "spamFilterLevel": 0,
  "binding_host": "::",
  "isInit": true
}
EOF
    echo "✓ config.json created"
else
    echo "✓ config.json already exists, skipping"
fi


#############################################
# 6. Start PMail
#############################################
echo "========================================="
echo "✓ INITIALIZATION COMPLETE"
echo "========================================="
echo ""

echo "==> Starting PMail daemon..."
exec ./pmail_linux_amd64
