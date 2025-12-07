===========================================================
                 PMail Auto Installer (Docker)
===========================================================

This installer image will automatically:

 - Download PMail-IPv6 binary from GitHub
 - Extract and set up folder structure
 - Start temporary nginx (for SSL provisioning)
 - Generate DKIM keys
 - Generate SSL (Let's Encrypt)
 - Create config/config.json automatically
 - Run PMail as daemon

===========================================================
                1. BUILD DOCKER IMAGE
===========================================================

Command:

    docker build -t pmail-auto .

===========================================================
                2. RUN CONTAINER
===========================================================

Command:

  docker run -d \
    --name pmail \
    -e DOMAIN=domain.com \
    -e WEB_DOMAIN=mail.domain.com \
    -p 25:25 \
    -p 587:587 \
    -p 465:465 \
    -p 80:80 \
    -p 443:443 \
    -p 110:110 \
    -p 995:995 \
    -p 993:993 \
    pmail-auto



Environment variables (ASCII Table):

+----------------+------------------------------+
| ENV VARIABLE   | DESCRIPTION                  |
+----------------+------------------------------+
| DOMAIN         | Main mail domain             |
|                | Example: domain.com          |
+----------------+------------------------------+
| WEB_DOMAIN     | HTTPS / Webmail domain       |
|                | Example: mail.domain.com     |
+----------------+------------------------------+


===========================================================
                3. REQUIRED DNS CONFIG
===========================================================

Add the following DNS records to your domain.

A RECORDS:

+------+-------------------+-----------------+
| TYPE | HOST              | VALUE           |
+------+-------------------+-----------------+
| A    | domain.com        | <SERVER_IP>     |
| A    | mail.domain.com   | <SERVER_IP>     |
+------+-------------------+-----------------+


MX RECORD:

+------+------------+-------------------+----------+
| TYPE | HOST       | VALUE             | PRIORITY |
+------+------------+-------------------+----------+
| MX   | domain.com | mail.domain.com   |   10     |
+------+------------+-------------------+----------+


SPF RECORD:

+------+-------+--------------------------------------+
| TYPE | HOST  | VALUE                                |
+------+-------+--------------------------------------+
| TXT  | @     | v=spf1 a mx ~all                     |
+------+-------+--------------------------------------+


DKIM RECORD:
(after the container generates dkim.pub)

+------+--------------------------+----------------------------+
| TYPE | HOST                     | VALUE                      |
+------+--------------------------+----------------------------+
| TXT  | default._domainkey       | v=DKIM1; k=rsa; p=<KEY>    |
+------+--------------------------+----------------------------+

NOTE:
Replace <KEY> with the public key generated in the logs.
Remove all line breaks from the key.


DMARC RECORD (optional but recommended):

+------+--------+---------------------------------------------+
| TYPE | HOST   | VALUE                                       |
+------+--------+---------------------------------------------+
| TXT  | _dmarc | v=DMARC1; p=none; rua=mailto:postmaster@... |
+------+--------+---------------------------------------------+


===========================================================
               4. IMPORTANT FILE LOCATIONS
===========================================================

+-------------------------------+----------------------------+
| PATH                          | DESCRIPTION                |
+-------------------------------+----------------------------+
| /opt/pmail/config/config.json | Main PMail config          |
| /opt/pmail/config/dkim/       | DKIM keypair               |
| /opt/pmail/config/ssl/        | SSL certificates           |
| /opt/pmail/pmail_linux_amd64  | Main PMail binary          |
+-------------------------------+----------------------------+


===========================================================
                 5. AFTER STARTUP
===========================================================

The container will print:

 - DKIM PUBLIC KEY  → add this to DNS
 - SSL status
 - PMail daemon startup log

Access PMail interface at:

    https://mail.domain.com


===========================================================
                     END OF README
===========================================================
