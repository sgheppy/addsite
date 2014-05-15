#!/bin/bash
#
# usage: $0 <sitename>
#

help() {
cat <<EOF
$0 [-d][-h] FQND_SITE
  -d create mysql database with username
  -h print this help

Questo script crea un utente con home in directory /var/www/ e con nome pari al dominio di terzo livello del sito specificato
In più crea il file di configurazione del virtualhost associato, lo abilita ed esegue il reload del servizio apache2

Se specificato crea Utenze e Database del relativo sito.

Esempio:

$0 -d sitename.domain.it

crea :
user -> sitename
home -> /var/www/site_sitename.domain.it/ ed inoltre la cartella /var/www/site_sitename.domain.it/sitename.domain.it/ ## NB il sito sarà ospitato solo nell'ultima cartella specificata
password -> generata di 8 caratteri specificata a fine script  
virtualhost -> /etc/apache2/sites-available/sitename.domain.it

MYSQL

user -> sitename troncato a 14 caratteri seguito da due interi casuali
password -> stessa password generata per l'utente posix
database name -> sitename


EOF
}

genpasswd() {
    local PWD_LENGHT=$1
    
    [ "$PWD_LENGHT" == "" ] && PWD_LENGHT=16
    tr -dc A-Za-z0-9_ < /dev/urandom | head -c $PWD_LENGHT | xargs
}

write_virtualhost() {
    local SITE_FQDN=${1}
    local SITE=$(echo $SITE_FQDN | cut -d. -f1)
    echo -e "Creating virtualhost ${SITE_FQDN} ... \n"
    cat <<EOF > /etc/apache2/sites-available/${SITE_FQDN}.dhitech.it
<VirtualHost *:80>
        ServerName  ${SITE_FQDN}.dhitech.it
        ServerAlias www.${SITE_FQDN}.dhitech.it

        ServerAdmin webmaster@dhitech.it
        ServerSignature Email

        DocumentRoot /var/www/site_${SITE_FQDN}.dhitech.it/${SITE_FQDN}.dhitech.it

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
    }


create_database() {
    echo -e "Create Database... \n"
    local USER=${1:0:13}$( expr $RANDOM % 99)
    local PASSWORD=$2
    local DBNAME=$1
    EXPECTED_ARGS=3
    E_BADARGS=65
    MYSQL=`which mysql`
    
    Q1="CREATE DATABASE IF NOT EXISTS \`${DBNAME}\`;"
    Q2="GRANT ALL PRIVILEGES ON ${DBNAME}.* TO ${USER}@localhost IDENTIFIED BY '${PASSWORD}' ;"
    Q3="FLUSH PRIVILEGES;"
    SQL="${Q1}${Q2}${Q3}"
    echo -e "Insert MySQL root password... \n"
    $MYSQL -uroot --password  -e "$SQL"
    while [ $? -ne 0 ]
    do
	echo -e "Insert MySQL root password... \n"
	$MYSQL -uroot --password  -e "$SQL"
    done
    cat <<EOF 
 DB USER = $USER
 DB PASSWORD = $PASSWORD
 DB NAME = $DBNAME 
EOF
}

while getopts "hvd" flag; do
    case "$flag" in
	h)help
	    ;;
	d)cdatabase=1
	    ;;

    esac
done

if [ -z "${@:$OPTIND}" ]
then
    echo "Missing arguments";
    exit 1
fi

## Controllo che non ci siano più di un argomento 
if [ $( echo ${@:$OPTIND}  | cut -d' ' -f 2 ) != ${@:$OPTIND} ]
then
    echo "Too arguments";
    exit 1
fi
 
user=$( echo ${@:$OPTIND} | cut -d. -f 1 );

SITE_FQDN=${@:$OPTIND}

if [ $( grep $user /etc/passwd|awk -F : '{print $user}' ) ]; then
 echo "ERROR: User $user already exists. Use a different login name." 
 exit 1
fi

## Aggiunge un utente con gruppo primario www-data (gid 33)
useradd -d "/var/www/site_${SITE_FQDN}" -m -g 33 $user 
password=$(genpasswd 8)
echo "$user:$password" | chpasswd

echo "$user:$password"

mkdir /var/www/site_${SITE_FQDN}/${SITE_FQDN}
chown ${user}:www-data /var/www/site_${SITE_FQDN}/${SITE_FQND}
chmod g+w /var/www/site_${SITE_FQDN}/${SITE_FQDN}
## Trucco per bug vsftpd
chmod -w /var/www/site_${SITE_FQDN}

write_virtualhost $SITE_FQDN

if [ $cdatabase -eq 1 ]
    then
    create_database $user $password $SITE_FQDN
fi
