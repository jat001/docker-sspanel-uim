# docker-sspanel-uim [![wakatime](https://wakatime.com/badge/github/jat001/docker-sspanel-uim.svg)](https://wakatime.com/@Jat/projects/yieaswmqse)

SSPanel UIM in Docker container

## Usage

Copy `config` folder from image to host

```bash
docker run -it --name=sspanel-tmp --rm --entrypoint=bash jat001/sspanel-uim:latest
docker cp sspanel-tmp:/app/config ./config
```

Create `.env` file and edit it

```text
MARIADB_ROOT_PASSWORD=MyRootPassword
REDIS_DEFAULT_PASSWORD=MyDefaultPassword
SSPANEL_ADMIN_EMAIL=sspanel@example.com
SSPANEL_ADMIN_PASSWORD=MySSPanelPassword
```

Copy `.config.example.php` to `.config.php`, `appprofile.example.php` to `appprofile.php` and edit them

```bash
cp config/.config.example.php config/.config.php
cp config/appprofile.example.php config/appprofile.php
```

Some example configs of `.config.php`

```php
$_ENV['db_driver']    = 'mysql';
$_ENV['db_host']      = '';
$_ENV['db_socket']    = '/run/sspanel/mysqld.sock';
$_ENV['db_database']  = 'sspanel';
$_ENV['db_username']  = 'sspanel';
$_ENV['db_password']  = 'sspanel';
$_ENV['db_port']      = '3306';

$_ENV['redis_host']            = '/run/sspanel/redis.sock';
$_ENV['redis_port']            = -1;
$_ENV['redis_connect_timeout'] = 2.0;
$_ENV['redis_read_timeout']    = 8.0;
$_ENV['redis_username']        = 'sspanel';
$_ENV['redis_password']        = 'sspanel';
$_ENV['redis_ssl']             = false;
$_ENV['redis_ssl_context']     = [];
```

You don't need to create mariadb database and mariadb/redis user, the entrypoint script will do it for you.

You can also run mariadb and redis on another host, just change `db_host`, `db_port`, `redis_host`, `redis_port` to the correct value.

`web` (nginx), `app` (sspanel) and `cron` (crontab) must run on the same host, `db` (mariadb) and `cache` (redis) can run on another host.
