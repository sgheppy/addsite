#!/bin/bash
#
# usage: $0 <sitename>
#
#    -d create mysql database with user
#    -h print this help
#
help() {
cat <<EOF
$0 [-d][-h] FQND_SITE
  
     -d create mysql database with user
     -h print this help

EOF

exit 0
}

yornorq() {
  shopt -s nocasematch
  until [[ "$ans" == [ynq] ]]
  do
    read  ans
  done
  if [  "$ANSWER" = "q" ]; then
      exit 0
  fi

  echo -n "$ans"
  shopt -u nocasematch
}

genpasswd() {
    local PWD_LENGHT=$1
    
    [ "$PWD_LENGHT" == "" ] && PWD_LENGHT=16
    tr -dc A-Za-z0-9_ < /dev/urandom | head -c $PWD_LENGHT | xargs
}

write_virtualhost() {
    local SITE_FQDN=${1}
    local SITE=$(echo $SITE_FQDN | cut -d. -f1)
    if [ -f  "/etc/apache2/sites-available/${SITE_FQDN}" ]; then
	echo "Virtualhost file ${SITE_FQDN} already exists.  Do you want to overwrite it? " 
	echo -n "Press Y or N to continue, Q to quit: "

	local ANSWER="$(yornorq | tail -c 1)"
	if [  "$ANSWER" = "n" ]; then
	    return
	fi
    fi

    echo "Creating virtualhost ${SITE_FQDN}..."

    cat <<EOF > /etc/apache2/sites-available/${SITE_FQDN}
<VirtualHost *:80>
        ServerName  ${SITE_FQDN}
        ServerAlias www.${SITE_FQDN}

        ServerAdmin webmaster@dhitech.it
        ServerSignature Email

        DocumentRoot /var/www/site_${SITE_FQDN}/${SITE_FQDN}

        <Directory /var/www/site_${SITE_FQDN}.dhitech.it/${SITE_FQDN}.dhitech.it>
                Options Indexes FollowSymLinks MultiViews
                AllowOverride All
                Order allow,deny
                allow from all
        </Directory>

        ErrorLog ${APACHE_LOG_DIR}/${SITE}_dhitech_it_error.log

        # Possible values include: debug, info, notice, warn, error, crit,
        # alert, emerg.
        LogLevel warn

        CustomLog ${APACHE_LOG_DIR}/${SITE}_dhitech_it_access.log combined
</VirtualHost>
EOF
    if [ -f  "/etc/apache2/sites-enabled/${SITE_FQDN}" ]; then
	echo "Site virtualhost already enabled." 
    else
	a2ensite $SITE_FQDN

	echo "Reload Apache?"
	local ANSWER="$(yornorq | tail -c 1)"
	if [  "$ANSWER" = "y" ]; then
	    service apache2 reload
	else 
	    if [  "$ANSWER" = "q" ]; then
		exit 0
	    fi
	fi
    fi

 }


create_database() {
    echo  "Create Database..."
    local USER=${1:0:13}$(( $RANDOM % 99 ))
    local PASSWORD=$2
    local DBNAME=$1
#    EXPECTED_ARGS=3
#    E_BADARGS=65
    cat <<EOF >>/tmp/creasiti_finalprint
##### MYSQL USER E DATABASE #####

 DB USER =      $USER
 DB PASSWORD =  $PASSWORD
 DB NAME =      $DBNAME

#################################

EOF

    echo "I can not check if the user or the mysql database that will be created already exist! Continue?"
    echo -n "Press Y or N to continue, Q to quit: "
    local ANSWER="$(yornorq | tail -c 1)"
    if [ $ANSWER = "n" ]; then
	exit 0
    fi

    MYSQL=$(which mysql)
    Q1="CREATE DATABASE IF NOT EXISTS \`${DBNAME}\`;"
    Q2="GRANT ALL PRIVILEGES ON ${DBNAME}.* TO ${USER}@localhost IDENTIFIED BY '${PASSWORD}' ;"
    Q3="FLUSH PRIVILEGES;"
    SQL="${Q1}${Q2}${Q3}"
    echo -e "Insert MySQL root password..."

    local COUNTER=1
    $MYSQL -uroot --password  -e "$SQL"
    while [ $? -ne 0 -a $COUNTER -lt 3 ]
    do
	echo "Insert MySQL root password..."
	(( COUNTER+=1 ))
	$MYSQL -u root --password  -e "$SQL"
    done

}

while getopts "hd" flag; do
    case "$flag" in
	h)help
	    ;;
	d)cdatabase=1
	    ;;
    esac
done

if [ -z "${@:$OPTIND}" ]
then
    echo -e "Missing arguments\n";
    exit 1
fi

## Controllo che non ci siano più di un argomento 
if [ $( echo ${@:$OPTIND}  | cut -d' ' -f 2 ) != ${@:$OPTIND} ]
then
    echo  -e "Too arguments\n";
    exit 1
fi

## Controllo che non ci siano più di un argomento 
if [  $( echo ${@:$OPTIND}  | cut -d'.' -f 2 ) = ${@:$OPTIND} ]
then
    echo -e "Only sitename.domain.it arguments available.\n";
    exit 1
fi
 
user=( "$( echo ${@:$OPTIND} | cut -d. -f 1 )" );

SITE_FQDN=${@:$OPTIND}

if [ $( grep $user /etc/passwd|awk -F : '{print $user}' ) ]; then
    echo -n "User $user already exists. Do you want to continue? "
    read ANSWER
    if [  $ANSWER != "y" -a $ANSWER != "Y" ]; then
	echo "Finish."
	exit 0
    fi
fi

## Aggiunge un utente con gruppo primario www-data (gid 33)
useradd -d "/var/www/site_${SITE_FQDN}" -m -g 33 $user 
password=$(genpasswd 8)
echo "$user:$password" | chpasswd

cat <<EOF >/tmp/creasiti_finalprint
###### UTENTE DI SISTEMA #######

 Nuovo utente:  $user
 Password:      $password
 Home utente:   /var/www/site_${SITE_FQDN}

EOF
if [ ! -d /var/www/site_${SITE_FQDN}/${SITE_FQDN} ]
then
    mkdir /var/www/site_${SITE_FQDN}/${SITE_FQDN}
fi
chown ${user}:www-data /var/www/site_${SITE_FQDN}/${SITE_FQDN}
chmod g+w /var/www/site_${SITE_FQDN}/${SITE_FQDN}
## Trucco per bug vsftpd
chmod -w /var/www/site_${SITE_FQDN}

write_virtualhost $SITE_FQDN
if [ -n "$cdatabase" ]
    then
    create_database $user $password $SITE_FQDN
fi

echo -e "\n\n\n\n\n"
cat /tmp/creasiti_finalprint

