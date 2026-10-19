select setval('person_id_seq', max(id)) from person;
select setval('movie_id_seq', max(id)) from movie;
