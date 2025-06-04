#!/bin/bash
cat << "EOF"
     _ _ _      _      _      _       _        ___         _        _ _
  _ | (_) |_ __(_)___ /_\  __| |_ __ (_)_ _   |_ _|_ _  __| |_ __ _| | |___ _ _
 | || | |  _(_-< |___/ _ \/ _` | '  \| | ' \   | || ' \(_-<  _/ _` | | / -_) '_|
  \__/|_|\__/__/_|  /_/ \_\__,_|_|_|_|_|_||_| |___|_||_/__/\__\__,_|_|_\___|_|


EOF
BRANCH=${1:-master}
sudo mkdir -p /var/www

echo ""
echo ******INSTALLING DEPENDENCIES******
echo ""
sudo apt update
sudo service apache2 stop
sudo apt-get purge apache2 apache2-utils apache2.2-bin apache2-common php php-*
sudo apt-get autoremove
sudo apt install -y lsb-release gnupg2 ca-certificates apt-transport-https software-properties-common
sudo add-apt-repository ppa:ondrej/php

sudo apt install -y \
    git curl lsb-release ca-certificates apt-transport-https software-properties-common gnupg2 mysql-server \
    nginx nginx-extras\
    php8.2 php8.2-{bcmath,fpm,xml,mysql,zip,intl,ldap,gd,cli,bz2,curl,mbstring,opcache,soap,cgi,dom,simplexml}
curl -sL https://deb.nodesource.com/setup_18.x | sudo bash -
sudo apt -y install nodejs

clear

echo ""
echo ******INSTALLING JITSI-ADMIN*******
echo ""

pushd /var/www
[ ! -d "/var/www/meetup" ] && git clone https://github.com/sazaco/jitsi-admin.git

popd

pushd /var/www/meetup
git -C /var/www/meetup checkout $BRANCH
git -C /var/www/meetup reset --hard
git -C /var/www/meetup pull

export COMPOSER_ALLOW_SUPERUSER=1
php composer.phar install --no-interaction
php composer.phar dump-autoload
cp -n .env.sample .env.local

sudo mysql -e "CREATE USER 'meetup'@'localhost' IDENTIFIED  BY 'meetup';"
sudo mysql -e "GRANT ALL PRIVILEGES ON meetup.* TO 'meetup'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

php bin/console app:install

php bin/console cache:clear

php bin/console doctrine:database:create --if-not-exists --no-interaction

php bin/console doctrine:migrations:migrate --no-interaction

php bin/console cache:clear

php bin/console cache:warmup
php bin/console app:system:repair

clear
echo ""
echo *******Build JS and CSS********
echo ""
npm install
npm run build
rm -rf node_modules/

clear
echo ""
echo *******Build Webesocket********
echo ""
popd
pushd /var/www/meetup/nodejs
npm install
popd

clear

pushd /var/www/meetup
echo ""
echo *******CONFIGURING SERVICES********
echo ""

crontab -l > cron_bkp
echo "* * * * * php /var/www/meetup/bin/console cron:run 1>> /dev/null 2>&1" > cron_bkp
crontab cron_bkp
rm cron_bkp

chown -R www-data:www-data var/
chown -R www-data:www-data public/
chown -R www-data:www-data theme/



cp installer/nginx.conf /etc/nginx/sites-enabled/meetup.conf
rm /etc/nginx/sites-enabled/default
cp installer/meetup_messenger.service /etc/systemd/system/meetup_messenger.service
cp installer/meetup.conf /etc/systemd/system/meetup.conf

cp -r nodejs /usr/local/bin/websocket
cp installer/meetup_websocket.service /etc/systemd/system/meetup_websocket.service
mkdir /var/log/websocket/


service php*-fpm restart
service nginx restart

systemctl daemon-reload
service  meetup* stop

service  meetup_messenger start
service  meetup_messenger restart

systemctl enable meetup_messenger

systemctl daemon-reload

service  meetup_websocket start
service  meetup_websocket restart

systemctl enable meetup_websocket


popd

cat << "EOF"
  ___         _        _ _        _                            __      _
 |_ _|_ _  __| |_ __ _| | |___ __| |  ____  _ __ __ ___ ______/ _|_  _| |
  | || ' \(_-|  _/ _` | | / -_/ _` | (_-| || / _/ _/ -_(_-(_-|  _| || | |
 |___|_||_/__/\__\__,_|_|_\___\__,_| /__/\_,_\__\__\___/__/__|_|  \_,_|_|
EOF

