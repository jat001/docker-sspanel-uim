# syntax=docker/dockerfile:1

# https://github.com/docker-library/docs/blob/master/php/README.md
FROM php:fpm

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y libyaml-dev libzip-dev && \
    rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install bcmath mysqli pdo_mysql zip && \
    yes '' | pecl install redis && \
    yes '' | pecl install yaml && \
    docker-php-ext-enable opcache redis yaml && \
    rm -rf /tmp/pear

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

RUN <<EOT
#!/usr/bin/env bash

set -euxo pipefail

ln -rs /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

echo '
error_log = /proc/self/fd/2

disable_functions = '\
'passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,'\
'ini_alter,ini_restore,dl,readlink,symlink,popepassthru,stream_socket_server,fsocket,popen'\
    >>/usr/local/etc/php/conf.d/docker-fpm.ini

echo '
opcache.file_cache = /tmp/sspanel/opcache
opcache.interned_strings_buffer = 64
opcache.jit_buffer_size = 256M
opcache.max_accelerated_files = 65535
opcache.memory_consumption = 512
opcache.revalidate_freq = 60
opcache.validate_permission = 1
opcache.validate_root = 1' \
    >>/usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

cat <<EOF | sed -Ei '/^access.log/r /dev/stdin' /usr/local/etc/php-fpm.d/docker.conf

slowlog = /proc/self/fd/2
request_slowlog_timeout = 10s
EOF

sed -Ei '/^;ping.path/s/^;//; /^;ping.response/s/^;//; /^;access.suppress_path/s/^;//' \
    /usr/local/etc/php-fpm.d/www.conf

sed -Ei '/^listen =/a listen = /run/sspanel/php-fpm.sock\nlisten.mode = 0666#' \
    /usr/local/etc/php-fpm.d/zz-docker.conf

EOT

ENV APP_VER=2023.6 DB_VER=2023102200
COPY --chown=www-data:www-data ./SSPanel-Uim /app
WORKDIR /app
RUN curl -fsSL https://github.com/SSPanel-UIM/SSPanel-UIM-Dev/pull/17.diff | patch -p1

USER www-data:www-data
RUN COMPOSER_CACHE_DIR=/tmp/composer composer update --no-dev --no-progress && rm -rf /tmp/composer
USER root

COPY --chown=www-data:www-data ./docker-entrypoint.sh ./docker-tool.php /app/
