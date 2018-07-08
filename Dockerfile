# Docker Hubで提供されているOfficial Repositoryから、CentOS7をベースにして構築する。
FROM centos:7

### OSの設定 ############################################################
# 作業ディレクトリに移動。
WORKDIR /root/.tmp

# OSのタイムゾーン設定
RUN \cp -p -f /usr/share/zoneinfo/Japan /etc/localtime

### YUMの設定 ############################################################

# EPELのリポジトリをインストールする。
RUN yum -y upgrade
RUN yum -y install epel-release
RUN yum -y install http://rpms.famillecollet.com/enterprise/remi-release-7.rpm

### インストール #########################################################

# Apacheなどのミドルウェアのインストール。
RUN yum -y install httpd mod_ssl telnet git vim wget sudo openssl memcached memcached-devel mlocate crontabs --enablerepo=epel

# PHP7.2のインストール。
# Laravelの動作条件を満たすように、併せて各種モジュールもインストールする。
RUN yum install -y --enablerepo=remi-php72 php php-devel php-mbstring php-pdo php-gd php-mysqlnd php-tokenizer php-mcrypt php-pecl-memcache php-xml php-pear php-pecl php-xdebug

# Composerのインストール。
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer

# locateが使えるようにupdatedb
RUN updatedb

### シンボリックリンクの作成 #######################################################
# Apache
RUN rm -rf /var/log/httpd
RUN ln -s /data/doc_root/service/larapi/log/httpd /var/log/httpd
# PHP
RUN ln -s /data/doc_root/service/larapi/log/php /var/log/php

### Apache, PHPの設定をして起動 #######################################################

# php.iniの個人設定
RUN touch /etc/php.d/personal.ini
RUN echo $'; エラーログ\n\
log_errors = On\n\
error_log = /var/log/php/php_errors.log\n\
; タイムゾーン\n\
date.timezone = \'Asia/Tokyo\'' >> /etc/php.d/personal.ini

# Apacheを設定して起動
RUN echo $'<VirtualHost *:80>\n\
   DocumentRoot /data/doc_root/service/larapi/public/\n\
   ServerName larapi/\n\
   ErrorLog logs/larapi_error_log\n\
   CustomLog logs/larapi_access_log combined\n\
   <Directory "/data/doc_root/service/larapi/public/">\n\
       Require all granted\n\
   </Directory>\n\
</VirtualHost>' >> /etc/httpd/conf/httpd.conf

# SSLの設定（既存のconfigをバックアップして新たにconfigを作る。）
RUN mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf_bk
RUN touch /etc/httpd/conf.d/ssl.conf
RUN echo $'LoadModule ssl_module modules/mod_ssl.so\n\
Listen 443\n\
SSLPassPhraseDialog  builtin\n\
SSLSessionCache         shmcb:/var/cache/mod_ssl/scache(512000)\n\
SSLSessionCacheTimeout  300\n\
Mutex default ssl-cache\n\
SSLRandomSeed startup file:/dev/urandom  256\n\
SSLRandomSeed connect builtin\n\
SSLCryptoDevice builtin\n\
<VirtualHost _default_:443>\n\
    DocumentRoot "/data/doc_root/service/larapi/public/"\n\
    ServerName larapi:443\n\
    ErrorLog logs/larapi_error_log\n\
    CustomLog logs/larapi_access_log combined\n\
    LogLevel warn\n\
    SSLEngine on\n\
    SSLProtocol all -SSLv2\n\
    SSLCipherSuite DEFAULT:!EXP:!SSLv2:!DES:!IDEA:!SEED:+3DES\n\
    SSLCertificateFile /etc/pki/tls/certs/server.pem\n\
    SSLCertificateKeyFile /etc/pki/tls/certs/server.key\n\
    <Files ~ "\.(cgi|shtml|phtml|php3?)$">\n\
        SSLOptions +StdEnvVars\n\
    </Files>\n\
    <Directory "/var/www/cgi-bin">\n\
        SSLOptions +StdEnvVars\n\
    </Directory>\n\
    <Directory "/data/doc_root/service/larapi/public/">\n\
        Require all granted\n\
    </Directory>\n\
    SetEnvIf User-Agent ".*MSIE.*" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0\n\
</VirtualHost>' >> /etc/httpd/conf.d/ssl.conf

# xdebug.iniを設定して起動
RUN echo $'xdebug.remote_enable = 1\n\
xdebug.remote_autostart = 1\n\
xdebug.remote_connect_back = 0\n\
xdebug.remote_host = host.docker.internal\n\
xdebug.remote_port = 9000\n\
xdebug.idekey = PHPSTORM' >> /etc/php.d/xdebug.ini

# 自動起動設定ON
RUN chkconfig httpd on

# SSL自己証明書をコピーする。
COPY certs/server.* /etc/pki/tls/certs/

# 作業ディレクトリを設定
WORKDIR /data/doc_root/service/larapi/

EXPOSE 80

# DOCKER RUN実行時に/sbin/initが実行されるようにする。
ENTRYPOINT /sbin/init
