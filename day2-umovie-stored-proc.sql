-- user : umovie (PROPRIETAIRE du schema data / de la table movie)
-- database : dbmovie
-- objectif : tracer la derniere modif (date + auteur) sur data.movie
--            quel que soit l'utilisateur qui declenche l'update/insert
--            (alain, jacques, matth, ... via v_movie_latest ou autre)

set search_path = cinema;

-- ============================================================
-- 1) Nouvelles colonnes d'audit sur la table movie
-- ============================================================

alter table movie
    add column last_update timestamp,
    add column update_by   varchar(63); -- 63 = taille max d'un identifiant PG (nom de role)

-- pas de "not null" : les lignes existantes n'ont pas cette info


-- ============================================================
-- 2) Fonction trigger
-- ============================================================
-- Point cle : SECURITY DEFINER
-- -------------------------------
-- Par defaut (SECURITY INVOKER), une fonction trigger s'execute avec les
-- privileges du role qui a declenche l'update/insert (alain, jacques...).
--

create or replace function trg_movie_audit()
    returns trigger
    language plpgsql
    security definer
    set search_path = data, pg_catalog, pg_temp
as $$
begin
    new.last_update := current_timestamp::timestamp; -- fonction standard SQL (= debut de transaction)
    new.update_by   := session_user; -- auteur reel, meme si la fonction tourne "en tant que" umovie
    return new;
end;
$$;


-- la fonction n'a pas besoin d'etre appelable directement en SQL
-- (seul le mecanisme de trigger l'invoque, sans verification d'EXECUTE) :
-- on retire donc le droit d'execution public, par defense en profondeur.
revoke execute on function trg_movie_audit() from public;


-- ============================================================
-- 3) Trigger sur la table movie
-- ============================================================

create or replace trigger trg_biu_movie_audit
    before insert or update
    on movie
    for each row
    execute function trg_movie_audit();


-- ============================================================
-- 4) Fonction de calcul independante des tables
-- ============================================================
-- Exemple de fonction "utilitaire" : aucun acces a une table, juste du
-- calcul a partir de ses parametres. Pas besoin de SECURITY DEFINER ici,

create or replace function fn_format_duration(p_duration smallint)
    returns text
    language sql
    immutable
as $$
    select case
        when p_duration is null then null
        else (p_duration / 60) || 'h' || lpad((p_duration % 60)::text, 2, '0')
    end;
$$;

-- select fn_format_duration(172); -- '2h52'
-- select fn_format_duration(null); -- NULL


-- ============================================================
-- 5) Procedure d'ajout d'un film + de son realisateur
-- ============================================================
-- Regles :
--  - title, year : obligatoires (pas de valeur par defaut => a fournir)
--  - realisateur identifie par p_director_id OU p_director_name
--    (+ eventuellement p_director_birthdate pour lever une ambiguite) ;
--    si p_director_id est fourni, il est prioritaire ; si aucun des deux
--    n'est fourni, le film est ajoute sans realisateur (director_id null)
--  - si plusieurs personnes portent ce nom et qu'on ne peut pas trancher
--    => on refuse l'ajout (RAISE EXCEPTION) apres avoir liste les
--       candidats en RAISE NOTICE (id + birthdate), pour que l'appelant
--       puisse relancer avec p_director_id ou p_director_birthdate
--  - si aucune personne ne correspond => on refuse l'ajout et on
--    suggere, en RAISE NOTICE, l'INSERT a faire pour creer le realisateur
--
-- Pas de SECURITY DEFINER ici (contrairement au trigger) : on laisse
-- les droits induits s'appliquer, donc la procedure s'execute avec les
-- privileges de l'appelant. Il lui faut alors directement :
--  - SELECT sur person (deja inclus via r_reader, cf day2-dba.sql)
--  - INSERT sur movie (a accorder explicitement : les grants existants
--    de r_contrib ne portent que sur la vue v_movie_latest, pas sur la
--    table de base)
--  - USAGE sur la sequence movie_id_seq (deja accorde a r_contrib)

create or replace procedure add_movie(
    p_title              varchar,
    p_year               smallint,
    p_director_id        int      default null,
    p_director_name      varchar  default null,
    p_director_birthdate date     default null,
    p_duration           smallint default null,
    p_synopsis           text     default null,
    p_poster_uri         varchar  default null,
    p_color              varchar  default null,
    p_pg                 varchar  default null
)
    language plpgsql
    set search_path = data, pg_catalog, pg_temp
as $$
declare
    v_director_id int;
    v_nb_matches   int;
    v_movie_id     int;
    v_rec          record;
begin
    -- ------------------------------------------------------------
    -- 1) resolution du realisateur
    -- ------------------------------------------------------------
    if p_director_id is not null then

        select id into v_director_id from person where id = p_director_id;

        if v_director_id is null then
            raise exception 'Realisateur introuvable (id = %). Film non ajoute.', p_director_id;
        end if;

    elsif p_director_name is not null then

        if p_director_birthdate is not null then
            select count(*) into v_nb_matches
            from person
            where name = p_director_name and birthdate = p_director_birthdate;
        else
            select count(*) into v_nb_matches
            from person
            where name = p_director_name;
        end if;

        if v_nb_matches = 0 then

            if p_director_birthdate is not null then
                raise notice 'Aucun realisateur "%" (ne(e) le %) trouve.', p_director_name, p_director_birthdate;
            else
                raise notice 'Aucun realisateur "%" trouve.', p_director_name;
            end if;

            raise notice 'Vous pouvez l''ajouter avec : insert into person(name, birthdate) values (%, %);',
                quote_literal(p_director_name),
                quote_nullable(p_director_birthdate::text);

            raise exception 'Realisateur introuvable. Film non ajoute.';

        elsif v_nb_matches = 1 then

            if p_director_birthdate is not null then
                select id into v_director_id from person
                where name = p_director_name and birthdate = p_director_birthdate;
            else
                select id into v_director_id from person
                where name = p_director_name;
            end if;

        else -- v_nb_matches > 1 : ambiguite non levee par birthdate (homonymes avec meme date, ou pas de date fournie)

            raise notice 'Plusieurs personnes nommees "%" trouvees :', p_director_name;
            for v_rec in select id, birthdate from person where name = p_director_name loop
                raise notice '  id = %, birthdate = %', v_rec.id, v_rec.birthdate;
            end loop;

            raise exception 'Realisateur ambigu ("%"). Precisez p_director_id ou p_director_birthdate. Film non ajoute.', p_director_name;

        end if;

    end if;
    -- ni id ni name fournis : v_director_id reste null (film sans realisateur, autorise par le schema)

    -- ------------------------------------------------------------
    -- 2) insertion du film
    -- ------------------------------------------------------------
    insert into movie(title, year, duration, synopsis, poster_uri, color, pg, director_id)
    values (p_title, p_year, p_duration, p_synopsis, p_poster_uri, p_color, p_pg, v_director_id)
    returning id into v_movie_id;

    raise notice 'Film "%" (%) ajoute : id = %, director_id = %, duree = %',
        p_title, p_year, v_movie_id, v_director_id, fn_format_duration(p_duration);
end;
$$;


-- exemples d'appel (parametres nommes recommandes vu le nombre de parametres optionnels) :
-- call add_movie(p_title => 'Oppenheimer', p_year => 2023, p_director_name => 'Christopher Nolan');
-- call add_movie(p_title => 'Le Futur', p_year => 2048, p_director_id => 634240, p_duration => 120);
-- call add_movie(p_title => 'Film Test', p_year => 2030); -- sans realisateur
-- call add_movie(p_title => 'Film Ambigu', p_year => 2030, p_director_name => 'Jean Dupont'); -- si homonymes
