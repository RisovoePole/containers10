FROM php:7.4-fpm as base

# Устанавливаем sqlite-клиент и расширение PDO для работы приложения с SQLite.
RUN apt-get update && \
    apt-get install -y libzip-dev && \
    docker-php-ext-install pdo_mysql

COPY site /var/www/html