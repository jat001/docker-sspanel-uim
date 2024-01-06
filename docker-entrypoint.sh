#!/usr/bin/env bash

set -euo pipefail

PS4='[$(date "+%Y-%m-%d %H:%M:%S")] Line ${LINENO}: '

set -x

create_database() {
    php docker-tool.php create_database

    php xcat Migration new
    php xcat Tool importAllSettings

    echo -e "$SSPANEL_ADMIN_EMAIL\n$SSPANEL_ADMIN_PASSWORD\ny" |
        php xcat Tool createAdmin

    php xcat ClientDownload
    php xcat Update
}

php docker-tool.php tables_exist || create_database

i=0
while :; do
    php docker-tool.php user_exists || php docker-tool.php create_acl

    [[ $((i % 5)) == 0 ]] && php xcat Cron

    [[ $((i % 60)) == 0 ]] && i=0
    # ((i++)) returns 1 when i is 0
    : $((i++))
    sleep 60
done
