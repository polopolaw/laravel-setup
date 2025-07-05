FROM composer:2 AS composer

FROM php:8.4-fpm AS base

ENV TZ=Europe/Moscow

ARG UID=5000
ARG GID=5000

RUN groupadd -g $GID appuser && \
    useradd -u $UID -g appuser -d /home/appuser -s /usr/sbin/nologin appuser

WORKDIR /var/www/html

RUN mkdir -p storage/framework/{sessions,views,cache} && \
    chown -R appuser:appuser storage && \
    chmod -R 775 storage

RUN apt-get update && apt-get install -y \
    gnupg \
    wget \
    lsb-release \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y \
    git \
    unzip \
    curl \
    libpq-dev \
    libicu-dev \
    libzip-dev \
    libonig-dev \
    libfreetype6-dev \
    libjpeg-dev \
    libpng-dev \
    zlib1g-dev \
    postgresql-client-17 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    pdo \
    pdo_pgsql \
    mbstring \
    intl \
    zip \
    exif \
    sockets \
    opcache \
    pcntl \
    php-redis

RUN docker-php-ext-enable pdo_pgsql

FROM base AS local

WORKDIR /var/www/html

RUN apt-get install -y \
    && pecl install xdebug-3.4.3 \
    && docker-php-ext-enable xdebug

COPY --chown=appuser:appuser . .
COPY --from=composer /usr/bin/composer /usr/bin/composer
RUN touch /var/log/xdebug.log && chown appuser:appuser /var/log/xdebug.log && chmod 664 /var/log/xdebug.log
USER appuser
ENTRYPOINT ["sh", "/var/www/html/docker/php/docker-entrypoint.sh"]

FROM base AS production

WORKDIR /var/www/html

RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.enable_cli=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.interned_strings_buffer=16" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=20000" >> /usr/local/etc/php/conf.d/opcache.ini

COPY --from=composer /app/vendor ./vendor
COPY --chown=appuser:appuser . .
COPY --from=composer /usr/bin/composer /usr/bin/composer

RUN composer install \
    --ignore-platform-reqs \
    --no-interaction \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader \
    --no-dev

RUN composer run-script post-install-cmd

RUN php artisan optimize:clear && \
    php artisan optimize

USER appuser

CMD ["sh", "-c", "php-fpm"]
