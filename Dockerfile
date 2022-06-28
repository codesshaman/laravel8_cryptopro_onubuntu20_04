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
		openssl \
		gcc \
		g++

# Подключение библиотек docker-php-ext-install
COPY --from=php:7.4-fpm /usr/local/bin/docker-php-ext-install /usr/local/bin/docker-php-ext-install
COPY --from=php:7.4-fpm /usr/local/bin/docker-php-source /usr/local/bin/docker-php-source
COPY --from=php:7.4-fpm /usr/local/bin/docker-php-ext-enable /usr/local/bin/docker-php-ext-enable
COPY --from=php:7.4-fpm /usr/local/bin/docker-php-ext-configure /usr/local/bin/docker-php-ext-configure
COPY --from=php:7.4-fpm /usr/local/bin/phpize /usr/local/bin/phpize
COPY --from=php:7.4-fpm /usr/src/php.tar.xz /usr/src/php.tar.xz

# Копирование исходников:
COPY $CSP_DISTR $CSP_DIR_TMP/linux-amd64_deb.tgz
COPY $CADES_DISTR $CADES_DIR_TMP/cades-linux-amd64.tar.gz
COPY $PHP_PATCH $PHP_PTH/php7_support.patch

# установка csp
RUN mkdir -p $CSP_DIR_TMP && cd $CSP_DIR_TMP && \
	# wget $CSP_DISTR && \
	tar zxvf `ls -1` --strip-components=1 && \
	chmod +x install.sh && ./install.sh && \
	dpkg -i `ls -1 | grep lsb- | grep devel` && \	
	cd && rm -rf $CSP_DIR_TMP

# установка кадеса
RUN	mkdir -p $CADES_DIR_TMP && cd $CADES_DIR_TMP && \
	# wget $CADES_DISTR && \
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

RUN apt install -y php-pdo-pgsql

# Конфигурация php
RUN cp $PHP_SRC/php.ini-production $PHP_DIR/lib/php.ini && \
	export EXT_DIR=`php -ini |grep extension_dir | grep -v sqlite | awk '{print $3}'` && \
	ln -s /opt/cprocsp/src/phpcades/libphpcades.so $EXT_DIR/libphpcades.so && \
	sed -i '/; Dynamic Extensions ;/a extension=libphpcades.so' $PHP_DIR/lib/php.ini && \
	mv $PHP_DIR/etc/php-fpm.conf.default $PHP_DIR/etc/php-fpm.conf && \
	sed -i 's!;error_log = log/php-fpm.log!error_log = syslog!g' $PHP_DIR/etc/php-fpm.conf && \
	mv $PHP_DIR/etc/php-fpm.d/www.conf.default $PHP_DIR/etc/php-fpm.d/www.conf && \
	sed -i 's!listen\s*=.*!listen = 9000!1' $PHP_DIR/etc/php-fpm.d/www.conf && \
	sed -i 's!nobody!www-data!g' $PHP_DIR/etc/php-fpm.d/www.conf && \
	chown -R www-data:www-data $PHP_DIR/var/log && \
	ln -s $PHP_DIR/sbin/php-fpm /usr/sbin/php-fpm && \
	rm -rf /tmp/*

COPY certificates /var/opt/cprocsp/keys/www-data/
RUN chown -R www-data:www-data /var/opt/cprocsp/keys/www-data/
USER www-data
RUN csptestf -absorb -certs

USER root
ADD $TEST_CA_DIR /root/test-ca-root.crt
RUN certmgr -inst -store mroot -file /root/test-ca-root.crt

EXPOSE 9000

CMD ["php-fpm","-F"]




	# sed -i 's!;extension=openssl!extension=openssl!g' $PHP_DIR/lib/php.ini && \
	# sed -i 's!;extension_dir = "./"!extension_dir = "./""!g' $PHP_DIR/lib/php.ini && \
	# echo "extension_dir = $EXT_DIR" >> $PHP_DIR/lib/php.ini && \
	# sed -i 's!;extension=pdo_pgsql!extension=pdo_pgsql!g' $PHP_DIR/lib/php.ini && \
	# sed -i 's!;extension=pgsql!extension=pgsql!g' $PHP_DIR/lib/php.ini && \



# ./usr/bin/openssl
# ./usr/include/openssl
# ./usr/include/x86_64-linux-gnu/openssl
# ./usr/share/doc/openssl
# ./usr/share/lintian/overrides/openssl






# USER www-data
# RUN apt-get install -y php-fpm 																	&& \
# 	sed -i 's!www-data!root!g' `find /etc/ -name www.conf`										&& \
# 	sed -i 's!listen\s*=.*!listen = 9000!1' `find /etc/ -name www.conf`							&& \
# 	mkdir -p /run/php
# sed -i 's!www-data!root!g' $PHP_DIR/etc/php-fpm.conf										&& \
# addgroup -g 82 -S www-data && useradd -u 82 -D -S -G www-data www-data						&& \
