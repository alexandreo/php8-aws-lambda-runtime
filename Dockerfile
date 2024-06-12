FROM public.ecr.aws/lambda/provided:al2 as builder

ARG php_version="8.3.0"

RUN yum clean all && \
    yum install -y autoconf \
                bison \
                bzip2-devel \
                gcc \
                gcc-c++ \
                git \
                gzip \
                libcurl-devel \
                libxml2-devel \
                make \
                openssl-devel \
                tar \
                unzip \
                zip \
                re2c \
                sqlite-devel \
                oniguruma-devel \
                libtool \
                nasm

RUN curl -sL https://github.com/php/php-src/archive/php-${php_version}.tar.gz | tar -xvz && \
    cd php-src-php-${php_version} && \
    ./buildconf --force && \
    ./configure --prefix=/var/lang/ --with-openssl --with-curl --with-zlib --with-pear --enable-bcmath --enable-sockets --with-bz2 --enable-mbstring --with-pdo-mysql --with-mysqli && \
    make -j 12 && \
    make install && \
    /var/lang/bin/php -v && \
    curl -sS https://getcomposer.org/installer | /var/lang/bin/php -- --install-dir=/var/lang/bin/ --filename=composer

COPY php.ini /var/lang/lib/php.ini

# Install MongoDB extension
RUN pecl install mongodb && \
    echo "extension=mongodb.so" > /var/lang/lib/php.ini

RUN mkdir /lambda-php-vendor && \
    cd /lambda-php-vendor && \
    /var/lang/bin/php /var/lang/bin/composer require guzzlehttp/guzzle

FROM public.ecr.aws/lambda/provided:al2 as runtime

RUN yum install -y oniguruma-devel

COPY --from=builder /var/lang /var/lang



COPY runtime/bootstrap /var/runtime
RUN chmod 0755 /var/runtime/bootstrap

COPY --from=builder /lambda-php-vendor/vendor /opt/vendor

COPY src/ /var/task/

RUN /var/lang/bin/php -v

CMD [ "index" ]