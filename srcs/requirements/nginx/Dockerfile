FROM debian:bookworm
RUN apt-get update && apt-get install -y nginx openssl
RUN mkdir -p /etc/nginx/ssl && openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/inception.key -out /etc/nginx/ssl/inception.crt -subj "/CN=jisobaek.42.fr"
RUN rm /etc/nginx/sites-enabled/default /var/www/html/index.nginx-debian.html
COPY conf/nginx.conf /etc/nginx/conf.d/inception.conf
ENTRYPOINT ["nginx", "-g", "daemon off;"]
