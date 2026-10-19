#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --renew-anon-volumes : recree les volumes anonymes (ex: data interne de
# l'image postgres) au lieu de reutiliser ceux du conteneur precedent.
docker compose \
  -f "$script_dir/docker-compose.yml" \
  -f "$script_dir/docker-compose.persist.yml" \
  up -d --renew-anon-volumes "$@"
