ARG PHP_VER=7.4.12

# Install php dependencies
FROM composer:2.0 AS php-dependencies

COPY composer.lock composer.json ./
RUN composer install --ignore-platform-reqs


# Compilation stage, build required php extensions
FROM php:$PHP_VER-cli AS builder
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get -y install \
      libfreetype6-dev \
      libjpeg62-turbo-dev \
      libpng-dev \
      libgmp-dev \
      libzip-dev \
      libxml2-dev

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd \
        iconv \
        bcmath \
        zip \
        pdo_mysql \
        soap \
        sockets \
        opcache \
        intl \
        gmp \
        pcntl \
    && pecl install \
        apcu \
        redis \
        ds \
        igbinary


# Shared packages for production and development stages
FROM php:$PHP_VER-cli AS cli-base

ENV DEBIAN_FRONTEND noninteractive
WORKDIR /application

# Enable built php extensions and install lib's dependencies
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
RUN apt-get update \
    && apt-get -y install \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libxml2-dev \
        libzip-dev \
        locales \
        gettext-base \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-enable \
        apcu \
        redis \
        opcache \
        bcmath \
        intl \
        zip \
        soap \
        gd \
        pdo_mysql \
        sockets \
        gmp \
        pcntl \
        ds \
        igbinary

# Generate german locales, install debugging tools and download required CA cert
RUN apt-get update \
    && apt-get -y install locales gettext-base \
        # Tools for debugging inside container
        neovim nano iputils-ping \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && echo "de_DE.UTF-8 UTF-8" > /etc/locale.gen \
    && dpkg-reconfigure -f noninteractive locales \
    # Download GeoTrust Root CA that is used for signing APNS TLS cert
    # It isn't included anymore in ca-certificates (https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=962596)
    && curl --output /usr/local/share/ca-certificates/GeoTrust_Global_CA.crt https://www.geotrust.com/resources/root_certificates/certificates/GeoTrust_Global_CA.pem \
    && update-ca-certificates

# Copy php config files
# Cron and queues need an extensive memory limit
COPY dockerfiles/php/ini/no-memory-limit.ini \
    dockerfiles/php/ini/sessions.ini \
    dockerfiles/php/ini/opcache.ini \
    dockerfiles/php/ini/apcu.ini \
    dockerfiles/php/ini/error-reporting.prod.ini \
    dockerfiles/php/ini/timezone.ini \
    dockerfiles/php/ini/upload.ini \
    /usr/local/etc/php/conf.d/


# Queues base stage
FROM cli-base AS queues-base

# Configure entrypoint script
COPY dockerfiles/php/docker-entrypoint.queues.sh /docker-entrypoint.sh
RUN apt-get update && apt-get -y install netcat \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]


# Queues production stage
FROM queues-base AS queues-production

# Copy built dependencies and src
COPY --chown=33:33 . .
COPY --from=php-dependencies --chown=33:33 /app/vendor ./vendor


# Alias name
FROM queues-production AS queues


# Including debugging tools for development
FROM queues-base AS queues-development

RUN pecl install xdebug && \
  docker-php-ext-enable xdebug
COPY dockerfiles/php/ini/xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini
COPY dockerfiles/php/ini/error-reporting.dev.ini /usr/local/etc/php/conf.d/99-error-reporting.dev.ini


# Build debugging tools for optimized for docker-for-mac
FROM php:$PHP_VER-cli AS development-for-mac-builder

# Use clock-patched (but outdated) version of xdebug
WORKDIR /root
RUN apt-get update && apt-get install -y git \
  && apt-get clean && rm -rf /var/lib/apt/lists/* \
  && git clone https://github.com/jimbojsb/xdebug.git \
  && cd xdebug && phpize && ./configure && make


# Install built debugging tools optimized for docker-for-mac
FROM queues-base AS queues-development-for-mac

# Extension dir is placed at RUN php -r 'echo ini_get("extension_dir");'
# This folder differs between php versions, but docker-php-ext-enable will fail
# if it has changed
COPY --from=development-for-mac-builder /root/xdebug/modules/xdebug.so /usr/local/lib/php/extensions/no-debug-non-zts-20190902/
RUN docker-php-ext-enable xdebug
COPY dockerfiles/php/ini/xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini
COPY dockerfiles/php/ini/error-reporting.dev.ini /usr/local/etc/php/conf.d/99-error-reporting.dev.ini


# Cron base stage
FROM cli-base AS cron-base

# Configure cronjob
RUN apt-get update && apt-get -y install cron \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY dockerfiles/php/crontab /tmp/crontab
CMD ["cron", "-f"]

# Configure entrypoint script
COPY dockerfiles/php/docker-entrypoint.cron.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]


# Cron production stage
FROM cron-base AS cron-production

# Copy built dependencies and src
COPY --chown=33:33 . .
COPY --from=php-dependencies --chown=33:33 /app/vendor ./vendor


# Alias name
FROM cron-production AS cron


# Debugging tools for development
FROM cron-base AS cron-development

RUN pecl install xdebug && \
  docker-php-ext-enable xdebug
COPY dockerfiles/php/ini/xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini
COPY dockerfiles/php/ini/error-reporting.dev.ini /usr/local/etc/php/conf.d/99-error-reporting.dev.ini


# Install built debugging tools optimized for docker-for-mac
FROM cron-base AS cron-development-for-mac

# Extension dir is placed at RUN php -r 'echo ini_get("extension_dir");'
# This folder differs between php versions, but docker-php-ext-enable will fail
# if it has changed
COPY --from=development-for-mac-builder /root/xdebug/modules/xdebug.so /usr/local/lib/php/extensions/no-debug-non-zts-20190902/
RUN docker-php-ext-enable xdebug
COPY dockerfiles/php/ini/xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini
COPY dockerfiles/php/ini/error-reporting.dev.ini /usr/local/etc/php/conf.d/99-error-reporting.dev.ini


# Shared packages for production and development stages
FROM php:$PHP_VER-fpm AS fpm-base

ENV DEBIAN_FRONTEND noninteractive
WORKDIR /application

COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
RUN apt-get clean && apt-get update \
  && apt-get -y install \
      libfreetype6-dev \
      libjpeg62-turbo-dev \
      libpng-dev \
      libxml2-dev \
      libzip-dev \
      locales \
      gettext-base \
  && docker-php-ext-enable \
      apcu \
      redis \
      opcache \
      bcmath \
      intl \
      zip \
      soap \
      gd \
      pdo_mysql \
      sockets \
      gmp \
      pcntl \
      ds \
      igbinary

# Generate german locales, install debugging tools and download required CA cert
RUN apt-get update \
    && apt-get -y install locales gettext-base \
        # Tools for debugging inside container
        neovim nano iputils-ping \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && echo "de_DE.UTF-8 UTF-8" > /etc/locale.gen \
    # Download GeoTrust Root CA that is used for signing APNS TLS cert
    # It isn't included anymore in ca-certificates (https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=962596)
    && curl --output /usr/local/share/ca-certificates/GeoTrust_Global_CA.crt https://www.geotrust.com/resources/root_certificates/certificates/GeoTrust_Global_CA.pem \
    && update-ca-certificates

# Copy php config files
COPY dockerfiles/php/www.template /usr/local/etc/php-fpm.d/zz-www.template
COPY dockerfiles/php/ini/memory-limit.ini \
    dockerfiles/php/ini/sessions.ini \
    dockerfiles/php/ini/opcache.ini \
    dockerfiles/php/ini/apcu.ini \
    dockerfiles/php/ini/error-reporting.prod.ini \
    dockerfiles/php/ini/timezone.ini \
    dockerfiles/php/ini/upload.ini \
    /usr/local/etc/php/conf.d/

# Configure entrypoint
COPY dockerfiles/php/docker-entrypoint.fpm.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["php-fpm", "-F"]


# FPM production stage
FROM fpm-base AS fpm-production

# Copy built dependencies and src
COPY --chown=33:33 . .
COPY --from=php-dependencies --chown=33:33 /app/vendor ./vendor


# Alias name
FROM fpm-production AS fpm


# Debugging tools for development
FROM fpm-base AS fpm-development

RUN pecl install xdebug \
  && docker-php-ext-enable xdebug
COPY dockerfiles/php/ini/xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini
COPY dockerfiles/php/ini/error-reporting.dev.ini /usr/local/etc/php/conf.d/99-error-reporting.dev.ini


# Install built debugging tools optimized for docker-for-mac
FROM fpm-base AS fpm-development-for-mac

# Extension dir is placed at RUN php -r 'echo ini_get("extension_dir");'
# This folder differs between php versions, but docker-php-ext-enable will fail
# if it has changed
COPY --from=development-for-mac-builder /root/xdebug/modules/xdebug.so /usr/local/lib/php/extensions/no-debug-non-zts-20190902/
RUN docker-php-ext-enable xdebug
COPY dockerfiles/php/ini/xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini
COPY dockerfiles/php/ini/error-reporting.dev.ini /usr/local/etc/php/conf.d/99-error-reporting.dev.ini
