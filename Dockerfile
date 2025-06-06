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
    pcntl


FROM base AS local

WORKDIR /var/www/html

RUN apt-get install -y\
    git \
    unzip \
    $PHPIZE_DEPS \
    && pecl install xdebug-3.4.3 \
    && docker-php-ext-enable xdebug

ENV PHP_IDE_CONFIG 'serverName=${SERVER_NAME}'
COPY --chown=appuser:appuser . .
COPY --from=composer /usr/bin/composer /usr/bin/composer

USER appuser


FROM base AS production

WORKDIR /var/www/html

RUN rm -rf /tmp/* /var/tmp/* && \
    rm -rf /var/www/html/storage/framework/cache/*

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

RUN php artisan migrate --force
RUN php artisan optimize:clear && \
    php artisan view:cache && \
    php artisan event:cache

USER appuser

CMD ["sh", "-c", "php artisan optimize && php-fpm"]
