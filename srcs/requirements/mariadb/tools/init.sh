#!/bin/bash
set -e

MYSQL_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

echo ">>> init.sh 開始!"

if [ ! -d /var/lib/mysql/mysql ]; then
	echo ">>> mariaDBを初期化..."
	mariadb-install-db --user=mysql --datadir=/var/lib/mysql
	mariadbd --user=mysql --skip-networking &
	until mariadb-admin ping --silent; do sleep 1; done

	mariadb -u root << EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
FLUSH PRIVILEGES;
EOF

	mariadb-admin -u root -p${MYSQL_ROOT_PASSWORD} shutdown
fi

echo ">>> MariaDB起動"

exec mariadbd --user=mysql --skip-networking=0