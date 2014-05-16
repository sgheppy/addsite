 # Creasiti
   Questo script crea un utente con home in directory /var/www/ e con nome pari al dominio di terzo livello del sito specificato
   In più crea il file di configurazione del virtualhost associato, lo abilita ed esegue il reload del servizio apache2

   Se specificato crea Utenze e Database del relativo sito.

   Esempio:
 ```bash
     $0 -d sitename.domain.it
 ```
   crea :
  user -> sitename
  home -> /var/www/site_sitename.domain.it/ ed inoltre la cartella  /var/www/site_sitename.domain.it/sitename.domain.it/       
                     NB: il sito sarà ospitato solo nell'ultima cartella specificata
  password -> generata di 8 caratteri specificata a fine script  
  virtualhost -> /etc/apache2/sites-available/sitename.domain.it

  MYSQL

  user -> sitename troncato a 14 caratteri seguito da due interi casuali
  password -> stessa password generata per l'utente posix
  database name -> sitename
