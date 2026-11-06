-- Local test of 0002_guilds.sql (runs after test_1_online_base.sql on the same DB).
\set ON_ERROR_STOP on
reset role;
grant select on all tables in schema public to anon, authenticated;
insert into auth.users values ('00000000-0000-0000-0000-000000000003'), ('00000000-0000-0000-0000-000000000004')
  on conflict do nothing;
set role authenticated;
select set_config('test.uid', '00000000-0000-0000-0000-000000000003', false) \g /dev/null
do $$ declare r jsonb; begin
  perform cl_set_name('Gründerin');
  assert cl_guild_mine() is null, 'noch keine Gilde';
  begin perform cl_guild_create('Xy', 'AB'); assert false, 'zu kurzer Name'; exception when raise_exception then null; end;
  begin perform cl_guild_create('Glutfalken', 'a!'); assert false, 'falsches Kürzel'; exception when raise_exception then null; end;
  r := cl_guild_create('Glutfalken', 'glut', 1);
  assert r ->> 'tag' = 'GLUT' and r ->> 'role' = 'anfuehrer' and (r ->> 'slots')::int = 15, 'Gilde gegründet, 15 Plätze';
  assert jsonb_array_length(r -> 'goals') = 3, 'drei Wochenziele';
  begin perform cl_guild_create('Zweite', 'ZW'); assert false, 'nur eine Gilde'; exception when raise_exception then null; end;
end $$;
select set_config('test.uid', '00000000-0000-0000-0000-000000000004', false) \g /dev/null
do $$ declare r jsonb; gid bigint; begin
  perform cl_set_name('Neuling');
  begin perform cl_guild_create('glutFALKEN', 'XX'); assert false, 'Name doppelt'; exception when raise_exception then null; end;
  r := cl_guild_list('falk');
  assert jsonb_array_length(r) = 1, 'Suche findet die Gilde';
  gid := (r -> 0 ->> 'id')::bigint;
  r := cl_guild_join(gid);
  assert jsonb_array_length(r -> 'members') = 2 and r ->> 'role' = 'mitglied', 'beigetreten';
  begin perform cl_guild_manage('banner', null, 2); assert false, 'Mitglied ändert kein Banner'; exception when raise_exception then null; end;
end $$;
-- Siege zählen für die Gilde (über die Trigger)
reset role;
update profiles set last_claim = null;
set role authenticated;
do $$ declare r jsonb; g jsonb; xp0 int; begin
  g := cl_guild_mine();
  xp0 := (g ->> 'xp')::int;
  r := cl_claim_boss('essenwaechter', 90, 5);
  g := cl_guild_mine();
  assert (select (x ->> 'points')::int from jsonb_array_elements(g -> 'members') x where (x ->> 'me')::boolean) >= 5, 'Beitrag: Sieg + Marken';
  assert (g ->> 'xp')::int > xp0, 'Gilden-XP steigt';
  r := cl_tower(12);
  g := cl_guild_mine();
  raise notice 'GILDE info: Ziele %', g -> 'goals';
end $$;
-- Stufenaufstieg und Bonus-Marke ab Stufe 5
reset role;
select cl_guild_add('00000000-0000-0000-0000-000000000004', 'marks', 10000);
update profiles set last_claim = null;
set role authenticated;
do $$ declare g jsonb; m0 int; r jsonb; begin
  g := cl_guild_mine();
  assert (g ->> 'level')::int >= 5 and (g ->> 'slots')::int = 15 + 5 * ((g ->> 'level')::int - 1), 'Stufe steigt, mehr Plätze (Stufe ' || (g ->> 'level') || ')';
  assert (select bool_or((x ->> 'done')::boolean) from jsonb_array_elements(g -> 'goals') x) or not exists (select from jsonb_array_elements(g -> 'goals') x where x ->> 'goal' = 'marks'), 'Marken-Ziel erfüllt';
  select marks into m0 from profiles;
  r := cl_claim_boss('essenwaechter', 90, 5);
  assert (select marks from profiles) = m0 + 5, 'Gildenbonus: 4 + 1 Marke';
end $$;
-- Anführerin geht: Führung wandert weiter; letzte geht: Gilde weg
select set_config('test.uid', '00000000-0000-0000-0000-000000000003', false) \g /dev/null
do $$ declare g jsonb; begin
  perform cl_guild_leave();
end $$;
select set_config('test.uid', '00000000-0000-0000-0000-000000000004', false) \g /dev/null
do $$ declare g jsonb; begin
  g := cl_guild_mine();
  assert g ->> 'role' = 'anfuehrer', 'Führung weitergegeben';
  g := cl_guild_manage('banner', null, 3);
  assert (g ->> 'banner')::int = 3, 'Banner ab höherer Stufe frei';
  perform cl_guild_leave();
  assert jsonb_array_length(cl_guild_list('')) = 0, 'leere Gilde aufgelöst';
end $$;
-- direkt schreiben verboten
do $$ begin
  begin insert into guilds (name, tag) values ('Hack', 'HK'); assert false, 'Gilde direkt angelegt!';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
\echo GILDEN-TEST OK
