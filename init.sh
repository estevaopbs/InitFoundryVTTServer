# Enable non-lts upgrade
sed -i 's/Prompt=lts/Prompt=normal/g' /etc/update-manager/release-upgrades

# Update
apt update

# Upgrade
apt upgrade -y

# Release upgrade
do-release-upgrade -d -f DistUpgradeViewNonInteractive

# Install apache2
apt install apache2 unzip nodejs -y

# Update
apt update

# Upgrade
apt upgrade -y

# Enable apache2 modules
a2enmod ssl rewrite proxy proxy_http

# Receive FoundryVTT download link as user input 
echo "Enter the FoundryVTT download link:"
read downloadLink

# Download FoundryVTT
cd /tmp
curl -o foundryvtt.zip "$downloadLink"

# Create user foundryvtt
adduser --disabled-password --gecos "" foundryvtt

# Create foundryvtt directory
mkdir /home/foundryvtt/foundryvtt

# Unzip FoundryVTT
unzip foundryvtt.zip -d /home/foundryvtt/foundryvtt

# Create foundrydata directory
mkdir /home/foundryvtt/foundrydata

# Change owner of foundrydata directory
chown -R foundryvtt:foundryvtt /home/foundryvtt/foundrydata

# Change owner of foundryvtt directory
chown -R foundryvtt:foundryvtt /home/foundryvtt/foundryvtt

# Create foundryvtt.service
echo "[Unit]
Description=Foundry Virtual Tabletop

[Service]
User=foundryvtt
ExecStart=node /home/foundryvtt/foundryvtt/resources/app/main.js --dataPath=/home/foundryvtt/foundrydata
Restart=always

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/foundryvtt.service

# Enable foundryvtt.service
systemctl enable foundryvtt

# Start foundryvtt.service
systemctl start foundryvtt

# Create certificate directory
mkdir /home/foundryvtt/certificate

# Create private.key
openssl genpkey -algorithm RSA -out /home/foundryvtt/certificate/private.key

# Create csr.pem
openssl req -new -key /home/foundryvtt/certificate/private.key -out /home/foundryvtt/certificate/csr.pem

# Instruct the user to generate the certificate using csr.pem
echo "Generate the certificate using the following csr.pem:"
cat /home/foundryvtt/certificate/csr.pem

# Receive the ssl certificate as user input
echo "Enter the ssl certificate:"
read sslCertificate

# Write certificate.crt
echo "$sslCertificate" > /home/foundryvtt/certificate/certificate.crt

# Receive domain name as user input
echo "Enter the domain name:"
read domainName

# Create apache config file
echo "ServerName $domainName

<VirtualHost *:80>
    ServerName $domainName
    ServerAlias *.$domainName

    RewriteEngine On
    RewriteCond %{HTTP_HOST} !^www\. [NC,OR]
    RewriteCond %{HTTPS} off
    RewriteRule ^ https://www.$domainName%{REQUEST_URI} [NE,R=301,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName $domainName
    ServerAlias *.$domainName

    # SSL Configuration
    SSLCertificateKeyFile   \"/home/foundryvtt/certificate/private.key\"
    SSLCertificateFile      \"/home/foundryvtt/certificate/certificate.crt\"

    # Redirect non-www to www for HTTPS
    RewriteEngine On
    RewriteCond %{HTTP_HOST} !^www\. [NC]
    RewriteRule ^ https://www.%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

    # Proxy Server Configuration
    ProxyPreserveHost       On
    ProxyPass \"/socket.io/\" \"ws://localhost:30000/socket.io/\"
    ProxyPass /             http://localhost:30000/
    ProxyPassReverse /      http://localhost:30000/
    RequestHeader set X-Forwarded-For %{REMOTE_ADDR}s
    RequestHeader set X-Forwarded-Proto \"https\"
</VirtualHost>" > /etc/apache2/sites-available/$domainName.conf

# Enable $domainName.conf
a2ensite $domainName.conf

# Write .htaccess
echo "RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)\$ https://www.$domainName/\$1 [L,R=301]" > /var/www/html/.htaccess

# Append to 000-default.conf
echo "
<Directory /var/www/html>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride All
    Require all granted
</Directory>" >> /etc/apache2/sites-available/000-default.conf

# Restart apache2
systemctl restart apache2

# Write options.json
echo "{
  "dataPath": "/home/foundryvtt/foundrydata",
  "compressStatic": true,
  "fullscreen": false,
  "hostname": "www.$domainName",
  "language": "en.core",
  "localHostname": null,
  "port": 30000,
  "protocol": null,
  "proxyPort": 443,
  "proxySSL": true,
  "routePrefix": null,
  "updateChannel": "stable",
  "upnp": true,
  "upnpLeaseDuration": null,
  "awsConfig": null,
  "compressSocket": true,
  "cssTheme": "foundry",
  "deleteNEDB": false,
  "hotReload": false,
  "passwordSalt": null,
  "sslCert": null,
  "sslKey": null,
  "world": null,
  "serviceConfig": null,
  "telemetry": false
}" > /home/foundryvtt/foundrydata/Config/options.json

# Change owner of options.json
chown foundryvtt:foundryvtt /home/foundryvtt/foundrydata/Config/options.json

# Restart foundryvtt.service
systemctl restart foundryvtt