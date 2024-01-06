# https://github.com/docker-library/docs/blob/master/php/README.md
FROM php:fpm

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y libyaml-dev libzip-dev && \
    rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install bcmath mysqli pdo_mysql zip && \
    yes '' | pecl install redis && \
    yes '' | pecl install yaml && \
    docker-php-ext-enable opcache redis yaml

COPY --from=composer /usr/bin/composer /usr/bin/composer

RUN sed -Ei \
's#^listen = .+#\
listen = /run/sspanel/php-fpm.sock\n\
listen.mode = 0666#' \
/usr/local/etc/php-fpm.d/zz-docker.conf

# https://wiki.sspanel.org/#/install-using-ubuntu?id=提高系统安全性与性能
RUN echo '\n\
disable_functions = \
passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,\
ini_alter,ini_restore,dl,readlink,symlink,popepassthru,stream_socket_server,fsocket,popen' \
>> /usr/local/etc/php/conf.d/docker-fpm.ini

RUN echo '\n\
opcache.file_cache = /tmp/sspanel/opcache\n\
opcache.interned_strings_buffer = 64\n\
opcache.jit_buffer_size = 256M\n\
opcache.max_accelerated_files = 65535\n\
opcache.memory_consumption = 512\n\
opcache.revalidate_freq = 60\n\
opcache.validate_permission = 1\n\
opcache.validate_root = 1' \
>> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

ENV APP_VER=2023.6 DB_VER=2023102200
COPY --chown=www-data:www-data ./SSPanel-Uim /app
WORKDIR /app
RUN curl -fsSL https://github.com/SSPanel-UIM/SSPanel-UIM-Dev/pull/17.diff | patch -p1

USER www-data:www-data
RUN COMPOSER_CACHE_DIR=/tmp/composer composer update --no-dev && rm -rf /tmp/composer
USER root

COPY --chown=www-data:www-data ./docker-entrypoint.sh ./docker-tool.php /app/
