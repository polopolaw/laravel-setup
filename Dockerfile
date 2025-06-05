FROM composer:2 AS composer

WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install \
    --ignore-platform-reqs \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader

FROM php:8.4-fpm-alpine AS base

ARG UID=5000
ARG GID=5000

RUN addgroup -g $GID appuser && \
    adduser -u $UID -G appuser -D -H -s /bin/false appuser

WORKDIR /var/www/html

RUN mkdir -p storage/framework/{sessions,views,cache} && \
    chown -R appuser:appuser storage && \
    chmod -R 775 storage

RUN apk add --no-cache \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    linux-headers


RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
    zip \
    gd \
    pdo_mysql


FROM base AS local

WORKDIR /var/www/html

RUN apk add --no-cache \
    git \
    unzip \
    $PHPIZE_DEPS \
    && pecl install xdebug-3.4.3 \
    && docker-php-ext-enable xdebug

ENV PHP_IDE_CONFIG 'serverName=${SERVER_NAME}'
COPY --from=composer /app/vendor ./vendor
COPY --chown=appuser:appuser . .

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

RUN php artisan optimize:clear && \
    php artisan optimize && \
    php artisan view:cache && \
    php artisan event:cache

USER appuser

# Удаляем development-зависимости в production
RUN if [ "$APP_ENV" = "production" ]; then \
      apk del $PHPIZE_DEPS git unzip; \
      rm -rf /var/cache/apk/* /tmp/* /var/tmp/*; \
    fi

CMD ["sh", "-c", "php artisan optimize && php-fpm"]
