<?php

declare(strict_types=1);

require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/config/.config.php';

function fail(string $message): void
{
    fwrite(STDERR, "\033[31m$message\033[0m" . PHP_EOL);
    exit(1);
}

class Tool
{
    private string $db_driver;
    private string $db_socket;
    private string $db_host;
    private string $db_port;

    private string $db_charset;
    private string $db_collation;

    private string $db_dsn;

    private string $db_root_username;
    private string $db_root_password;

    private string $db_name;
    private string $db_username;
    private string $db_password;

    private string $redis_host;
    private int $redis_port;

    private float $redis_connect_timeout;
    private float $redis_read_timeout;
    private bool $redis_ssl;
    private array $redis_ssl_context;

    private string $redis_default_username;
    private string $redis_default_password;

    private string $redis_username;
    private string $redis_password;

    private array $redis_connect_options;
    private Redis $redis;

    private string $maxmind_license_key;

    public function __construct()
    {
        $this->db_driver = $_ENV['db_driver'];
        $this->db_socket = $_ENV['db_socket'];
        $this->db_host = $_ENV['db_host'];
        $this->db_port = $_ENV['db_port'];

        $this->db_charset = $_ENV['db_charset'];
        $this->db_collation = $_ENV['db_collation'];

        $this->db_dsn = $this->db_socket ? "unix_socket=$this->db_socket" : "host=$this->db_host;port=$this->db_port";
        $this->db_dsn = "$this->db_driver:$this->db_dsn;charset=$this->db_charset";

        $this->db_root_username = 'root';
        $this->db_root_password = getenv('MARIADB_ROOT_PASSWORD');

        $this->db_name = $_ENV['db_prefix'] . $_ENV['db_database'];
        $this->db_username = $_ENV['db_username'];
        $this->db_password = $_ENV['db_password'];

        $this->redis_host = $_ENV['redis_host'];
        $this->redis_port = $_ENV['redis_port'];

        $this->redis_connect_timeout = $_ENV['redis_connect_timeout'];
        $this->redis_read_timeout = $_ENV['redis_read_timeout'];

        $this->redis_ssl = $_ENV['redis_ssl'];
        $this->redis_ssl_context = $_ENV['redis_ssl_context'];

        $this->redis_default_username = 'default';
        $this->redis_default_password = getenv('REDIS_DEFAULT_PASSWORD');

        $this->redis_username = $_ENV['redis_username'] === '' ? $this->redis_default_username : $_ENV['redis_username'];
        $this->redis_password = $_ENV['redis_password'] === '' ? 'nopass' : '>' . $_ENV['redis_password'];

        $this->redis_connect_options = [
            'host' => $this->redis_host,
            'port' => $this->redis_port,
            'connectTimeout' => $this->redis_connect_timeout,
            'readTimeout' => $this->redis_read_timeout,
            'auth' => [
                'user' => $this->redis_default_username,
                'pass' => $this->redis_default_password,
            ],
        ];
        if ($this->redis_ssl === true) {
            $this->redis_connect_options['ssl'] = $this->redis_ssl_context;
        }
        $this->redis = new Redis($this->redis_connect_options);

        $this->maxmind_license_key = $_ENV['maxmind_license_key'];
    }

    public function __call(string $name, array $arguments)
    {
        fail("Unknown command: $name");
    }

    public function tables_exist(): void
    {
        try {
            $pdo = new PDO("$this->db_dsn;dbname=$this->db_name", $this->db_root_username, $this->db_root_password);
        } catch (PDOException $e) {
            echo 'Database does not exist' . PHP_EOL;
            exit(1);
        }

        $query = $pdo->query('SHOW TABLES');
        $result = $query->fetchAll();
        $count = count($result);

        if ($count > 0) {
            echo "Database exists and has $count tables" . PHP_EOL;
            exit(0);
        } else {
            echo 'Database exists but no table exists' . PHP_EOL;
            exit(1);
        }
    }

    public function create_database(): void
    {
        $pdo = new PDO($this->db_dsn, $this->db_root_username, $this->db_root_password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_SILENT,
        ]);

        $sql = "CREATE DATABASE IF NOT EXISTS `$this->db_name` CHARACTER SET $this->db_charset COLLATE $this->db_collation;
                CREATE USER IF NOT EXISTS '$this->db_username'@'localhost' IDENTIFIED BY '$this->db_password';
                GRANT ALL ON `$this->db_name`.* TO '$this->db_username'@'localhost';
                FLUSH PRIVILEGES;";

        $result = $pdo->exec($sql);

        if ($result === false) {
            fail($pdo->errorInfo()[2]);
        }
    }

    public function user_exists(): void
    {
        $result = $this->redis->acl('GETUSER', $this->redis_username);

        if ($result === false) {
            echo 'User not exists' . PHP_EOL;
            exit(1);
        } else {
            echo 'User exists' . PHP_EOL;
            exit(0);
        }
    }

    public function create_acl(): void
    {
        $result = $this->redis->acl(
            'SETUSER',
            $this->redis_username,
            'on',
            $this->redis_username === $this->redis_default_username ? ">$this->redis_default_password" : '',
            "$this->redis_password",
            '~*',
            '&*',
            '+@all',
            $this->redis_username === $this->redis_default_username ? '' : '-@dangerous',
        );

        if ($result !== true) {
            fail($this->redis->getLastError());
        }
    }

    public function download_mmdb(): void
    {
        if ($this->maxmind_license_key === '') {
            fail('Please set maxmind license key in .config.php');
        }

        $client = new tronovav\GeoIP2Update\Client([
            'license_key' => $this->maxmind_license_key,
            'dir' => __DIR__ . '/storage/',
            'editions' => ['GeoLite2-City', 'GeoLite2-Country'],
        ]);

        try {
            $client->run();
        } catch (Exception $e) {
            fail($e->getMessage());
        }
    }
}

if (count($argv) < 2) {
    fail("Usage: php docker-tool.php [command]");
}

$tool = new Tool();
$tool->{$argv[1]}();
