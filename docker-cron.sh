#!/usr/bin/env bash

# TODO: make this script more robust and remove this
set -euo pipefail

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

    # create admin user
    echo -e "$SSPANEL_ADMIN_EMAIL\n$SSPANEL_ADMIN_PASSWORD\ny" |
        php xcat Tool createAdmin

    # download clients defined in /app/config/clients.json
    # php xcat ClientDownload
    # update /app/config/.config.php to current version and download maxmind database
    # php xcat Update
}

rm -f /tmp/docker-cron.pid

php docker-tool.php tables_exist || create_database

# for healthcheck, let docker know the database has been created
echo -n $$ >/tmp/docker-cron.pid

shutdown() {
    print 'Shutting down...'
    kill $(jobs -p)
    print 'Goodbye'
}

trap shutdown EXIT

cron_1m() {
    php docker-tool.php user_exists >/dev/null || {
        print 'Creating redis user...'
        php docker-tool.php create_acl || :
        print 'Created redis user'
    }
}

cron_5m() {
    php xcat Cron || :
}

cron_24h() {
    print 'Downloading maxmind database...'
    php docker-tool.php download_mmdb || :
    print 'Downloaded maxmind database'
}

cron_7d() {
    print 'Resetting counter...'
    i=0
}

i=0
while :; do
    print 'Running every 1 minute cron jobs...'
    cron_1m
    print 'Every 1 minute cron jobs done'

    [[ $((i % 5)) -eq 0 ]] && {
        print 'Running every 5 minutes cron jobs...'
        cron_5m
        print 'Every 5 minutes cron jobs done'
    }

    [[ $i -eq 0 || $((i % 1440)) -eq 0 ]] && {
        print 'Running every 24 hours cron jobs...'
        cron_24h
        print 'Every 24 hours cron jobs done'
    }

    [[ $i -ge 10080 ]] && {
        print 'Running every 7 days cron jobs...'
        cron_7d
        print 'Every 7 days cron jobs done'
    }

    # ((i++)) returns 1 when i is 0
    : $((i++))

    sleep 60 &
    wait
done
