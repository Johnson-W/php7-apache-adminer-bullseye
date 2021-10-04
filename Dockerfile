FROM php:7.4.23-apache-bullseye

MAINTAINER Johnson

COPY files/adminer-4.8.1.php /opt
COPY files/plugins.tar.gz /opt
COPY files/pematon-adminer-theme.tar.gz /opt
COPY files/php.ini-production.ini /opt
COPY files/adminer-with-plugins.php /opt
COPY files/p.php /opt
COPY files/instantclient-basiclite-linux.x64-19.12.0.0.0dbru.zip /opt
COPY files/instantclient-sdk-linux.x64-19.12.0.0.0dbru.zip /opt

RUN rm /etc/localtime \
    && ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && apt-get update \
    && apt-get install -y unzip libssl-dev freetds-dev libpq-dev unixodbc-dev libaio1 \
    && apt-get clean autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/

RUN ln -s /usr/lib/x86_64-linux-gnu/libsybdb.so /usr/lib/ 

# Install pdo_dblib mysqli pdo_mysql pgsql pdo_pgsql pdo_odbc
RUN docker-php-ext-configure pdo_odbc --with-pdo-odbc=unixODBC,/usr \
    && docker-php-ext-install -j$(nproc) \
    pdo_dblib \
    mysqli pdo_mysql \
    pgsql pdo_pgsql \
    pdo_odbc

# Install mongodb
RUN pecl install mongodb \
    && docker-php-ext-enable mongodb

# Install oci8 pdo_oci
RUN mkdir -p /opt/oracle/instantclient_19_12 \
    && unzip -q /opt/instantclient-basiclite-linux.x64-19.12.0.0.0dbru.zip -d /opt/oracle \
    && unzip -q /opt/instantclient-sdk-linux.x64-19.12.0.0.0dbru.zip -d /opt/oracle \
    && echo "/opt/oracle/instantclient_19_12" > /etc/ld.so.conf.d/oracle.conf \
    && ldconfig \
    && docker-php-ext-configure oci8 --with-oci8=instantclient,/opt/oracle/instantclient_19_12 \
    && docker-php-ext-configure pdo_oci --with-pdo-oci=instantclient,/opt/oracle/instantclient_19_12 \
    && docker-php-ext-install oci8 pdo_oci

RUN cd /var/log/ \
    && >alternatives.log;>apt/eipp.log.xz;>apt/history.log;>apt/term.log;>dpkg.log;>faillog;>lastlog

WORKDIR /var/www/html

# Install Adminer
RUN cp /opt/adminer-4.8.1.php adminer.php \
    # Install plugins (defined in adminer-with-plugins.php)
    && tar zxf /opt/plugins.tar.gz -C /var/www/html \
    # Install style
    && tar zxf /opt/pematon-adminer-theme.tar.gz -C /var/www/html \
    # Install index
    && cp /opt/adminer-with-plugins.php /var/www/html/index.php \
    && cp /opt/p.php p.php

RUN  sed -i 's/\*\:80>/*:5908>/' /etc/apache2/sites-enabled/000-default.conf \
    && sed -i 's/Listen 80/Listen 5908/' /etc/apache2/ports.conf \
    && cp /opt/php.ini-production.ini $PHP_INI_DIR/php.ini \
    && rm -r /opt/*.zip /opt/*.php /opt/*.tar.gz /opt/php.ini-production.ini

EXPOSE 5908

