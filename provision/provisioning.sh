#!/usr/bin/env bash

# https://github.com/mattandersen/vagrant-lamp/blob/master/provision.sh

php_version="7.2"
php_version_long="7.2.0"
php_source="php-${php_version_long}.tar.gz"

homeDir="/home/vagrant/php72"

apache_env_file="/etc/apache2/envvars"
apache_config_file="/etc/apache2/apache2.conf"
apache_vhost_file="/etc/apache2/sites-available/vagrant_vhost.conf"
php_config_file="/etc/php/7.1/apache2/php.ini"
php_config_file_cli="/etc/php/7.1/cli/php.ini"
xdebug_config_file="/etc/php/7-1/mods-available/xdebug.ini"
mysql_config_file="/etc/mysql/my.cnf"
default_apache_index="/var/www/html/index.html"
rc_local="/etc/rc.local"
bash_aliases="/home/vagrant/.bash_aliases"

# This function is called at the very bottom of the file
main() {

    export DEBIAN_FRONTEND=noninteractive

	update_proc

	if [[ -e /var/lock/vagrant-provision ]]; then
	    cat 1>&2 << EOD
################################################################################
# To re-run full provisioning, delete /var/lock/vagrant-provision and run
#
#    $ vagrant provision
#
# From the host machine
################################################################################
EOD
	    exit
	fi

	network_proc
	swap_proc
	java_proc
	apache_proc
	mysql_proc
	bash_proc
	permissions_proc
	install_proc

	touch /var/lock/vagrant-provision
}

install_proc() {
    if [[ ! -f "${homeDir}/sources/${php_source}" ]]
    then
        echo "Downloading PHP sources ${php_source}"
        wget -q http://de2.php.net/distributions/${php_source} > "${homeDir}/sources/${php_source}"
    else
        echo "${php_source} does exist..."
    fi

    rm -rf /tmp/php
    mkdir -p /tmp/php
    cp "${homeDir}/sources/${php_source}" /tmp/php

    cd /tmp/php
    tar xfz ${php_source}

    cd php-${php_version_long}
    ./configure \
        --with-apxs2=/usr/bin/apxs \
        --with-mysqli

    make
    make install
}

permissions_proc() {
    echo
    echo "******************************"
    echo "** permissions_proc ************"
    echo "******************************"

    chown -R vagrant:vagrant ${homeDir}
#    touch /home/vagrant/php72/var/log
#    chmod -R 777 /home/vagrant/php72/var/log
#    touch /home/vagrant/php72/var/cache
#    chmod -R 777 /home/vagrant/php72/var/cache
}

update_proc() {
    echo
    echo "******************************"
    echo "** update_proc *****************"
    echo "******************************"

    # Install basic tools
	apt-get -y install build-essential
	apt-get -y install binutils-doc
	apt-get -y install git
	apt-get -y install apt-transport-https
	apt-get -y install lsb-release
	apt-get -y install ca-certificates
	apt-get -y install zip
	apt-get -y install unzip
    apt-get -y install libxml2-dev

	apt-get update
	apt-get -y upgrade
}

bash_proc() {
    echo
    echo "******************************"
    echo "** bash_proc *******************"
    echo "******************************"

	cat << EOF > ${bash_aliases}
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias lll='ls -al'
EOF
}

network_proc() {
    echo
    echo "******************************"
    echo "** network_proc ****************"
    echo "******************************"

	IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')
	sed -i "s/^${IPADDR}.*//" /etc/hosts
	echo ${IPADDR} vagrant.localhost >> /etc/hosts
}

swap_proc() {
    echo
    echo "******************************"
    echo "** swap_proc *******************"
    echo "******************************"

    # https://gist.github.com/shovon/9dd8d2d1a556b8bf9c82
    # swapfile size (MB)
    swapsize=8000

    # does the swap file already exist?
    grep -q "swapfile" /etc/fstab

    # if not then create it
    if [ $? -ne 0 ]; then
      echo 'swapfile not found. Adding swapfile.'
      fallocate -l ${swapsize}M /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo '/swapfile none swap defaults 0 0' >> /etc/fstab
    fi
}

apache_proc() {
    echo
    echo "******************************"
    echo "** apache_proc *****************"
    echo "******************************"

	apt-get -y install apache2-dev

	sed -i "s/^\(.*\)www-data/\1vagrant/g" ${apache_env_file}
	sed -i "s/^\(.*\)\/var\/www\//\1\/home\/vagrant\/php72\//g" ${apache_config_file}
	chown -R vagrant:vagrant /var/log/apache2

	# Export locale
	sudo locale-gen de_DE.UTF-8

	cat << EOF > ${apache_vhost_file}
<VirtualHost *:80>
        ServerName php72.co.uk
        ServerAlias www.php72.co.uk

        ServerAdmin webmaster@localhost
        DocumentRoot /home/vagrant/php72/public
        LogLevel debug

        ErrorLog /var/log/apache2/error.log
        CustomLog /var/log/apache2/access.log combined

        SetEnv php72_ENV dev

        <Directory /home/vagrant/php72/public>
            AllowOverride None
            Order Allow,Deny
            Allow from All
            Options -MultiViews

            RewriteEngine On
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteRule ^(.*)$ index.php [QSA,L]
        </Directory>
</VirtualHost>
EOF

	a2dissite 000-default
	a2ensite vagrant_vhost

	a2enmod rewrite

	service apache2 reload
	update-rc.d apache2 enable
}

java_proc() {
    echo
    echo "******************************"
    echo "** java_proc *******************"
    echo "******************************"

    apt-get -y install default-jre
}

sqlite_proc() {
    echo
    echo "******************************"
    echo "** sqlite_proc *****************"
    echo "******************************"

    apt-get -y install sqlite3
}

php_proc() {
    echo
    echo "******************************"
    echo "** php_proc ********************"
    echo "******************************"

    x="$(dpkg --list | grep php | awk '/^ii/{ print $2}')"
    echo
    echo "Purging preinstalled PHP: "${x}
    echo
    apt-get --purge remove ${x}

	apt-get -y install php php-curl php-mysql php-sqlite3 php-xdebug php-intl php-gd php-xml

	sed -i "s/display_startup_errors = Off/display_startup_errors = On/g" ${php_config_file}
	sed -i "s/display_startup_errors = Off/display_startup_errors = On/g" ${php_config_file_cli}
	sed -i "s/display_errors = Off/display_errors = On/g" ${php_config_file}
	sed -i "s/display_errors = Off/display_errors = On/g" ${php_config_file_cli}
	sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 4M/g" ${php_config_file}
	sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 4M/g" ${php_config_file_cli}
	sed -i "s/;date\.timezone =/date.timezone = Europe\/Berlin/g" ${php_config_file}
    sed -i "s/;date\.timezone =/date.timezone = Europe\/Berlin/g" ${php_config_file_cli}
  	sed -i "s/session\.gc_maxlifetime = 1440/session.gc_maxlifetime = 7200/g" ${php_config_file}
  	sed -i "s/session\.gc_maxlifetime = 1440/session.gc_maxlifetime = 7200/g" ${php_config_file_cli}

	cat << EOF > ${xdebug_config_file}
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.remote_port=9000
xdebug.remote_host=10.0.2.2
EOF
	service apache2 reload
}

mysql_proc() {
    echo "******************************"
    echo "** mysql_proc ******************"
    echo "******************************"

	echo "mysql-server mysql-server/root_password password root" | debconf-set-selections
	echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections
	apt-get -y install mysql-client mysql-server

	sed -i "s/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" ${mysql_config_file}
	sed -i "s/#general_log_file/general_log_file/g" ${mysql_config_file}
	sed -i "s/#general_log/general_log/g" ${mysql_config_file}

	# Allow root access from any host
	echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION" | mysql -u root --password=root
	echo "GRANT PROXY ON ''@'' TO 'root'@'%' WITH GRANT OPTION" | mysql -u root --password=root
    echo

	service mysql restart
	update-rc.d apache2 enable
}

main
exit 0
