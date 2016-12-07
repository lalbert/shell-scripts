#!/bin/bash

# Check if is root
if [ "$EUID" -ne 0 ]
	then echo "Please run as root"
	exit 1
fi

# Update installed packages
echo "Update installed packages"
apt-get update && apt-get upgrade -y
echo

# Install utils packages
echo "Install utils packages"
apt-get install -y software-properties-common curl git zip ca-certificates --no-install-recommends
echo

# Install apache2
echo "Install apache2"
apt-get install -y apache2.2-bin apache2.2-common --no-install-recommends
a2enmod autoindex deflate expires filter headers include mime rewrite setenvif
echo

# Install MariaDB
echo "Install MariaDB"
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
add-apt-repository 'deb [arch=amd64,i386] http://mirror6.layerjet.com/mariadb/repo/10.1/debian jessie main'
apt-get update && apt-get install -y mariadb-server --no-install-recommends
echo

# Install PHP7
echo "Install PHP7"
a2dismod mpm_event && a2enmod mpm_prefork proxy_fcgi
echo "deb http://packages.dotdeb.org jessie all" > /etc/apt/sources.list.d/dotdeb.list
wget https://www.dotdeb.org/dotdeb.gpg && apt-key add dotdeb.gpg
apt-get update && apt-get install -y php7.0 php7.0-fpm php7.0-curl php7.0-gd php7.0-imagick php7.0-intl php7.0-json php7.0-mcrypt php7.0-mbstring php7.0-mysql php7.0-xsl php7.0-zip --no-install-recommends
a2enconf php7.0-fpm
service apache2 restart
echo

# Install Composer
echo "Install Composer"
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin/ --filename=composer
echo

# Cleanup install
echo "Cleanup"
rm dotdeb.gpg
rm -r /var/lib/apt/lists/*

exit 0;
