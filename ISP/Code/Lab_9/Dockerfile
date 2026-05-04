FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y nginx libnginx-mod-http-dav-ext apache2-utils && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/nginx/sites-enabled/default && \
    mkdir -p /var/webdav/.tmp

CMD ["sh", "-c", "chown -R www-data:www-data /var/webdav && nginx -g 'daemon off;'"]
