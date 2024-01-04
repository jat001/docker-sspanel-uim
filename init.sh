#!/usr/bin/env bash

set -euxo pipefail

: "${ADMIN_EMAIL:=admin@example.com}"
: "${ADMIN_PASSWORD:=ChangeMe}"

container_id() {
    docker ps -qf "name=$proj-$1"
}

php_echo() {
    docker exec "$(container_id app)" php -r "require './config/.config.php'; echo \$_ENV['$1'];"
}

php_run() {
    docker exec -u www-data "$(container_id app)" php xcat "$*"
}

root="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
proj="$(basename "$root")"

docker exec "$(container_id db)" bash -c 'mariadb --password="$MARIADB_ROOT_PASSWORD" <<EOF'"
CREATE DATABASE IF NOT EXISTS $(php_echo db_prefix)$(php_echo db_database) CHARACTER SET $(php_echo db_charset) COLLATE $(php_echo db_collation);
CREATE USER IF NOT EXISTS '$(php_echo db_username)'@'localhost' IDENTIFIED BY '$(php_echo db_password)';
GRANT ALL ON sspanel.* TO 'sspanel'@'localhost';
FLUSH PRIVILEGES;
EOF
"

php_run Migration new
php_run Tool importAllSettings
echo -e "$ADMIN_EMAIL\n$ADMIN_PASSWORD\ny" | docker exec -iu www-data "$(container_id app)" php xcat Tool createAdmin
php_run ClientDownload
php_run Update
