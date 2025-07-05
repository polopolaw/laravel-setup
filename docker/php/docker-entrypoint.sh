#!/bin/sh
set -e

cd /var/www/html

# Проверяем, есть ли vendor и нужно ли ставить зависимости
if [ ! -d "vendor" ]; then
  composer install --no-interaction --prefer-dist
fi

# Генерируем ключ, если его нет
if [ ! -f ".env" ] || ! grep -q '^APP_KEY=.' .env; then
  [ -f .env ] || cp .env.example .env
  php artisan key:generate
fi

if [ ! -f "database/database.sqlite" ]; then
touch database/database.sqlite
chmod 666 database/database.sqlite
php artisan migrate
php artisan db:seed
fi

# Передаем управление основному процессу
exec "$@"
