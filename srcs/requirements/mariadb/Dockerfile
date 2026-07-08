FROM alpine:3.23

RUN apk add --no-cache \
	mariadb \
	mariadb-client \
	bash

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/init.sh"]