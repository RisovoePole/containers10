# Лабораторная 10. Управление секретами в контейнерах

## Выполнил: Виктор Анисимов

## Группа: IA2403

## Дата: 04.05.2026

## Цель

Целью работы является знакомство с методами управления секретами в контейнерах.

## Задание

Создать многосервисное приложение с контейнерами, использующими секреты.

## Подготовка

- [x] install Docker

## Выполнение

За основу взял структуру проекта из [восьмой лабораторной](https://github.com/RisovoePole/containers8).

### Переход от `sqlite3` к `mysql`

Изменил конструктор класса работы с БД:

``` php
 public function __construct(string $dsn, string $username, string $password)
    {
        $this->pdo = new PDO($dsn, $username, $password);
        $this->pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    }
```

В конфиге добавил сопоставление массива `$config` с переменными среды:

``` php
$config['db']['host'] = getenv('MYSQL_HOST');
$config['db']['database'] = getenv('MYSQL_DATABASE');
$config['db']['username'] = getenv('MYSQL_USER');
$config['db']['password'] = getenv('MYSQL_PASSWORD');
```

Изменил инициализацию объекта обращения к БД:

``` php
// Инициализация доступа к БД и шаблонизатору страницы.
$dsn = "mysql:host={$config['db']['host']};dbname={$config['db']['database']};charset=utf8";

$db = new Database($dsn, $config['db']['username'], $config['db']['password']);
$page = new Page(__DIR__ . '/templates/index.tpl');
```

### Изменения `Dockerfile`

Новый `Dockerfile`:

``` dockerfile
FROM php:7.4-fpm AS base

# install pdo_mysql extension
RUN apt-get update && \
    apt-get install -y libzip-dev && \
    docker-php-ext-install pdo_mysql

# copy site files
COPY site /var/www/html
```

### Конфигурация nginx

Взята из моей 7 лабораторной.

### Защита секретов

Добавил секцию с секретами:

``` yaml
secrets:
  root_secret:
    file: ./secrets/root_secret
  user:
    file: ./secrets/user
  secret:
    file: ./secrets/secret
```

Изменил некоторые переменные с жестко заданных значений на пути к секретам:

``` yaml
#database
environment:
  MYSQL_ROOT_PASSWORD_FILE: /run/secrets/root_secret
  MYSQL_DATABASE: my_database
  MYSQL_USER_FILE: /run/secrets/user
  MYSQL_PASSWORD_FILE: /run/secrets/secret
```

``` yaml
#backend
environment:
  MYSQL_HOST: database
  MYSQL_DATABASE: my_database
```

Также изменил источник секрета в `config.php`:

``` php
// $config['db']['username'] = getenv('MYSQL_USER');
// $config['db']['password'] = getenv('MYSQL_PASSWORD');
$config['db']['username'] = file_get_contents('/run/secrets/user');
$config['db']['password'] = file_get_contents('/run/secrets/secret');
```

Примечание: функции `get_file_contents(string $path)` нету.

### Проверка через scout

Изначально в пакете *docker* у меня не было `scout`... Пришлось собрать бинарник и использовать его как дополнительный модуль для Docker. Благо [flake.nix](https://nixos.wiki/wiki/Flakes) позволяет удобно это сделать.

``` bash
docker scout quickview local://lab10-backend
    ✓ Image stored for indexing
    ✓ Indexed 242 packages

    i Base image was auto-detected. To get more accurate results, build images with max-mode provenance attestations.
      Review docs.docker.com ↗ for more information.

 Target             │  local://lab10-backend:latest  │    9C    51H    80M   185L    18?  
   digest           │  f71496b79cb0                  │                                    
 Base image         │  php:7-fpm                     │    9C    51H    80M   184L    18?  
 Updated base image │  php:8-fpm                     │    0C     4H     6M   102L     9?  
                    │                                │    -9    -47    -74    -82     -9  
```

Данная таблица показывает, сколько найдено ошибок и какого они типа: критические - C, высокие - H, средние - M, неопасные - L, неоцененные - ?. Scout не анализирует само приложение или код, а показывает уязвимости в образах и их базовых слоях.

Также видно, что в списке есть более новая версия, в которой 0 критических и заметно меньше других уязвимостей. Поэтому в данном случае лучше использовать не `php:7.4-fpm`, а `php:8.x-fpm`.

## Выводы

Научился правильно использовать встроенный механизм хранения секретов `docker secrets`.

## Ответы на вопросы

1. Почему плохо передавать секреты в образ при сборке?
    `ARG/ENV` значения видны в *docker history* и метаданных образа
    Каждый слой образа кешируется и хранится - секрет остаётся навсегда, даже если потом удалить через `RUN unset`
    Образ можно вытащить из *registry* и прочитать всё содержимое

2. Как можно безопасно управлять секретами в контейнерах?

    Секреты при сборке избегают передачи через `ARG`/`ENV`, которые остаются в слоях образа - вместо этого используют `--secret` (BuildKit) или runtime-механизмы вроде Docker Secrets, Vault или переменных окружения. Docker Secrets (Swarm) монтируют данные как временный файл в `/run/secrets/` только внутри контейнера, не сохраняя их в образе или логах.

3. Как использовать Docker Secrets для управления конфиденциальной информацией?

    Управление происходит с помощью хранения локальных файлов, где один файл отражает один ключ. Их можно использовать в `docker-compose`:

    ``` yaml
    secrets:
        root_secret:
            file: ./secrets/root_secret
    ```

    Или же передавать в параметр:

    ``` bash
        docker service create \
        --secret db_password \
        myapp
    ```
