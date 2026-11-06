-- Local test of 0001_online_base.sql:
--   supabase/test/run.sh  (starts a throwaway Postgres 16, prints ONLINE-TEST OK)
\set ON_ERROR_STOP on
insert into auth.users values ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002');
grant select on all tables in schema public to anon, authenticated;
set role authenticated;
select set_config('test.uid', '00000000-0000-0000-0000-000000000001', false);

create temp table chances (n serial, chance float8, bonus boolean, drops int, min_rarity int);
grant all on chances to authenticated;
grant usage on sequence chances_n_seq to authenticated;
do $$ declare r jsonb; begin
  r := cl_state();
  assert (r ->> 'marks')::int = 0, 'neues Profil ohne Marken';
  begin
    perform cl_claim_boss('essenwaechter', 5, 10);
    assert false, 'kurzer Kampf hätte scheitern müssen';
  exception when raise_exception then null; end;
end $$;
reset role;
update profiles set last_claim = null;  -- Wartezeit im Test überspringen
set role authenticated;
do $$ declare r jsonb; begin
  r := cl_claim_boss('essenwaechter', 90, 10);
  insert into chances (chance, bonus, drops, min_rarity) values ((r ->> 'chance')::float8, (r ->> 'bonus')::boolean,
    jsonb_array_length(r -> 'drops'), (select min((d ->> 'rarity')::int) from jsonb_array_elements(r -> 'drops') d where d ->> 'source' = 'essenwaechter'));
end $$;
reset role;
update profiles set last_claim = null;  -- Wartezeit im Test überspringen
set role authenticated;
do $$ declare r jsonb; begin
  r := cl_claim_boss('essenwaechter', 90, 10);
  insert into chances (chance, bonus, drops, min_rarity) values ((r ->> 'chance')::float8, (r ->> 'bonus')::boolean,
    jsonb_array_length(r -> 'drops'), (select min((d ->> 'rarity')::int) from jsonb_array_elements(r -> 'drops') d where d ->> 'source' = 'essenwaechter'));
end $$;
reset role;
update profiles set last_claim = null;  -- Wartezeit im Test überspringen
set role authenticated;
do $$ declare r jsonb; begin
  r := cl_claim_boss('essenwaechter', 90, 10);
  insert into chances (chance, bonus, drops, min_rarity) values ((r ->> 'chance')::float8, (r ->> 'bonus')::boolean,
    jsonb_array_length(r -> 'drops'), (select min((d ->> 'rarity')::int) from jsonb_array_elements(r -> 'drops') d where d ->> 'source' = 'essenwaechter'));
end $$;
reset role;
update profiles set last_claim = null;  -- Wartezeit im Test überspringen
set role authenticated;
do $$ declare r jsonb; begin
  r := cl_claim_boss('essenwaechter', 90, 10);
  insert into chances (chance, bonus, drops, min_rarity) values ((r ->> 'chance')::float8, (r ->> 'bonus')::boolean,
    jsonb_array_length(r -> 'drops'), (select min((d ->> 'rarity')::int) from jsonb_array_elements(r -> 'drops') d where d ->> 'source' = 'essenwaechter'));
end $$;
reset role;
update profiles set last_claim = null;  -- Wartezeit im Test überspringen
set role authenticated;
do $$ declare r jsonb; begin
  r := cl_claim_boss('essenwaechter', 90, 10);
  insert into chances (chance, bonus, drops, min_rarity) values ((r ->> 'chance')::float8, (r ->> 'bonus')::boolean,
    jsonb_array_length(r -> 'drops'), (select min((d ->> 'rarity')::int) from jsonb_array_elements(r -> 'drops') d where d ->> 'source' = 'essenwaechter'));
end $$;
reset role;
update profiles set last_claim = null;  -- Wartezeit im Test überspringen
set role authenticated;
do $$ declare r jsonb; begin
  r := cl_claim_boss('essenwaechter', 90, 10);
  insert into chances (chance, bonus, drops, min_rarity) values ((r ->> 'chance')::float8, (r ->> 'bonus')::boolean,
    jsonb_array_length(r -> 'drops'), (select min((d ->> 'rarity')::int) from jsonb_array_elements(r -> 'drops') d where d ->> 'source' = 'essenwaechter'));
end $$;
do $$ declare r jsonb; c float8[]; marks int; begin
  select array_agg(chance order by n) into c from chances;
  raise notice 'ONLINE info: Chancen %', c;
  assert abs(c[1] - 1.0) < 1e-9 and abs(c[2] - 0.6) < 1e-9 and abs(c[3] - 0.36) < 1e-9 and abs(c[6] - 0.2) < 1e-9, 'Tageschance sinkt';
  assert not exists (select from chances where bonus and (drops <> 2 or min_rarity < 3)), 'Bonus = 2 Teile (eins ab Episch, eins Essenwacht)';
  assert not exists (select from chances where not bonus and drops <> 0), 'ohne Bonus keine Teile';
  select p.marks into marks from profiles p;
  assert marks = 24, 'Marken: 6 x 4';
  begin
    perform cl_claim_boss('essenwaechter', 90, 10);
    assert false, 'Spam hätte scheitern müssen';
  exception when raise_exception then null; end;
  r := cl_buy('schuhe', 3, 10);
  assert (r ->> 'total_marks')::int = 4 and r -> 'drop' ->> 'slot' = 'schuhe' and (r -> 'drop' ->> 'rarity')::int = 3, 'Tausch Episch';
  begin
    perform cl_buy('waffe', 4, 10);
    assert false, 'zu wenig Marken';
  exception when raise_exception then null; end;
  r := cl_tower(7);
  r := cl_tower(5);
  assert (r ->> 'best')::int = 7 and (r ->> 'place')::int = 1, 'Turm: nur höher zählt';
  perform cl_set_name('Kaiser');
  raise notice 'ONLINE info: Beute %', (select count(*) from drops);
end $$;

-- direkt schreiben ist verboten
do $$ begin
  begin
    update profiles set marks = 9999;
    assert (select marks from profiles) < 9999, 'Marken direkt geändert!';
  exception when insufficient_privilege then null; end;
  begin
    insert into drops (owner, source, slot, rarity, ilvl, seed) values (auth.uid(), 'x', 'waffe', 5, 99, 1);
    assert false, 'Beute direkt eingefügt!';
  exception when insufficient_privilege then null; end;
end $$;

-- zweiter Spieler sieht fremde Beute nicht, aber die Bestenliste
select set_config('test.uid', '00000000-0000-0000-0000-000000000002', false);
do $$ declare r jsonb; begin
  assert (select count(*) from drops) = 0, 'fremde Beute sichtbar!';
  r := cl_tower(9);
  assert (r ->> 'place')::int = 1, 'Spieler 2 vorne';
  assert (select count(*) from cl_tower_board()) = 2, 'Bestenliste mit 2 Spielern';
  assert (select name from cl_tower_board() where place = 2) = 'Kaiser', 'Name in der Liste';
end $$;
reset role;
\echo ONLINE-TEST OK
