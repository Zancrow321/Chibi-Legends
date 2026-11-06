-- Chibi Legends: Weltbosse (Endgame Schritt 8, ohne Kampfserver)
--
-- Ein Weltboss hat EINE Lebensleiste für alle Spieler. Jeder kämpft in
-- seiner eigenen Arena gegen ihn, das Spiel meldet den Schaden alle paar
-- Sekunden (cl_world_hit) und holt den gemeinsamen Stand (cl_world_state).
-- Der Server deckelt den Schaden pro Sekunde, damit niemand schummelt.
-- Fällt der Boss, holt sich jeder mit genug Beitrag seine Beute
-- (cl_world_claim). Danach öffnet sich der Riss nach einer Pause neu, mit
-- mehr Lebenspunkten, je mehr Spieler beim letzten Mal mitgemacht haben.
--
-- Braucht 0001_online_base.sql (und 0002 für die Gilden-Trigger auf den
-- Raid-Marken). Wiederholt ausführbar.
-- Einspielen: Supabase-Dashboard -> SQL Editor -> Inhalt einfügen -> Run.

create table if not exists public.world_bosses (
  id bigint generated always as identity primary key,
  boss text not null,
  max_hp bigint not null check (max_hp > 0),
  hp bigint not null check (hp >= 0),
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  defeated_at timestamptz,
  last_hit_by uuid references public.profiles (id) on delete set null
);

create table if not exists public.world_hits (
  boss_id bigint not null references public.world_bosses (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  damage bigint not null default 0,
  reports integer not null default 0,
  last_report timestamptz not null default now(),
  claimed boolean not null default false,
  primary key (boss_id, user_id)
);
create index if not exists world_hits_rank on public.world_hits (boss_id, damage desc);

alter table public.world_bosses enable row level security;
alter table public.world_hits enable row level security;
drop policy if exists "Weltbosse lesen" on public.world_bosses;
create policy "Weltbosse lesen" on public.world_bosses for select using (true);
drop policy if exists "Weltboss-Treffer lesen" on public.world_hits;
create policy "Weltboss-Treffer lesen" on public.world_hits for select using (true);
revoke insert, update, delete, truncate on public.world_bosses, public.world_hits from anon, authenticated;

-- Regeln (gleiche Werte wie scripts/raid/world_boss_rules.gd)
create or replace function public.cl_world_rules() returns jsonb
language sql immutable set search_path = public as $$
  select jsonb_build_object(
    'bosses', jsonb_build_array('donnerhorn'),
    'hp_per_fighter', 60000,     -- Lebenspunkte je Spieler der letzten Runde
    'max_fighters', 40,
    'lifetime_hours', 72,        -- so lange bleibt er, dann zieht er weiter
    'respawn_minutes', 20,       -- Pause nach Sieg oder Flucht
    'report_max', 60,            -- längstes Meldefenster in Sekunden
    'dps_cap', 1500,             -- mehr Schaden pro Sekunde glaubt der Server nicht
    'min_share', 0.005,          -- ab 0,5 % der Lebenspunkte gibt es Beute
    'marks', 4, 'marks_share', 4, 'marks_last_hit', 2
  )
$$;

-- Aktueller Weltboss; legt einen neuen an, wenn keiner da ist, der alte
-- geflohen ist oder die Pause nach dem Sieg vorbei ist.
create or replace function public.cl_world_current() returns public.world_bosses
language plpgsql volatile security definer set search_path = public as $$
declare b public.world_bosses; r jsonb := cl_world_rules(); n int; pool jsonb := r -> 'bosses';
begin
  select * into b from world_bosses order by id desc limit 1;
  if b.id is not null and ((b.defeated_at is null and now() < b.ends_at)
     or now() < coalesce(b.defeated_at, b.ends_at) + make_interval(mins => (r ->> 'respawn_minutes')::int)) then
    return b;
  end if;
  perform pg_advisory_xact_lock(4242);
  select * into b from world_bosses order by id desc limit 1;  -- jemand anderes war schneller?
  if b.id is not null and ((b.defeated_at is null and now() < b.ends_at)
     or now() < coalesce(b.defeated_at, b.ends_at) + make_interval(mins => (r ->> 'respawn_minutes')::int)) then
    return b;
  end if;
  n := 1;
  if b.id is not null then
    select greatest(1, least(count(*), (r ->> 'max_fighters')::int)) into n from world_hits where boss_id = b.id and damage > 0;
  end if;
  insert into world_bosses (boss, max_hp, hp, ends_at)
  values (pool ->> ((coalesce(b.id, 0) % jsonb_array_length(pool))::int),
          n * (r ->> 'hp_per_fighter')::bigint, n * (r ->> 'hp_per_fighter')::bigint,
          now() + make_interval(hours => (r ->> 'lifetime_hours')::int))
  returning * into b;
  return b;
end $$;

-- Stand für den Bildschirm: Lebensleiste, Bestenliste, eigener Beitrag.
create or replace function public.cl_world_state() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare b public.world_bosses; r jsonb := cl_world_rules(); h public.world_hits; st text; rank int;
begin
  b := cl_world_current();
  st := case when b.defeated_at is not null then 'besiegt' when now() >= b.ends_at then 'geflohen' else 'aktiv' end;
  select * into h from world_hits where boss_id = b.id and user_id = auth.uid();
  if h.damage > 0 then
    select count(*) + 1 into rank from world_hits where boss_id = b.id and damage > h.damage;
  end if;
  return jsonb_build_object(
    'id', b.id, 'boss', b.boss, 'hp', b.hp, 'max_hp', b.max_hp, 'state', st,
    'ends_at', b.ends_at, 'next_at', coalesce(b.defeated_at, b.ends_at) + make_interval(mins => (r ->> 'respawn_minutes')::int),
    'next_in', greatest(0, ceil(extract(epoch from coalesce(b.defeated_at, b.ends_at) + make_interval(mins => (r ->> 'respawn_minutes')::int) - now())))::int,
    'ends_in', greatest(0, ceil(extract(epoch from b.ends_at - now())))::int,
    'fighters_now', (select count(*) from world_hits where boss_id = b.id and last_report > now() - interval '45 seconds'),
    'fighters', (select count(*) from world_hits where boss_id = b.id and damage > 0),
    'my_damage', coalesce(h.damage, 0), 'my_rank', coalesce(rank, 0),
    'claimable', st = 'besiegt' and coalesce(h.damage, 0) >= b.max_hp * (r ->> 'min_share')::float8 and not coalesce(h.claimed, true),
    'claimed', coalesce(h.claimed, false),
    'last_hit', (select name from profiles where id = b.last_hit_by),
    'top', (select coalesce(jsonb_agg(jsonb_build_object('name', p.name, 'damage', w.damage, 'me', w.user_id = auth.uid())
                                       order by w.damage desc), '[]')
            from (select * from world_hits where boss_id = b.id and damage > 0 order by damage desc limit 8) w
            join profiles p on p.id = w.user_id));
end $$;

-- Schaden melden: höchstens dps_cap pro Sekunde seit der letzten Meldung.
create or replace function public.cl_world_hit(boss_id bigint, damage bigint, seconds int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  r jsonb := cl_world_rules(); b public.world_bosses; h public.world_hits;
  win float8; allowed bigint;
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  if damage < 0 or seconds < 1 then raise exception 'ungültige Meldung'; end if;
  insert into profiles (id) values (auth.uid()) on conflict (id) do nothing;
  select * into b from world_bosses where id = cl_world_hit.boss_id for update;
  if b.id is null then raise exception 'Diesen Weltboss gibt es nicht'; end if;
  if b.defeated_at is not null or now() >= b.ends_at then
    return cl_world_state() || jsonb_build_object('accepted', 0);
  end if;
  select * into h from world_hits w where w.boss_id = b.id and w.user_id = auth.uid() for update;
  win := least(seconds, (r ->> 'report_max')::int)::float8;
  if h.user_id is not null then
    win := least(win, extract(epoch from now() - h.last_report) + 1.0);
  end if;
  allowed := least(damage, floor(greatest(win, 0.0) * (r ->> 'dps_cap')::int)::bigint, b.hp);
  insert into world_hits (boss_id, user_id, damage, reports, last_report)
  values (b.id, auth.uid(), allowed, 1, now())
  on conflict on constraint world_hits_pkey do update
    set damage = world_hits.damage + excluded.damage, reports = world_hits.reports + 1, last_report = now();
  update world_bosses set hp = hp - allowed,
    defeated_at = case when hp - allowed <= 0 then now() else null end,
    last_hit_by = case when hp - allowed <= 0 then auth.uid() else last_hit_by end
  where id = b.id;
  return cl_world_state() || jsonb_build_object('accepted', allowed);
end $$;

-- Beute nach dem Sieg (einmal pro Boss und Spieler).
create or replace function public.cl_world_claim(boss_id bigint, level int) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  r jsonb := cl_world_rules(); rules jsonb := cl_rules(); b public.world_bosses; h public.world_hits;
  share float8; rank int; m int; lvl int; out_drops jsonb := '[]'::jsonb; p public.profiles;
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  select * into b from world_bosses where id = cl_world_claim.boss_id;
  if b.id is null or b.defeated_at is null then raise exception 'Der Weltboss ist noch nicht besiegt'; end if;
  select * into h from world_hits w where w.boss_id = b.id and w.user_id = auth.uid() for update;
  if h.user_id is null or h.claimed then raise exception 'Keine Beute offen'; end if;
  share := h.damage::float8 / b.max_hp;
  if share < (r ->> 'min_share')::float8 then raise exception 'Zu wenig Beitrag für Beute'; end if;
  select count(*) + 1 into rank from world_hits w where w.boss_id = b.id and w.damage > h.damage;
  lvl := greatest(1, least(level, (rules ->> 'max_level')::int));
  m := (r ->> 'marks')::int + round(least(share, 0.5) * 2.0 * (r ->> 'marks_share')::int)::int
     + case when b.last_hit_by = auth.uid() then (r ->> 'marks_last_hit')::int else 0 end;
  update world_hits w set claimed = true where w.boss_id = b.id and w.user_id = auth.uid();
  update profiles set marks = marks + m where id = auth.uid() returning * into p;
  -- ein Teil ab Episch für alle, ein zweites für die drei Besten oder ab 10 % Anteil
  out_drops := out_drops || cl_new_drop(auth.uid(), b.boss, null, cl_pick_rarity(rules -> 'raid_table', 3), lvl);
  if rank <= 3 or share >= 0.1 then
    out_drops := out_drops || cl_new_drop(auth.uid(), b.boss, null, cl_pick_rarity(rules -> 'raid_table', 2), lvl);
  end if;
  return jsonb_build_object('marks', m, 'total_marks', p.marks, 'rank', rank, 'share', share,
    'last_hit', b.last_hit_by = auth.uid(), 'drops', out_drops);
end $$;

revoke all on function public.cl_world_current() from public, anon, authenticated;
revoke all on function public.cl_world_state() from public, anon;
revoke all on function public.cl_world_hit(bigint, bigint, int) from public, anon;
revoke all on function public.cl_world_claim(bigint, int) from public, anon;
grant execute on function public.cl_world_state() to authenticated;
grant execute on function public.cl_world_hit(bigint, bigint, int) to authenticated;
grant execute on function public.cl_world_claim(bigint, int) to authenticated;
