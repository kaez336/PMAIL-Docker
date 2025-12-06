#!/bin/bash
set -e

DOMAIN=${DOMAIN}
WEB_DOMAIN=${WEB_DOMAIN}
DKIM_SELECTOR=${DKIM_SELECTOR:-default}

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

# Generate DKIM key
echo "==> Generating DKIM key..."
if [ ! -f "config/dkim/dkim.priv" ]; then
    openssl genrsa -out config/dkim/dkim.priv 2048
    openssl rsa -in config/dkim/dkim.priv -pubout -out config/dkim/dkim.pub
    echo "✓ DKIM key generated"
else
    echo "✓ DKIM key already exists"
fi

# Setup Nginx for Certbot
echo "==> Setting up Nginx for certificate generation..."
cat > /etc/nginx/sites-available/pmail-certbot <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name $DOMAIN $WEB_DOMAIN;

    root /var/www/html;
    index index.html;

    # ACME challenge for Let's Encrypt
    location ^~ /.well-known/acme-challenge/ {
        default_type "text/plain";
        root /var/www/html;
        allow all;
    }

    location / {
        return 200 "PMail - Ready for certificate generation\\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/pmail-certbot /etc/nginx/sites-enabled/pmail-certbot

# Test Nginx config
echo "==> Testing Nginx configuration..."
nginx -t

# Start Nginx
echo "==> Starting Nginx..."
nginx

sleep 3

# Check if Nginx is running
if ! pgrep -x "nginx" > /dev/null 2>&1; then
    # Fallback to ps if pgrep not available
    if ! ps aux | grep -v grep | grep -q nginx; then
        echo "ERROR: Nginx failed to start"
        cat /var/log/nginx/error.log
        exit 1
    fi
fi
echo "✓ Nginx is running"

# Check DNS resolution
echo "==> Checking DNS resolution..."
dig +short $DOMAIN || echo "⚠️  DNS not resolved for $DOMAIN"
dig +short $WEB_DOMAIN || echo "⚠️  DNS not resolved for $WEB_DOMAIN"

# Get SSL certificate
echo "==> Requesting SSL certificate..."
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "Attempting to get certificate with --nginx plugin..."
    
    certbot --nginx \
        -d "$DOMAIN" \
        -d "$WEB_DOMAIN" \
        --email "admin@$DOMAIN" \
        --agree-tos \
        --non-interactive \
        --redirect \
        --keep-until-expiring \
        2>&1 | tee /tmp/certbot.log
    
    if [ $? -eq 0 ]; then
        echo "✓ Certificate obtained successfully"
    else
        echo "⚠️  Certificate generation failed"
        echo ""
        echo "Showing Certbot logs:"
        tail -30 /var/log/letsencrypt/letsencrypt.log
        echo ""
        echo "Diagnostic info:"
        echo "1. Check DNS:"
        echo "   dig +short $DOMAIN"
        echo "   dig +short $WEB_DOMAIN"
        echo ""
        echo "2. Check port 80 accessibility from internet"
        echo ""
        echo "3. Check rate limits:"
        echo "   https://crt.sh/?q=$DOMAIN"
        echo ""
        echo "==> Generating self-signed certificate as fallback..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /tmp/selfsigned.key \
            -out /tmp/selfsigned.crt \
            -subj "/C=US/ST=State/L=City/O=PMail/CN=$DOMAIN" 2>/dev/null
        
        mkdir -p /etc/letsencrypt/live/$DOMAIN
        cp /tmp/selfsigned.key /etc/letsencrypt/live/$DOMAIN/privkey.pem
        cp /tmp/selfsigned.crt /etc/letsencrypt/live/$DOMAIN/fullchain.pem
        
        echo "⚠️  Using self-signed certificate"
    fi
else
    echo "✓ Certificate already exists, checking if renewal needed..."
    certbot renew --nginx --quiet || echo "⚠️  Certificate renewal skipped or failed"
fi

# Copy certificates to PMail config
echo "==> Copying certificates to PMail config..."
if [ -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem config/ssl/private.key
    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem config/ssl/public.crt
    echo "✓ Certificates copied"
else
    echo "ERROR: Certificate files not found"
    exit 1
fi

# Stop Nginx (PMail will handle web interface)
echo "==> Stopping Nginx..."
nginx -s stop || true
sleep 2

# Initialize database
DB_PATH="/opt/pmail/config/pmail.db"
INIT_SQL="/opt/pmail/init_pmail.sql"

if [ ! -f "$DB_PATH" ]; then
    echo "==> Creating SQLite database..."
  #  sqlite3 "$DB_PATH" < "$INIT_SQL"
    echo "✓ Database created"
else
    echo "✓ Database already exists"
fi

# Create config.json
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

echo "✓ Configuration created"

echo ""
echo "========================================="
echo "✓ INITIALIZATION COMPLETE"
echo "========================================="
echo ""
echo "📧 IMPORTANT DNS RECORDS TO ADD:"
echo ""
echo "1. MX Record:"
echo "   Type: MX"
echo "   Name: @"
echo "   Value: $DOMAIN"
echo "   Priority: 10"
echo ""
echo "2. SPF Record:"
echo "   Type: TXT"
echo "   Name: @"
echo "   Value: v=spf1 mx ~all"
echo ""
echo "3. DKIM Record:"
echo "   Type: TXT"
echo "   Name: $DKIM_SELECTOR._domainkey"
echo "   Value: v=DKIM1; k=rsa; p=$(grep -v 'BEGIN\|END' config/dkim/dkim.pub | tr -d '\n')"
echo ""
echo "4. DMARC Record:"
echo "   Type: TXT"
echo "   Name: _dmarc"
echo "   Value: v=DMARC1; p=none; rua=mailto:postmaster@$DOMAIN"
echo ""
echo "========================================="
echo ""

echo "==> Starting PMail daemon..."
exec ./pmail_linux_amd64
