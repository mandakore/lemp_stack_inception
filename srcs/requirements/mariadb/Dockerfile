FROM alpine:3.23

RUN apk add --no-cache \
	mariadb \
	mariadb-client \
	bash

COPY conf/50-server.cnf /etc/my.cnf.d/50-server.cnf


COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/init.sh"]