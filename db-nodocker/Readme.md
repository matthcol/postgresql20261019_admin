# Base de donnée dbmovie (no docker)

## Database
Au préalable créer la base de données:
- encoding UTF-8
- collation par défaut ou collation en-US (provider icu ou libc)

## User / search_path
Choisir user métier propriétaire, schema public ou métier et régler le search_path.

## Import dbmovie
Jouer les scripts initiaux 1 à 1 ou en bloc avec le script 00.

Exemple
```sh
cd sql-init
psql -U umovie -d dbmovie -f 00-import-dbmovie.sql
```
