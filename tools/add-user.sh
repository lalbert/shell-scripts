#!/bin/bash

# Add user :
# * Create new user and home directory (web document root)
# * Create apache vhost
# * Create php-fpm pool
# * Create MySQL database
#
# ./add-user.sh -u|--user {{user}} -p|--password {{password}} -d|--domain {{domain}}

# Check if is root
if [ "$EUID" -ne 0 ]
	then echo "Please run as root"
	exit 1
fi

# Show command usage
function usage()
{
	echo "Usage: ./add-user.sh [options...]"
	echo "Options:"
	echo "  -u,  --user USERNAME     Username of new user. 3 cars min. No space"
	echo "  -p,  --password PASSWORD Password of new user. 6 cars min. No space"
	echo "  -d,  --domaine DOMAIN    Domain for apache vhost"
}

# Default variables
CREATE_APACHE_VHOST=true
CREATE_PHPFPM_POOL=true
CREATE_DATABASE=true
WEB_ROOT=/var/www/

# Parse arguments
while test $# -gt 0; do
	case "$1" in
        -h|--help)
	        usage
	        exit 0
	        ;;
        -u)
			shift
	        if test $# -gt 0; then
                export NEW_USER=$1
	        else
                echo "no user specified"
                exit 100
	        fi
	        shift
			;;
        --user*)
			export NEW_USER=`echo $1 | sed -e 's/^[^=]*=//g'`
			shift
			;;
        -p)
			shift
	        if test $# -gt 0; then
                export PASSWORD=$1
	        else
                echo "no password specified"
                exit 100
	        fi
	        shift
			;;
        --password*)
			export PASSWORD=`echo $1 | sed -e 's/^[^=]*=//g'`
			shift
			;;
        -d)
			shift
	        if test $# -gt 0; then
                export DOMAIN=$1
	        else
                echo "no domain specified"
                exit 100
	        fi
	        shift
			;;
        --domain*)
			export DOMAIN=`echo $1 | sed -e 's/^[^=]*=//g'`
			shift
			;;
        --no-apache-vhost*)
			CREATE_APACHE_VHOST=false
			shift
			;;
        --no-php-fpm-pool*)
			CREATE_PHPFPM_POOL=false
			shift
			;;
        --no-create-db*)
			CREATE_DATABASE=false
			shift
			;;
        *)
	        break
	        ;;
	esac
done

while [[ -z "${NEW_USER// }" ]] || [[ ${#NEW_USER} -lt 3 ]]
do
        read -p 'Username (3 cars min, no space): ' NEW_USER
done

while [[ -z "${PASSWORD// }" ]] || [[ ${#PASSWORD} -lt 6 ]]
do
        read -p 'Password (6 cars min, no space): ' PASSWORD
done

if [ $CREATE_APACHE_VHOST == 'true' ]
then
	while [[ -z "${DOMAIN// }" ]]
	do
        read -p 'Domain: ' DOMAIN
	done
fi

USER_HOME_DIRECTORY="$WEB_ROOT$NEW_USER/"

# Display information to confirm
echo
echo -e "USERNAME:            '\e[92m$NEW_USER\e[0m'"
echo -e "PASSWORD:            '\e[92m$PASSWORD\e[0m'"
echo -e "CREATE_APACHE_VHOST: \e[92m$CREATE_APACHE_VHOST\e[0m"
if [ $CREATE_APACHE_VHOST == 'true' ]
then
	echo -e "DOMAIN:              '\e[92m$DOMAIN\e[0m'"
fi
echo -e "CREATE_PHPFPM_POOL:  \e[92m$CREATE_PHPFPM_POOL\e[0m"
echo -e "CREATE_DATABASE:     \e[92m$CREATE_DATABASE\e[0m"

# Check if all is ok
read -p 'All is ok? [yes/no]: ' ok
if [ "$ok" != "yes" ]
then
    echo -e "\e[31mCreate new user canceled\e[0m"
    exit 999
fi

# Check if user already exists
if id "$NEW_USER" >/dev/null 2>&1; then
	echo -e "\e[31mUser '$NEW_USER' already exists\e[0m"
	exit 2
fi

WEB_ROOT_NAME="web/"
WEB_ROOT="$USER_HOME_DIRECTORY$WEB_ROOT_NAME"

function create_user()
{
	echo -e "\e[33mCreate new user $NEW_USER\e[0m"
	echo
	
	useradd -m -d "$USER_HOME_DIRECTORY" -s /bin/bash $NEW_USER
	echo "$NEW_USER:$PASSWORD" | chpasswd
	
	mkdir $WEB_ROOT
	chown $NEW_USER:$NEW_USER $WEB_ROOT
	
	echo "New user '$NEW_USER' created"
	echo "Home directory: '$USER_HOME_DIRECTORY'"
	echo "Web root: '$WEB_ROOT'"
	echo
}

APACHE_TEMPLATE_FILE="./../templates/apache-php7-fpm.tpl"
APACHE_TO_FILE="/etc/apache2/sites-available/$NEW_USER.conf"

function create_apache_vhost()
{
	# escape / for sed command
	local _WEB_ROOT="${WEB_ROOT//\//\\/}"
	
	echo -e "\e[33mCreate Apache Virtual Host\e[0m"
	echo
	
	cp "$APACHE_TEMPLATE_FILE" "$APACHE_TO_FILE"
	
	# Replace all variables
	sed -i -- "s/{{domain}}/$DOMAIN/g" "$APACHE_TO_FILE"
	sed -i -- "s/{{user}}/$NEW_USER/g" "$APACHE_TO_FILE"
	sed -i -- "s/{{web_root}}/$_WEB_ROOT/g" "$APACHE_TO_FILE"
	
	echo "Apache Virtual Host is configured"
	echo "Configuration file is here: $APACHE_TO_FILE"
	echo "Your document root is here: $WEB_ROOT"
	echo
}

PHPFPM_POOL_TEMPLATE_FILE="./../templates/php7-fpm-pool.tpl"
PHPFPM_POOL_TO_FILE="/etc/php/7.0/fpm/pool.d/$NEW_USER.conf"

function create_phpfpm_pool()
{
	echo -e "\e[33mCreate PHP7 FPM Pool\e[0m"
	echo
	
	cp "$PHPFPM_POOL_TEMPLATE_FILE" "$PHPFPM_POOL_TO_FILE"
	
	# Replace all variables
	sed -i -- "s/{{user}}/$NEW_USER/g" "$PHPFPM_POOL_TO_FILE"
	
	echo "PHP FPM Pool is configured"
	echo "Configuration file is here: $PHPFPM_POOL_TO_FILE"
	echo
}

function create_database()
{
	local MYSQL_ROOT_PASSWORD=""
	local MYSQL_LOGIN_COMMAND=""
	
	echo -e "\e[33mCreate MySQL Database\e[0m"
	echo
	
	if [ ! -f ~/.my.cnf ]
	then
		while [[ -z "${MYSQL_ROOT_PASSWORD// }" ]]
		do
	        read -p -s 'MySQL root password: ' MYSQL_ROOT_PASSWORD
		done
		
		MYSQL_LOGIN_COMMAND=" -uroot -p${MYSQL_ROOT_PASSWORD}"
	fi
	
	mysql $MYSQL_LOGIN_COMMAND -e "CREATE USER '${NEW_USER}'@'localhost' IDENTIFIED BY '${PASSWORD}';"
	mysql $MYSQL_LOGIN_COMMAND -e "CREATE DATABASE IF NOT EXISTS ${NEW_USER}"
	mysql $MYSQL_LOGIN_COMMAND -e "GRANT ALL PRIVILEGES ON ${NEW_USER}.* TO '${NEW_USER}'@'localhost';"
	mysql $MYSQL_LOGIN_COMMAND -e "FLUSH PRIVILEGES;"
	
	echo
}

# Activate Apache Vhost and restarts services
function activate()
{
	echo -e "\e[33mActivate and restart services...\e[0m"
	a2ensite "$NEW_USER" > /dev/null 2>&1
	
	service php7.0-fpm restart && service apache2 restart
	echo -e "\e[92mDone\e[0m"
}

create_user
create_apache_vhost
create_phpfpm_pool
create_database
activate
