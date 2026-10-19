#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
env_file="$script_dir/.env"
pgpass_file="$script_dir/pgadmin/pgpass"
servers_file="$script_dir/pgadmin/servers.json"

db_name="dbmovie"
db_user="umovie"
db_password="password"

if [[ -f "$env_file" ]]; then
  while IFS='=' read -r key value; do
    key="$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$key" || "$key" == \#* ]] && continue
    value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/;s/^'"'"'\(.*\)'"'"'$/\1/')"
    case "$key" in
      DB_NAME) db_name="$value" ;;
      DB_USER) db_user="$value" ;;
      DB_PASSWORD) db_password="$value" ;;
    esac
  done < "$env_file"
fi

# Port reste 5432 : c'est le port interne au reseau docker (pgadmin -> db),
# pas DB_PORT qui sert uniquement au mapping vers l'hote.
echo "db:5432:*:${db_user}:${db_password}" > "$pgpass_file"
chmod 600 "$pgpass_file" 2>/dev/null || true

# PassFile: ".pgpass" fait reference au fichier copie par pgAdmin dans son
# repertoire de stockage via la variable PGPASS_FILE (sans cette cle,
# pgAdmin ignore le pgpass et redemande toujours le mot de passe).
cat > "$servers_file" <<EOF
{
  "Servers": {
    "1": {
      "Name": "${db_name}",
      "Group": "Servers",
      "Host": "db",
      "Port": 5432,
      "MaintenanceDB": "${db_name}",
      "Username": "${db_user}",
      "PassFile": ".pgpass",
      "SSLMode": "prefer"
    }
  }
}
EOF

env_found="non"; [[ -f "$env_file" ]] && env_found="oui"
echo "pgpass + servers.json mis a jour (.env trouve: ${env_found}) -> db=${db_name} user=${db_user}"
