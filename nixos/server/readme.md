Hello! This is the WIP section of the NixOS config for my server (beryllium).

A couple things to note:

Secrets go in /var/secrets (this should probably be worked on to be more secure).

Traefik when you use it needs to have an acme.json file with the permissions of 600 and owned by traefik:traefik created in /var/acme.json

Vaultwarden, when you are importing the DB needs it to be owned by vaultwarden:vaultwarden

Dashy needs the directory "dashy" created in the user's home directory. This is where you put the config for dashy.

Home assistant need the directory "hass" created in the user's home directory. You also need to make sure that a port that is not in use (other than 8123) is being used, as Clickhouse as a part of plausible likes 8123.

Wishthis needs "wishthis/config.php" created in the user's home directory along with "wishthis/mariadb"