ARG PHP_VERSION
FROM php:${PHP_VERSION}-alpine

RUN apk add mariadb-client procps git jq --no-cache

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions gd bcmath zip intl xsl pdo_mysql soap sockets ftp @composer

ENV COMPOSER_ALLOW_SUPERUSER 1

RUN echo "memory_limit = -1" > $PHP_INI_DIR/conf.d/php-memory-limits.ini
RUN echo "max_execution_time = 120" >> $PHP_INI_DIR/conf.d/php-memory-limits.ini

COPY pipe.sh /

ENTRYPOINT ["/pipe.sh"]
