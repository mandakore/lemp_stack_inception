FROM alpine:3.23

RUN apk add --no-cache nginx openssl

RUN mkdir -p /etc/nginx/ssl \
	&& openssl req -x509 -nodes -days 365 \
	-newkey rsa:2048 \
	-keyout /etc/nginx/ssl/inception.key \
	-out /etc/nginx/ssl/inception.crt \
	-subj "/C=JP/ST=Tokyo/L=Tokyo/O=42Tokyo/CN=atashiro.42.fr"

RUN rm -f /etc/nginx/http.d/default.conf

COPY conf/nginx.conf /etc/nginx/http.d/inception.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]