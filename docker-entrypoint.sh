#!/usr/bin/env bash

# TODO: make this script more robust and remove this
set -euo pipefail

rm -f /tmp/docker-entrypoint.pid

print() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]" "$@"
}

create_database() {
    print 'Creating database...'
    php docker-tool.php create_database

    print 'Creating tables...'
    # create database tables
    php xcat Migration new

    print 'Importing settings...'
    # import settings from /app/config/settings.json
    php xcat Tool importAllSettings

    echo -e "$SSPANEL_ADMIN_EMAIL\n$SSPANEL_ADMIN_PASSWORD\ny" |
        php xcat Tool createAdmin

    # download clients defined in /app/config/clients.json
    # php xcat ClientDownload
    # update /app/config/.config.php to current version and download maxmind database
    # php xcat Update
}

php docker-tool.php tables_exist || create_database

# for healthcheck, let docker know the database has been created
echo $$ >/tmp/docker-entrypoint.pid

i=0
while :; do
    # every 1 minute
    php docker-tool.php user_exists >/dev/null || {
        print 'Creating redis user...'
        php docker-tool.php create_acl
    }

    # every 5 minutes
    [[ $((i % 5)) == 0 ]] && {
        print 'Running cron jobs...'
        php xcat Cron
    }

    # every 24 hours
    [[ $((i % 1440)) == 0 ]] && {

        print 'Updating maxmind database...'
        # TODO
        # php docker-tool.php download_mmdb
    }

    # reset every 7 days
    [[ $i -ge 10080 ]] && i=0

    # ((i++)) returns 1 when i is 0
    : $((i++))

    sleep 60
done
