FROM alpine:3.23

RUN apk add --no-cache \

	php83 \
	php83-fpm \
	php83-mysqli \
	php83-phar \
	php83-openssl \
	php83-curl \
	php83-mbstring \
	php83-xml \
	php83-simplexml \
	php83-dom \
	php83-zip \
	php83-exif \
	php83-gd \
	php83-json \
	php83-session \

	bash \

	curl \

	mariadb-client \

	&& ln -s /usr/bin/php83 /usr/bin/php

RUN sed -i 's|^listen = .*|listen = 9000|' /etc/php83/php-fpm.d/www.conf \

	&& sed -i 's|^memory_limit = .*|memory_limit = 256M|' /etc/php83/php.ini \

	&& mkdir -p /run/php

RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \

	&& chmod +x /usr/local/bin/wp

COPY tools/setup.sh /usr/local/bin/setup.sh

RUN chmod +x /usr/local/bin/setup.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/setup.sh"]