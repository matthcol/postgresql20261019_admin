select * from pg_database;
-- postgres: base défaut, base maintenance
-- template0/template1: bases modèles

-- par défaut : utilise template 1
CREATE DATABASE dbmovie
WITH
    ENCODING = 'UTF8'
;

-- user postgres
-- database postgres


-- short syntax
drop database dbmovie;
CREATE DATABASE dbmovie encoding 'UTF8';

select 
	current_database(),
	current_user,
	SESSION_USER
;


-- USER/ROLE keywords sont interchangeables
CREATE USER umovie WITH
	LOGIN
	PASSWORD 'password'
;

-- ------------------------------------
--              database dbmovie
-- ------------------------------------

-- Le schema public est protégé en écriture par défaut (usage only pas create)
grant create on schema public to umovie;
-- revoke create on schema public from umovie;

-- ------------------------------------
--              database postgres
-- ------------------------------------

-- recreate database
drop database dbmovie;
CREATE DATABASE dbmovie ENCODING 'UTF8';

-- ------------------------------------
--              database dbmovie
-- ------------------------------------
create schema cinema authorization umovie;
alter user umovie set search_path = cinema, public;
select * from pg_user; -- voir colonne useconfig

