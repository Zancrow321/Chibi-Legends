-- Chibi Legends: Online-Basis (Endgame Schritt 3)
--
-- Konten (Supabase Auth, Gast oder E-Mail), Profil, Beute und Raid-Marken.
-- Der Server entscheidet alles, was wertvoll ist: ob Bonus-Beute fällt
-- (Tageschance), welche Seltenheit, welches Teil, wie viele Marken. Der
-- Client baut das Teil danach aus dem Seed (Loot.roll mit festem Zufall),
-- so bleiben Itemcode und Server getrennt aktuell.
--
-- Spieler können ihre Zeilen nur lesen; geschrieben wird ausschließlich über
-- die Funktionen unten (security definer). Wiederholt ausführbar.
--
-- Einspielen: Supabase-Dashboard -> SQL Editor -> Inhalt einfügen -> Run.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default 'Schüler',
  marks integer not null default 0 check (marks >= 0),
  last_claim timestamptz,
  created_at timestamptz not null default now()
);

-- Beute vom Server: das Teil selbst baut der Client aus seed + slot + rarity + ilvl.
create table if not exists public.drops (
  id bigint generated always as identity primary key,
  owner uuid not null references public.profiles (id) on delete cascade,
  source text not null,
  slot text not null,
  rarity smallint not null check (rarity between 0 and 5),
  ilvl integer not null check (ilvl between 1 and 999),
  seed bigint not null,
  created_at timestamptz not null default now()
);
create index if not exists drops_owner on public.drops (owner, created_at desc);

-- Siege pro Boss und Tag (Tageschance sinkt).
create table if not exists public.raid_kills (
  owner uuid not null references public.profiles (id) on delete cascade,
  boss text not null,
  day date not null,
  kills integer not null default 0,
  primary key (owner, boss, day)
);

-- Turm der Prüfungen: beste Etage pro Woche (Wochenwechsel Montag, UTC).
create table if not exists public.tower_records (
  owner uuid not null references public.profiles (id) on delete cascade,
  week date not null,
  best_floor integer not null default 0,
  reached_at timestamptz not null default now(),
  primary key (owner, week)
);

alter table public.profiles enable row level security;
alter table public.drops enable row level security;
alter table public.raid_kills enable row level security;
alter table public.tower_records enable row level security;

drop policy if exists "eigenes Profil lesen" on public.profiles;
create policy "eigenes Profil lesen" on public.profiles for select using (id = auth.uid());
drop policy if exists "eigene Beute lesen" on public.drops;
create policy "eigene Beute lesen" on public.drops for select using (owner = auth.uid());
drop policy if exists "eigene Siege lesen" on public.raid_kills;
create policy "eigene Siege lesen" on public.raid_kills for select using (owner = auth.uid());
drop policy if exists "Turm-Rekorde lesen" on public.tower_records;
create policy "Turm-Rekorde lesen" on public.tower_records for select using (true);

-- Regeln an einer Stelle (gleiche Werte wie scripts/raid/raid_loot.gd).
create or replace function public.cl_rules() returns jsonb
language sql immutable as $$
  select jsonb_build_object(
    'decay', 0.6, 'floor', 0.2,
    'marks', jsonb_build_object('essenwaechter', 4, 'turmwache', 1),
    -- kürzeste glaubhafte Kampfzeit in Sekunden
    'min_fight', jsonb_build_object('essenwaechter', 25, 'turmwache', 8),
    'price', jsonb_build_object('3', 20, '4', 60),
    -- Raid-Tabelle: Mythisch .. Ungewöhnlich (wie Loot.RAID_TABLE)
    'raid_table', jsonb_build_array(0.02, 0.07, 0.16, 0.25, 0.27),
    'kinds', jsonb_build_array('waffe', 'oberteil', 'hose', 'schuhe', 'accessoire', 'talisman'),
    'armor_pieces', jsonb_build_array('oberteil', 'hose', 'schuhe'),
    'max_level', 99
  )
$$;

create or replace function public.cl_week(t timestamptz default now()) returns date
language sql stable as $$ select date_trunc('week', t at time zone 'utc')::date $$;

-- Seltenheit aus einer Tabelle [Mythisch .. Ungewöhnlich], Rest Gewöhnlich.
create or replace function public.cl_pick_rarity(tbl jsonb, minimum int default 0) returns int
language plpgsql volatile as $$
declare r float8 := random(); acc float8 := 0; i int;
begin
  for i in 0 .. jsonb_array_length(tbl) - 1 loop
    acc := acc + (tbl ->> i)::float8;
    if r < acc then return greatest(5 - i, minimum); end if;
  end loop;
  return minimum;
end $$;

create or replace function public.cl_new_drop(p uuid, src text, kind text, rar int, lvl int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare k jsonb := cl_rules() -> 'kinds'; d public.drops;
begin
  if kind is null or kind = '' then
    kind := k ->> floor(random() * jsonb_array_length(k))::int;
  end if;
  insert into drops (owner, source, slot, rarity, ilvl, seed)
  values (p, src, kind, rar, greatest(1, least(lvl, 999)), floor(random() * 2147483647)::bigint)
  returning * into d;
  return jsonb_build_object('id', d.id, 'source', d.source, 'slot', d.slot, 'rarity', d.rarity, 'ilvl', d.ilvl, 'seed', d.seed);
end $$;

-- Profil anlegen (erster Login) und Stand holen.
create or replace function public.cl_state() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare p public.profiles;
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  insert into profiles (id) values (auth.uid()) on conflict (id) do nothing;
  select * into p from profiles where id = auth.uid();
  return jsonb_build_object('id', p.id, 'name', p.name, 'marks', p.marks,
    'drops', (select count(*) from drops where owner = p.id),
    'tower_week', coalesce((select best_floor from tower_records where owner = p.id and week = cl_week()), 0));
end $$;

-- Boss besiegt: Marken immer, Bonus-Beute mit sinkender Tageschance.
-- fight_seconds und level kommen vom Client und werden nur grob geprüft,
-- bis der Kampfserver (Schritt 4/5) die Kämpfe selbst beobachtet.
create or replace function public.cl_claim_boss(boss text, fight_seconds int, level int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  rules jsonb := cl_rules();
  p public.profiles;
  n int;
  chance float8;
  bonus boolean;
  m int;
  lvl int;
  out_drops jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  if not (rules -> 'marks') ? boss then raise exception 'unbekannter Boss %', boss; end if;
  if fight_seconds < (rules -> 'min_fight' ->> boss)::int then
    raise exception 'Kampf zu kurz';
  end if;
  insert into profiles (id) values (auth.uid()) on conflict (id) do nothing;
  select * into p from profiles where id = auth.uid() for update;
  if p.last_claim is not null and now() - p.last_claim < make_interval(secs => (rules -> 'min_fight' ->> boss)::int) then
    raise exception 'zu schnell hintereinander';
  end if;
  insert into raid_kills (owner, boss, day, kills) values (p.id, boss, current_date, 0)
    on conflict do nothing;
  select kills into n from raid_kills where owner = p.id and raid_kills.boss = cl_claim_boss.boss and day = current_date for update;
  chance := greatest((rules ->> 'floor')::float8, power((rules ->> 'decay')::float8, n));
  bonus := random() < chance;
  m := (rules -> 'marks' ->> boss)::int;
  lvl := greatest(1, least(level, (rules ->> 'max_level')::int));
  update raid_kills set kills = kills + 1 where owner = p.id and raid_kills.boss = cl_claim_boss.boss and day = current_date;
  update profiles set marks = marks + m, last_claim = now() where id = p.id;
  if boss = 'essenwaechter' and bonus then
    -- ein Teil ab Episch und ein Teil der Essenwacht-Rüstung (jede Seltenheit, wie RaidArmor)
    out_drops := out_drops || cl_new_drop(p.id, boss, null, cl_pick_rarity(rules -> 'raid_table', 3), lvl);
    out_drops := out_drops || cl_new_drop(p.id, 'essenwacht',
      rules -> 'armor_pieces' ->> floor(random() * jsonb_array_length(rules -> 'armor_pieces'))::int,
      cl_pick_rarity(rules -> 'raid_table', 0), lvl);
  elsif boss = 'turmwache' then
    out_drops := out_drops || cl_new_drop(p.id, boss, null, cl_pick_rarity(rules -> 'raid_table', 2), lvl);
  end if;
  return jsonb_build_object('marks', m, 'total_marks', p.marks + m, 'chance', chance, 'bonus', bonus,
    'kills_today', n + 1, 'drops', out_drops);
end $$;

-- Raid-Marken gegen ein Wunschteil (Episch 3 / Legendär 4).
create or replace function public.cl_buy(kind text, rarity int, level int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare rules jsonb := cl_rules(); price int; p public.profiles;
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  if not (rules -> 'kinds') ? kind then raise exception 'unbekannte Teil-Art %', kind; end if;
  price := (rules -> 'price' ->> rarity::text)::int;
  if price is null then raise exception 'nicht im Angebot'; end if;
  select * into p from profiles where id = auth.uid() for update;
  if p.id is null or p.marks < price then raise exception 'zu wenig Raid-Marken'; end if;
  update profiles set marks = marks - price where id = p.id;
  return jsonb_build_object('total_marks', p.marks - price,
    'drop', cl_new_drop(p.id, 'marken', kind, rarity, greatest(1, least(level, (rules ->> 'max_level')::int))));
end $$;

-- Turm: neue Etage melden (nur höher zählt), Platz in der Wochenliste zurück.
create or replace function public.cl_tower(floor_reached int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare w date := cl_week(); best int; place int;
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  if floor_reached < 1 or floor_reached > 999 then raise exception 'ungültige Etage'; end if;
  insert into profiles (id) values (auth.uid()) on conflict (id) do nothing;
  insert into tower_records (owner, week, best_floor) values (auth.uid(), w, floor_reached)
  on conflict (owner, week) do update
    set best_floor = greatest(tower_records.best_floor, excluded.best_floor),
        reached_at = case when excluded.best_floor > tower_records.best_floor then now() else tower_records.reached_at end;
  select best_floor into best from tower_records where owner = auth.uid() and week = w;
  select count(*) + 1 into place from tower_records t
    where t.week = w and (t.best_floor > best or (t.best_floor = best and t.reached_at < (select reached_at from tower_records where owner = auth.uid() and week = w)));
  return jsonb_build_object('week', w, 'best', best, 'place', place);
end $$;

-- Wochen-Bestenliste (Top 50) mit Namen.
create or replace function public.cl_tower_board() returns table (place bigint, name text, best_floor int)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by t.best_floor desc, t.reached_at), p.name, t.best_floor
  from tower_records t join profiles p on p.id = t.owner
  where t.week = cl_week()
  order by t.best_floor desc, t.reached_at
  limit 50
$$;

-- Anzeigename ändern (3-16 Zeichen).
create or replace function public.cl_set_name(new_name text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  new_name := btrim(new_name);
  if char_length(new_name) < 3 or char_length(new_name) > 16 then raise exception 'Name braucht 3 bis 16 Zeichen'; end if;
  insert into profiles (id, name) values (auth.uid(), new_name)
    on conflict (id) do update set name = excluded.name;
  return jsonb_build_object('name', new_name);
end $$;

-- Tabellen nur lesen (Supabase gibt anon/authenticated sonst volle Rechte).
revoke insert, update, delete, truncate on public.profiles, public.drops, public.raid_kills, public.tower_records from anon, authenticated;

-- Nur angemeldete Spieler dürfen die Funktionen aufrufen; Hilfsfunktionen gar nicht.
revoke all on function public.cl_new_drop(uuid, text, text, int, int) from public, anon, authenticated;
revoke all on function public.cl_state() from public, anon;
revoke all on function public.cl_claim_boss(text, int, int) from public, anon;
revoke all on function public.cl_buy(text, int, int) from public, anon;
revoke all on function public.cl_tower(int) from public, anon;
revoke all on function public.cl_set_name(text) from public, anon;
grant execute on function public.cl_state() to authenticated;
grant execute on function public.cl_claim_boss(text, int, int) to authenticated;
grant execute on function public.cl_buy(text, int, int) to authenticated;
grant execute on function public.cl_tower(int) to authenticated;
grant execute on function public.cl_set_name(text) to authenticated;
grant execute on function public.cl_tower_board() to anon, authenticated;
