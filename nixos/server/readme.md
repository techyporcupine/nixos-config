Hello! This is the WIP section of the NixOS config for my server (beryllium).

A couple things to note:

Secrets go in /var/secrets (this should probably be worked on to be more secure).

Traefik when you use it needs to have an acme.json file with the permissions of 600 and owned by traefik:traefik created in /var/acme.json

Vaultwarden, when you are importing the DB needs it to be owned by vaultwarden:vaultwarden

Dashy needs the directory "dashy" created in the user's home directory. This is where you put the config for dashy.

Home assistant need the directory "hass" created in the user's home directory.