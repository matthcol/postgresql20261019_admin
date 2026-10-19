$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# --renew-anon-volumes : recree les volumes anonymes (ex: data interne de
# l'image postgres) au lieu de reutiliser ceux du conteneur precedent.
docker compose `
  -f (Join-Path $scriptDir "docker-compose.yml") `
  -f (Join-Path $scriptDir "docker-compose.persist.yml") `
  up -d --renew-anon-volumes @args
