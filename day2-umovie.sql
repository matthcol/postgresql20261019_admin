-- user umovie
-- database dbmovie

create or replace view v_movie_latest as (
	select 
		m.id,
		m.title,
		m.year,
		m.duration,
		m.director_id
	from movie m
	where 
		m.year > (date_part('year', current_date) - 10)
);


select * from v_movie_latest order by year desc;

create or replace view v_movie_director as (
	select
		m.id as movie_id,
		m.title,
		m.year,
		m.director_id,
		d.name
	from 
		movie m
		left join person d on m.director_id = d.id
);


select *
from v_movie_director
where year = 1984
order by title;











