#!/bin/bash

apt update -y
apt upgrade -y

# NFS client
apt install -y nfs-common

# Nginx
apt install -y nginx
systemctl enable nginx

# Install NodeJS 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | bash - &&\
	apt-get install -y nodejs

# PHP
apt install -y php8.1-ctype php8.1-common php8.1-curl php8.1-dom php8.1-fileinfo php8.1-pdo php8.1-cli php8.1-fpm php8.1-curl php8.1-dom php8.1-mbstring php8.1-pgsql php8.1-zip php8.1-tokenizer php8.1-xml
php -v

# Composer
export HOME=/root
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '55ce33d7678c5a611085589f1f3ddf8b3c52d662cd01d4ba75c0ee0459970c2200a51f492d557530c71c15d8dba01eae') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
mv composer.phar /usr/local/bin/composer

# Mount NFS
mkdir -p /var/www/efs
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.0.0.181:/ /var/www/efs
ls -lah /var/www/efs

# Clone laravel project
git clone https://github.com/itsgitz/lksjabar2023-modul3.git /var/www/efs/modul3.lkscc.my.id
chown ubuntu:www-data /var/www/efs/modul3.lkscc.my.id -Rf
chmod 777 /var/www/efs/modul3.lkscc.my.id/storage -Rf

ls -lah /var/www/efs/modul3.lkscc.my.id

cd /var/www/efs/modul3.lkscc.my.id && \
	composer install && \
	npm install && \
	npm run build

# Configure Laravel .env
cat << EOF > /var/www/efs/modul3.lkscc.my.id/.env
APP_NAME="lksjabar2023modul3"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://modul3.lkscc.my.id
LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug
DB_CONNECTION=pgsql
DB_HOST=lksccjabar2023-rds.cluster-cldlmyb0vf4w.ap-southeast-1.rds.amazonaws.com
DB_PORT=5432
DB_DATABASE=lksjabarmodul3
DB_USERNAME=postgres
DB_PASSWORD=sapi.1234
BROADCAST_DRIVER=log
CACHE_DRIVER=dynamodb
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync
SESSION_DRIVER=dynamodb
SESSION_LIFETIME=120
MEMCACHED_HOST=127.0.0.1
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379
MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"
AWS_ACCESS_KEY_ID=YOURAWSACCESSKEY
AWS_SECRET_ACCESS_KEY=YOURAWSSECRETKEY
AWS_DEFAULT_REGION=ap-southeast-1
AWS_BUCKET=
AWS_USE_PATH_STYLE_ENDPOINT=false
DYNAMODB_CACHE_TABLE=lksccjabar2023-dynamodb
PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_HOST=
PUSHER_PORT=443
PUSHER_SCHEME=https
PUSHER_APP_CLUSTER=mt1
VITE_PUSHER_APP_KEY="${PUSHER_APP_KEY}"
VITE_PUSHER_HOST="${PUSHER_HOST}"
VITE_PUSHER_PORT="${PUSHER_PORT}"
VITE_PUSHER_SCHEME="${PUSHER_SCHEME}"
VITE_PUSHER_APP_CLUSTER="${PUSHER_APP_CLUSTER}"
EOF

chown ubuntu:www-data /var/www/efs/modul3.lkscc.my.id/.env

cd /var/www/efs/modul3.lkscc.my.id && \
	php artisan key:generate && \
	php artisan migrate --force --isolated && \
	php artisan config:cache && \
	php artisan route:cache && \
	php artisan view:cache && \
	php artisan storage:link

# Setup nginx
cat << EOF > /etc/nginx/sites-available/modul3.lkscc.my.id
server {
    server_name modul3.lkscc.my.id;
    root /var/www/efs/modul3.lkscc.my.id/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

	listen 80;
}
EOF
rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/modul3.lkscc.my.id /etc/nginx/sites-enabled/

nginx -t
systemctl restart nginx
