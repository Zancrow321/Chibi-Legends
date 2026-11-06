-- Local test of 0004_god_items.sql (runs after tests 1-3 on the same DB).
\set ON_ERROR_STOP on
reset role;
grant select on all tables in schema public to anon, authenticated;
insert into auth.users values ('00000000-0000-0000-0000-000000000007'), ('00000000-0000-0000-0000-000000000008')
  on conflict do nothing;
-- 48 Teile, alle frei (Tests vorher vergeben keins)
do $$ begin
  assert (select count(*) from god_items) = 48, '48 GOD-Teile';
  assert (select count(*) from god_items where owner is null) = 48, 'alle frei';
end $$;
set role authenticated;
select set_config('test.uid', '00000000-0000-0000-0000-000000000007', false) \g /dev/null
do $$ declare r jsonb; begin
  perform cl_set_name('Seraphin');
  assert jsonb_array_length(cl_god_mine()) = 0, 'noch nichts';
  assert jsonb_array_length(cl_god_hall()) = 48, 'Halle zeigt alle';
  -- ohne Sieg kein Wurf
  begin perform cl_god_roll('raid', 'x'); assert false, 'Raid ohne Sieg'; exception when raise_exception then null; end;
  begin perform cl_god_roll('tower', '15'); assert false, 'Etage 15 zählt nicht'; exception when raise_exception then null; end;
  begin perform cl_god_roll('tower', '20'); assert false, 'Etage 20 nicht erreicht'; exception when raise_exception then null; end;
  begin perform cl_god_roll('world', '999999'); assert false, 'fremder Weltboss'; exception when raise_exception then null; end;
  begin perform cl_god_roll('kiste', '1'); assert false, 'unbekannte Quelle'; exception when raise_exception then null; end;
  -- Turm Etage 30 erreicht: Etage 20 und 30 würfeln je einmal
  perform cl_tower(30);
  r := cl_god_roll('tower', '20');
  assert r ? 'won' and not (r ? 'already'), 'Wurf Etage 20';
  r := cl_god_roll('tower', '20');
  assert (r ->> 'already')::boolean, 'Etage 20 nur einmal';
  r := cl_god_roll('tower', '30');
  assert not (r ? 'already'), 'Wurf Etage 30';
  begin perform cl_god_roll('tower', '40'); assert false, 'Etage 40 nicht erreicht'; exception when raise_exception then null; end;
  -- direkt schreiben verboten, interne Vergabe nicht aufrufbar
  begin
    update god_items set owner = auth.uid();
    assert (select count(*) from god_items where owner = auth.uid()) <= 2, 'GOD-Teile direkt genommen!';
  exception when insufficient_privilege then null; end;
  begin perform cl_god_give(auth.uid(), 'x'); assert false, 'interne Vergabe aufrufbar!'; exception when insufficient_privilege then null; end;
end $$;
-- Einmaligkeit: der Server vergibt jedes Teil genau einmal, dann ist Schluss
reset role;
update god_items set owner = null, source = null, obtained_at = null;
insert into profiles (id) values ('00000000-0000-0000-0000-000000000008') on conflict do nothing;
do $$ declare i int; got text; n int := 0; begin
  for i in 1 .. 30 loop
    got := cl_god_give('00000000-0000-0000-0000-000000000007', 'test');
    if got is not null then n := n + 1; end if;
  end loop;
  for i in 1 .. 30 loop
    got := cl_god_give('00000000-0000-0000-0000-000000000008', 'test');
    if got is not null then n := n + 1; end if;
  end loop;
  assert n = 48, 'genau 48 vergeben, nicht ' || n;
  assert cl_god_give('00000000-0000-0000-0000-000000000008', 'test') is null, 'alle weg';
  assert (select count(distinct item) from god_items where owner is not null) = 48, 'keins doppelt';
end $$;
set role authenticated;
select set_config('test.uid', '00000000-0000-0000-0000-000000000008', false) \g /dev/null
do $$ declare h jsonb; begin
  perform cl_set_name('Abgrund');
  assert jsonb_array_length(cl_god_mine()) = 18, 'zweite Person hat den Rest (18)';
  h := cl_god_hall();
  assert (select count(*) from jsonb_array_elements(h) e where e ->> 'owner' = 'Seraphin') = 30, 'Halle nennt Besitzer';
  assert (select count(*) from jsonb_array_elements(h) e where (e ->> 'mine')::boolean) = 18, 'eigene markiert';
end $$;
-- Konto weg: Teile werden wieder frei
reset role;
delete from profiles where id = '00000000-0000-0000-0000-000000000008';
do $$ begin
  assert (select count(*) from god_items where owner is null) = 18, 'Teile des gelöschten Kontos frei';
end $$;
update god_items set owner = null, source = null, obtained_at = null;
\echo GOD-TEST OK
