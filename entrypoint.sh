#!/bin/bash
set -e

DOMAIN=${DOMAIN}
WEB_DOMAIN=${WEB_DOMAIN}
DKIM_SELECTOR=${DKIM_SELECTOR:-default}

if [ -z "$DOMAIN" ] || [ -z "$WEB_DOMAIN" ]; then
  echo "ERROR: ENV DOMAIN and WEB_DOMAIN must be set"
  exit 1
fi

echo "==> Generating DKIM key..."
openssl genrsa -out config/dkim/dkim.priv 2048
openssl rsa -in config/dkim/dkim.priv -pubout -out config/dkim/dkim.pub

# Export the DKIM public key to ENV output (for user DNS)
export DKIM_PUBLIC_KEY=$(sed ':a;N;$!ba;s/\n//g' config/dkim/dkim.pub)

echo "==> Starting temporary nginx for Certbot..."
nginx

echo "==> Requesting SSL certificate..."
certbot certonly --webroot \
    -w /var/www/html \
    -d "$DOMAIN" \
    -d "$WEB_DOMAIN" \
    --email admin@$DOMAIN --agree-tos --non-interactive

echo "==> Copying SSL certificates..."
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem config/ssl/private.key
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem config/ssl/public.crt

echo "==> Stopping nginx..."
nginx -s stop || true

# === INIT SQLITE DB if not exist ===
DB_PATH="/opt/pmail/config/pmail.db"
INIT_SQL="/opt/pmail/init_pmail.sql"

if [ ! -f "$DB_PATH" ]; then
    echo "==> Creating initial SQLite database (admin user)..."
    sqlite3 "$DB_PATH" < "$INIT_SQL"
    echo "==> Database created at $DB_PATH"
else
    echo "==> SQLite database exists, skipping initialization."
fi

echo "==> Creating config.json..."

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
  "isInit": true
}
EOF

echo "==> CONFIG READY"
echo "==> DKIM PUBLIC KEY (ADD TO DNS):"
cat config/dkim/dkim.pub

echo "==> Starting PMail daemon..."
exec ./pmail_linux_amd64
