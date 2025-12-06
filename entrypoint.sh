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

# Export the DKIM public key to ENV output (for user DNS)
export DKIM_PUBLIC_KEY=$(sed ':a;N;$!ba;s/\n//g' config/dkim/dkim.pub)

echo "==> Creating directories..."
mkdir -p /var/www/html/.well-known/acme-challenge
mkdir -p config/ssl

echo "==> Starting temporary nginx for Certbot..."
nginx

echo "==> Checking Certbot version..."
certbot --version || echo "Certbot version check failed"

echo "==> Requesting SSL certificate..."

# Method 1: Try with pip-installed certbot (fixes AttributeError bug)
if command -v python3 &> /dev/null; then
    echo "==> Installing/Upgrading certbot via pip..."
    pip3 install --upgrade certbot >/dev/null 2>&1 || true
fi

# Method 2: Use certbot with minimal options to avoid the bug
certbot certonly \
    --webroot \
    -w /var/www/html \
    -d "$DOMAIN" \
    -d "$WEB_DOMAIN" \
    --email "admin@$DOMAIN" \
    --agree-tos \
    --non-interactive \
    --keep-until-expiring \
    2>&1 | tee /tmp/certbot.log || {
        
        echo "==> Certbot webroot failed. Checking logs..."
        cat /var/log/letsencrypt/letsencrypt.log | tail -20
        
        echo "==> Trying standalone mode..."
        nginx -s stop || true
        sleep 3
        
        certbot certonly \
            --standalone \
            -d "$DOMAIN" \
            -d "$WEB_DOMAIN" \
            --email "admin@$DOMAIN" \
            --agree-tos \
            --non-interactive \
            --keep-until-expiring \
            2>&1 | tee /tmp/certbot_standalone.log || {
                
                echo ""
                echo "========================================="
                echo "ERROR: Certificate generation failed"
                echo "========================================="
                echo ""
                echo "Logs from Certbot:"
                cat /var/log/letsencrypt/letsencrypt.log | tail -30
                echo ""
                echo "Common issues:"
                echo "1. DNS not pointing to this server:"
                echo "   Run: dig +short $DOMAIN"
                echo "   Run: dig +short $WEB_DOMAIN"
                echo ""
                echo "2. Port 80 blocked:"
                echo "   Run: nc -zv $(hostname -I | awk '{print $1}') 80"
                echo ""
                echo "3. Certbot bug (AttributeError):"
                echo "   Try: pip3 install --upgrade --force-reinstall certbot"
                echo ""
                echo "4. Rate limit exceeded:"
                echo "   Check: https://crt.sh/?q=$DOMAIN"
                echo "   Wait 1 hour if you see many recent attempts"
                echo ""
                echo "========================================="
                
                # Create self-signed certificate as fallback
                echo "==> Generating self-signed certificate as fallback..."
                openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                    -keyout config/ssl/private.key \
                    -out config/ssl/public.crt \
                    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN" \
                    2>/dev/null
                
                echo "==> Self-signed certificate created. PMail will start but SSL won't be trusted."
                echo "==> Fix DNS/firewall and restart container to get real certificate."
                return 0
            }
    }

echo "==> Copying SSL certificates..."
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem config/ssl/private.key
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem config/ssl/public.crt

echo "==> Stopping nginx..."
nginx -s stop || true
sleep 2

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
echo ""
echo "========================================="
echo "DKIM PUBLIC KEY (ADD TO DNS):"
echo "========================================="
echo "TXT Record:"
echo "Name: $DKIM_SELECTOR._domainkey.$DOMAIN"
echo "Value:"
cat config/dkim/dkim.pub
echo "========================================="
echo ""

echo "==> Starting PMail daemon..."
exec ./pmail_linux_amd64
