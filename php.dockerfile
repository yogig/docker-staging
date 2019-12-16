FROM php:7.2-fpm-alpine

LABEL maintainer="y.ghorecha@xxxx.de" \
      muz.customer="xxx" \
      muz.product="WIDC" \
      container.mode="production"

#https://pkgs.alpinelinux.org/packages
RUN apk add --no-cache --virtual .deps autoconf tzdata build-base libzip-dev mysql-dev gmp-dev \
            libxml2-dev libpng-dev zlib-dev freetype-dev jpeg-dev icu-dev openldap-dev libxslt-dev &&\
    docker-php-ext-install zip xml mbstring json intl gd pdo pdo_mysql iconv soap \
                           dom gmp fileinfo sockets bcmath mysqli ldap xsl &&\
    echo 'date.timezone="Europe/Berlin"' >> "${PHP_INI_DIR}"/php.ini &&\
    cp /usr/share/zoneinfo/Europe/Berlin /etc/localtime &&\
    echo 'Europe/Berlin' > /etc/timezone &&\
    apk del .deps &&\
    apk add --no-cache libzip mysql libxml2 libpng zlib freetype jpeg icu gmp git subversion libxslt openldap \
            apache2 apache2-ldap apache2-proxy libreoffice openjdk11-jre ghostscript msttcorefonts-installer \
            terminus-font ghostscript-fonts &&\
    ln -s /usr/lib/apache2 /usr/lib/apache2/modules &&\
    ln -s /usr/sbin/httpd /etc/init.d/httpd &&\
    update-ms-fonts

# imap setup
RUN apk --update --virtual build-deps add imap-dev
RUN apk add imap
RUN docker-php-ext-install imap

# LDAP Certificate setup
RUN apk update && apk add --update openldap openssl ca-certificates && rm -rf /var/cache/apk/*
COPY backend/data/certs/LufthansaCa.crt /usr/local/share/ca-certificates/LufthansaCa.crt
RUN update-ca-certificates

# copy all codebase
COPY ./ /var/www

# SSH setup
RUN apk update && \
    apk add --no-cache \
    openssh-keygen \
    openssh

# copy Azure specific files
COPY backend/build/azure/backend/ /var/www/backend/

# User owner setup
RUN chown -R www-data:www-data /var/www/
#RUN addgroup -S -g 33 www-data \
#&& adduser -S -D -u 33 -s /sbin/nologin -h /var/www -G www-data www-data \
#&& chown -R www-data:www-data /var/www/

# Make lhcrypt executable
RUN chmod 744 /var/www/LH_Crypt/lhcrypt_linux_v2.0_static

# Work directory setup
WORKDIR /var/www

# copy apache httpd.conf file
COPY httpd.conf /etc/apache2/httpd.conf

# copy crontabs for root user
COPY backend/data/CRONTAB/production/crontab.txt /etc/crontabs/www-data

# SSH Key setup
RUN mkdir -p /home/www-data/.ssh
RUN chown -R www-data:www-data /home/www-data/

# Setting the defualt USER as www-data
USER www-data

#https://github.com/docker-library/httpd/blob/3ebff8dadf1e38dbe694ea0b8f379f6b8bcd993e/2.4/alpine/httpd-foreground
#https://github.com/docker-library/php/blob/master/7.2/alpine3.10/fpm/Dockerfile
CMD ["/bin/sh", "-c", "rm -f /usr/local/apache2/logs/httpd.pid && /usr/sbin/crond start && httpd -DBACKGROUND && php-fpm"]
