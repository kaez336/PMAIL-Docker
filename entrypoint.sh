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
mkdir -p config/dkim
openssl genrsa -out config/dkim/dkim.priv 2048
openssl rsa -in config/dkim/dkim.priv -pubout -out config/dkim/dkim.pub

export DKIM_PUBLIC_KEY=$(sed ':a;N;$!ba;s/\n//g' config/dkim/dkim.pub)

echo "==> Creating directories..."
mkdir -p /var/www/html/.well-known/acme-challenge
mkdir -p config/ssl

echo "==> Creating Nginx configuration for Certbot..."
cat > /etc/nginx/sites-available/certbot <<EOF
server {
    listen 80;
    listen [::]:80;
    
    server_name $DOMAIN $WEB_DOMAIN;

    root /var/www/html;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files \$uri =404;
    }

    location / {
        return 200 "Ready for certificate generation";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/certbot /etc/nginx/sites-enabled/certbot

echo "==> Testing Nginx configuration..."
nginx -t

echo "==> Starting Nginx..."
nginx

echo "==> Waiting for Nginx to start..."
sleep 3

echo "==> Checking if Nginx is running..."
if ! pgrep -x "nginx" > /dev/null; then
    echo "ERROR: Nginx failed to start"
    exit 1
fi

echo "==> Requesting SSL certificate using Nginx plugin..."
# Use --nginx plugin which is more reliable than webroot
certbot --nginx \
    -d "$DOMAIN" \
    -d "$WEB_DOMAIN" \
    --email "admin@$DOMAIN" \
    --agree-tos \
    --non-interactive \
    --redirect \
    --keep-until-expiring \
    || {
        echo ""
        echo "========================================="
        echo "ERROR: Certbot failed"
        echo "========================================="
        
        echo "==> Showing last 30 lines of certbot log..."
        tail -30 /var/log/letsencrypt/letsencrypt.log
        
        echo ""
        echo "==> Diagnostic Information:"
        echo "1. Checking DNS resolution..."
        dig +short $DOMAIN || echo "  DNS lookup failed for $DOMAIN"
        dig +short $WEB_DOMAIN || echo "  DNS lookup failed for $WEB_DOMAIN"
        
        echo ""
        echo "2. Checking port 80..."
        netstat -tuln | grep :80 || echo "  Port 80 not listening"
        
        echo ""
        echo "3. Testing local HTTP access..."
        curl -I http://localhost/.well-known/acme-challenge/test 2>&1 | head -5
        
        echo ""
        echo "==> Generating self-signed certificate as fallback..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout config/ssl/private.key \
            -out config/ssl/public.crt \
            -subj "/C=US/ST=State/L=City/O=PMail/CN=$DOMAIN" \
            2>/dev/null
        
        echo ""
        echo "⚠️  WARNING: Using self-signed certificate"
        echo "   Fix issues and restart to get valid certificate"
        echo ""
        
        # Continue with self-signed cert
    }

if [ -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
    echo "==> Copying SSL certificates..."
    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem config/ssl/private.key
    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem config/ssl/public.crt
    echo "✓ Valid SSL certificate installed"
else
    echo "⚠️  Using self-signed certificate"
fi

echo "==> Stopping Nginx (PMail will handle HTTPS)..."
nginx -s stop || true
sleep 2

# === INIT SQLITE DB if not exist ===
DB_PATH="/opt/pmail/config/pmail.db"
INIT_SQL="/opt/pmail/init_pmail.sql"

if [ ! -f "$DB_PATH" ]; then
    echo "==> Creating initial SQLite database..."
    sqlite3 "$DB_PATH" < "$INIT_SQL"
    echo "✓ Database created at $DB_PATH"
else
    echo "✓ SQLite database exists"
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

echo ""
echo "========================================="
echo "✓ CONFIGURATION COMPLETE"
echo "========================================="
echo ""
echo "DKIM DNS Record:"
echo "  Type: TXT"
echo "  Name: $DKIM_SELECTOR._domainkey.$DOMAIN"
echo "  Value:"
cat config/dkim/dkim.pub | grep -v "BEGIN\|END" | tr -d '\n'
echo ""
echo ""
echo "MX Record:"
echo "  Type: MX"
echo "  Name: @"
echo "  Value: $DOMAIN"
echo "  Priority: 10"
echo ""
echo "SPF Record:"
echo "  Type: TXT"
echo "  Name: @"
echo "  Value: v=spf1 mx ~all"
echo ""
echo "DMARC Record:"
echo "  Type: TXT"
echo "  Name: _dmarc"
echo "  Value: v=DMARC1; p=none; rua=mailto:postmaster@$DOMAIN"
echo "========================================="
echo ""

echo "==> Starting PMail daemon..."
exec ./pmail_linux_amd64
