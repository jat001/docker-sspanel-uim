#!/usr/bin/env bash

set -euxo pipefail

container_id() {
    docker ps -qf "name=$proj-$1"
}

php_run() {
    docker exec -u www-data "$(container_id app)" php xcat "$@"
}

root="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
proj="$(basename "$root")"

php_run Update
php_run Tool importAllSettings
docker exec -u www-data "$(container_id app)" bash -c 'php xcat Migration "$DB_VER"'
