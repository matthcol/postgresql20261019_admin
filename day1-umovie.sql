-- user umovie
-- database dbmovie

show search_path;  -- "cinema, public"

select count(*) from movie;
select title, year from movie where year = 1982;

select
	current_user,
	current_database()
;

-- setting provisoire sur la session
set search_path = public;
select count(*) from movie; -- ERROR:  relation "movie" does not exist
select count(*) from cinema.movie; -- OK

set search_path = cinema;
select count(*) from movie;  -- OK

-- primary keys et sequences
-- - solution 1 : types "serial"
--       * smallserial  => type smallint + creer sequence  <nomtable>_<nomcolonne>_seq + clause default
--                        max ~32K
--       * serial  => type int(eger)  + creer sequence <nomtable>_<nomcolonne>_seq + clause default
--                        max ~2G (milliard)
--       * bigserial => type bigint + creer sequence <nomtable>_<nomcolonne>_seq + clause default
--                        max ~9E (milliard de milliard)
--
-- - solution 2 : clause "identity" (standard SQL) => create sequence <nomtable>_<nomcolonne>_seq
--             https://www.postgresql.org/docs/18/ddl-identity-columns.html
--
-- - colution 3 : create sequence + pilotage appli
select nextval('movie_id_seq');  -- 8079249
select currval('movie_id_seq'); -- dans la session courante : 8079249

select * from pg_indexes where schemaname = 'cinema';
-- indexes implicites : contrainte UNIQUE (inclus PK) => BTREE

-- index explicite
-- https://www.postgresql.org/docs/current/indexes.html
create index idx_person_name on person(name); -- default BTREE => opérateur =, >, >=, <, <=, BETWEEN
select * from person where name = 'Clint Eastwood'; -- TODO: explain plan  => index idx_person_name
select * from person where birthdate = '1930-05-31'; -- pas d'index => balayage de la table


-- code stocké
-- * procedure
-- * function (appelable en SQL)
-- * type
-- * operator (surcharge +, -, ...)
-- * trigger : event DML (INSERT, UPDATE, DELETE, ...), sur  1 vue (INSTEAD OF)

select 
	title,
	year,
	duration,
	fn_format_duration(duration) as duration_hm
from movie
where year = 1992
;


select upper('terminator');
select fn_format_duration(125); -- ERROR:  function fn_format_duration(integer) does not exist
select fn_format_duration(125::smallint);

-- types de données
-- https://www.postgresql.org/docs/current/datatype.html
--

select 
	0.1::decimal * 3, -- calcul exact : 0.3
	0.1::real * 3     -- calcul à virgule flottante : 0.30000000447034836
;

select 
	current_date, -- date
	current_time, -- time with time zone = timetz
	current_time::time, -- time without time zone = time
	current_timestamp,  -- timestamp with time zone = timestamptz
	current_timestamp::timestamp -- timestamp without time zone = timestamptz
;


select 
	name,
	birthdate,
	age(birthdate),
	extract(year from current_date) - extract(year from birthdate) as age_year
from person
where 
	extract(year from birthdate) between 1930 and 1939
order by birthdate
;


select * from person where name like '% Tarantino'; -- OK (CS)
select * from person where name like '% tarantino'; -- no one (CS)
select * from person where name ilike '% tarantino'; -- OK (CI)

-- regexp POSIX
select 
	title,
	year
from movie
where title ~* 'war|love'
;

select 
	title,
	year
from movie
where title ~* '(of .*){5,}'
;


