FROM ubuntu:20.04
# следующие аргументы приходят из docker-compose. они переопределяют локальные
ARG CSP_DISTR
ARG CADES_DISTR
ARG PHP_PATCH
ARG PHP_URL
ARG TEST_CA_DIR
# локальные аргументы
ARG TZ=Europe/Moscow
ARG	CSP_DIR_TMP=/tmp/csp
ARG	CADES_DIR_TMP=/tmp/cades
ARG	PHP_DIR=/opt/php
ARG	PHP_SRC=/tmp/php
ARG	PHP_PTH=/tmp/patch
ARG CSP_INCLUDE=/opt/cprocsp/include
ENV PATH="/opt/cprocsp/bin/amd64:/opt/cprocsp/sbin/amd64:${PATH}"

# установка пакетов
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
	&& apt-get update \
	&& apt-get install --no-install-recommends -y \
		lsb-base \
		wget \
		nano \
		ca-certificates \
		unzip \
		libxml2-dev \
		libboost-dev \
		php-dev \
		pkg-config \
		libsqlite3-dev \
		build-essential \
		php-pdo-pgsql \
		libpq-dev \
		openssl \
		gcc \
		g++

# Копирование исходников:
COPY $CSP_DISTR $CSP_DIR_TMP/linux-amd64_deb.tgz
COPY $CADES_DISTR $CADES_DIR_TMP/cades-linux-amd64.tar.gz
COPY $PHP_PATCH $PHP_PTH/php7_support.patch

# установка csp
RUN mkdir -p $CSP_DIR_TMP && cd $CSP_DIR_TMP && \
	tar zxvf `ls -1` --strip-components=1 && \
	chmod +x install.sh && ./install.sh && \
	dpkg -i `ls -1 | grep lsb- | grep devel` && \	
	cd && rm -rf $CSP_DIR_TMP

# установка кадеса
RUN	mkdir -p $CADES_DIR_TMP && cd $CADES_DIR_TMP && \
	tar zxvf `ls -1` --strip-components=1 && \
	dpkg -i `ls -1 |grep cades |grep .deb` && \
	dpkg -i `ls -1 |grep phpcades |grep .deb` && \
	cd && rm -rf $CADES_DIR_TMP

# установка php
RUN mkdir $PHP_SRC && cd $PHP_SRC && wget $PHP_URL && \
	tar zxvf `ls -1` --strip-components=1 && \
	./configure --prefix $PHP_DIR --enable-fpm --with-openssl --with-openssl-dir=/usr/bin --with-pdo-pgsql && \
	make && make install && update-alternatives --install /usr/local/bin/php php $PHP_DIR/bin/php 100 && \
	cp $PHP_PTH/php7_support.patch /opt/cprocsp/src/phpcades/ && \
	cd /opt/cprocsp/src/phpcades/ && patch -p0 < ./php7_support.patch && \
	sed -i 's!PHPDIR=/php!PHPDIR=${PHP_SRC}!1' Makefile.unix && \
	sed -i 's!-fPIC -DPIC!-fPIC -DPIC -fpermissive!1' Makefile.unix && \
	sed -i 's!-lrdrsup -lcplib !-lrdrsup !1' Makefile.unix && \
	eval `/opt/cprocsp/src/doxygen/CSP/../setenv.sh --64`; make -f Makefile.unix

# Конфигурация php (ВАЖНО! 2 пробела для подключения libphpcades.so в php.ini)
RUN cp $PHP_SRC/php.ini-production $PHP_DIR/lib/php.ini && \
	export EXT_DIR=`php -ini |grep extension_dir | grep -v sqlite | awk '{print $3}'` && \
	ln -s /opt/cprocsp/src/phpcades/libphpcades.so $EXT_DIR/libphpcades.so && \
	sed -i '/; Dynamic Extensions ;/a extension=libphpcades.so' /etc/php/7.4/cli/php.ini && \
	sed -i 's!;extension=pdo_mysql!extension=pdo_mysql!g' /etc/php/7.4/cli/php.ini && \
	sed -i 's!;extension=pdo_pgsql!extension=pdo_pgsql!g' /etc/php/7.4/cli/php.ini && \
	sed -i '/; Dynamic Extensions ;/a extension=libphpcades.so'  $PHP_DIR/lib/php.ini && \
	sed -i 's!;extension=pdo_mysql!extension=pdo_mysql!g' $PHP_DIR/lib/php.ini && \
	sed -i 's!;extension=pdo_pgsql!extension=pdo_pgsql!g' $PHP_DIR/lib/php.ini && \
	sed -i 's!;extension=pgsql!extension=pgsql!g' $PHP_DIR/lib/php.ini && \
	mv $PHP_DIR/etc/php-fpm.conf.default $PHP_DIR/etc/php-fpm.conf && \
	sed -i 's!;error_log = log/php-fpm.log!error_log = syslog!g' $PHP_DIR/etc/php-fpm.conf && \
	mv $PHP_DIR/etc/php-fpm.d/www.conf.default $PHP_DIR/etc/php-fpm.d/www.conf && \
	sed -i 's!listen\s*=.*!listen = 9000!1' $PHP_DIR/etc/php-fpm.d/www.conf && \
	sed -i 's!nobody!www-data!g' $PHP_DIR/etc/php-fpm.d/www.conf && \
	chown -R www-data:www-data $PHP_DIR/var/log && \
	ln -s $PHP_DIR/sbin/php-fpm /usr/sbin/php-fpm && \
	rm -rf /tmp/*

# Настройка сертификата
COPY certificates /var/opt/cprocsp/keys/www-data/
RUN chown -R www-data:www-data /var/opt/cprocsp/keys/www-data/
USER www-data
RUN csptestf -absorb -certs
USER root
ADD $TEST_CA_DIR /root/test-ca-root.crt
RUN certmgr -inst -store mroot -file /root/test-ca-root.crt

# Открытие порта
EXPOSE 9000

# Запуск php-fpm
CMD ["php-fpm","-F"]
