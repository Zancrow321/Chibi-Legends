-- Local test of 0003_world_boss.sql (runs after test_1 and test_2 on the same DB).
\set ON_ERROR_STOP on
reset role;
grant select on all tables in schema public to anon, authenticated;
insert into auth.users values ('00000000-0000-0000-0000-000000000005'), ('00000000-0000-0000-0000-000000000006')
  on conflict do nothing;
set role authenticated;
select set_config('test.uid', '00000000-0000-0000-0000-000000000005', false) \g /dev/null
do $$ declare s jsonb; r jsonb; begin
  perform cl_set_name('Riesentöter');
  s := cl_world_state();
  assert s ->> 'state' = 'aktiv' and s ->> 'boss' = 'donnerhorn', 'Weltboss da';
  assert (s ->> 'max_hp')::bigint = 60000 and (s ->> 'hp')::bigint = 60000, 'erste Runde: 60000 LP';
  assert (cl_world_state() ->> 'id') = (s ->> 'id'), 'gleicher Boss beim zweiten Abruf';
  -- erste Meldung: 10 s, 5000 Schaden (glaubhaft)
  r := cl_world_hit((s ->> 'id')::bigint, 5000, 10);
  assert (r ->> 'accepted')::bigint = 5000 and (r ->> 'hp')::bigint = 55000, 'Schaden zählt';
  assert (r ->> 'my_damage')::bigint = 5000 and (r ->> 'my_rank')::int = 1, 'eigener Beitrag, Platz 1';
  -- gleich danach 1 000 000 Schaden: der Server glaubt nur ~1 s * 1500
  r := cl_world_hit((s ->> 'id')::bigint, 1000000, 60);
  assert (r ->> 'accepted')::bigint <= 3000, 'Schummel-Schaden gedeckelt (' || (r ->> 'accepted') || ')';
  begin perform cl_world_claim((s ->> 'id')::bigint, 10); assert false, 'noch nicht besiegt'; exception when raise_exception then null; end;
end $$;
-- zweite Spielerin, kleiner Beitrag
select set_config('test.uid', '00000000-0000-0000-0000-000000000006', false) \g /dev/null
do $$ declare s jsonb; r jsonb; begin
  perform cl_set_name('Mitläuferin');
  s := cl_world_state();
  r := cl_world_hit((s ->> 'id')::bigint, 100, 5);
  assert (r ->> 'my_rank')::int = 2 and (r ->> 'fighters')::int = 2, 'zwei Kämpfer, Platz 2';
end $$;
-- Zeit vergeht: die erste Spielerin schlägt ihn nieder
reset role;
update world_hits set last_report = now() - interval '60 seconds';
set role authenticated;
select set_config('test.uid', '00000000-0000-0000-0000-000000000005', false) \g /dev/null
do $$ declare s jsonb; r jsonb; m0 int; i int; begin
  s := cl_world_state();
  for i in 1 .. 2 loop
    r := cl_world_hit((s ->> 'id')::bigint, 90000, 60);
    exit when r ->> 'state' = 'besiegt';
    reset role;  -- nächste Minute
    update world_hits set last_report = now() - interval '60 seconds';
    set role authenticated;
  end loop;
  assert r ->> 'state' = 'besiegt' and (r ->> 'hp')::bigint = 0, 'Weltboss besiegt (' || (r ->> 'hp') || ')';
  assert r ->> 'last_hit' = 'Riesentöter' and (r ->> 'claimable')::boolean, 'letzter Schlag, Beute offen';
  begin perform cl_world_hit((s ->> 'id')::bigint, 10, 5); exception when others then assert false, 'Meldung nach dem Sieg wirft nicht'; end;
  select marks into m0 from profiles where id = auth.uid();
  r := cl_world_claim((s ->> 'id')::bigint, 12);
  assert jsonb_array_length(r -> 'drops') = 2 and (r -> 'drops' -> 0 ->> 'rarity')::int >= 3, 'zwei Teile, erstes ab Episch';
  assert (r -> 'drops' -> 0 ->> 'source') = 'donnerhorn', 'Quelle Donnerhorn';
  assert (r ->> 'marks')::int = 4 + 4 + 2 and (select marks from profiles where id = auth.uid()) = m0 + 10, 'Marken: Grund + Anteil + letzter Schlag';
  begin perform cl_world_claim((s ->> 'id')::bigint, 12); assert false, 'nur einmal'; exception when raise_exception then null; end;
end $$;
-- zu wenig Beitrag: keine Beute
select set_config('test.uid', '00000000-0000-0000-0000-000000000006', false) \g /dev/null
do $$ declare s jsonb; begin
  s := cl_world_state();
  assert not (s ->> 'claimable')::boolean, '100 von 60000 reicht nicht';
  begin perform cl_world_claim((s ->> 'id')::bigint, 12); assert false, 'keine Beute'; exception when raise_exception then null; end;
end $$;
-- Pause vorbei: neuer Boss mit mehr Lebenspunkten (2 Kämpfer)
reset role;
update world_bosses set defeated_at = now() - interval '1 hour';
set role authenticated;
do $$ declare s jsonb; begin
  s := cl_world_state();
  assert s ->> 'state' = 'aktiv' and (s ->> 'max_hp')::bigint = 120000 and (s ->> 'my_damage')::bigint = 0, 'neuer Boss, 2 x 60000 LP';
end $$;
-- Nicht angemeldet: keine Meldungen
reset role;
set role anon;
do $$ begin
  begin perform cl_world_hit(1, 10, 5); assert false, 'anon darf nicht melden'; exception when insufficient_privilege then null; end;
end $$;
reset role;
\echo WELTBOSS-TEST OK
