#!/bin/bash
set -e

DB_PASSWORD=$(cat /run/secrets/db_password)
. /run/secrets/credentials

if [ ! -f wp-config.php ]; then
   echo "init.sh: first run, installing WordPress"
   wp core download --allow-root
   wp config create --dbname="$MYSQL_DATABASE" --dbuser="$MYSQL_USER" --dbpass="$DB_PASSWORD" --dbhost=mariadb --allow-root
   wp core install --url="https://$DOMAIN_NAME" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_EMAIL" --skip-email --allow-root
   wp user create "$WP_USER" "$WP_USER_EMAIL" --role=author --user_pass="$WP_USER_PASSWORD" --allow-root
   chown -R www-data:www-data /var/www/html
else
   echo "init.sh: WordPress already installed, skipping"
fi

echo "init.sh: starting php-fpm"
exec php-fpm8.2 -F
