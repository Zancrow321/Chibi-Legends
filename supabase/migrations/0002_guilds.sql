-- Chibi Legends: Gilden (Endgame Schritt 6)
--
-- Gilde gründen, beitreten, verlassen; Stufen 1-10 (Plätze 15 -> 60),
-- drei Wochenziele pro Gilde, Beiträge der Mitglieder, kleine Boni und
-- Banner-Farben. Fortschritt zählt der Server selbst mit (Trigger auf den
-- Tabellen aus 0001): Boss-Siege, Turm-Etagen, Raid-Marken.
-- Gilden-Kriege (4v4) brauchen den Kampfserver und kommen später.
--
-- Braucht 0001_online_base.sql. Wiederholt ausführbar.
-- Einspielen: Supabase-Dashboard -> SQL Editor -> Inhalt einfügen -> Run.

-- kleine Härtung aus 0001: feste search_path auch für die Hilfsfunktionen
alter function public.cl_rules() set search_path = public;
alter function public.cl_week(timestamptz) set search_path = public;
alter function public.cl_pick_rarity(jsonb, int) set search_path = public;

create table if not exists public.guilds (
  id bigint generated always as identity primary key,
  name text not null,
  tag text not null,
  banner smallint not null default 0,
  level smallint not null default 1 check (level between 1 and 10),
  xp integer not null default 0,
  trophies integer not null default 0,  -- erfüllte Wochenziele (Deko in der Halle)
  created_at timestamptz not null default now()
);
create unique index if not exists guilds_name on public.guilds (lower(name));
create unique index if not exists guilds_tag on public.guilds (upper(tag));

create table if not exists public.guild_members (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  guild_id bigint not null references public.guilds (id) on delete cascade,
  role text not null default 'mitglied' check (role in ('anfuehrer', 'offizier', 'mitglied')),
  joined_at timestamptz not null default now()
);
create index if not exists guild_members_guild on public.guild_members (guild_id);

-- Wochenziele: drei pro Gilde und Woche, aus cl_guild_goal_pool()
create table if not exists public.guild_goals (
  guild_id bigint not null references public.guilds (id) on delete cascade,
  week date not null,
  goal text not null,
  target integer not null,
  progress integer not null default 0,
  done boolean not null default false,
  primary key (guild_id, week, goal)
);

-- Beiträge pro Mitglied und Woche (Bestenliste in der Gilde)
create table if not exists public.guild_points (
  guild_id bigint not null references public.guilds (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  week date not null,
  points integer not null default 0,
  primary key (guild_id, user_id, week)
);

alter table public.guilds enable row level security;
alter table public.guild_members enable row level security;
alter table public.guild_goals enable row level security;
alter table public.guild_points enable row level security;
drop policy if exists "Gilden lesen" on public.guilds;
create policy "Gilden lesen" on public.guilds for select using (true);
drop policy if exists "Mitglieder lesen" on public.guild_members;
create policy "Mitglieder lesen" on public.guild_members for select using (true);
drop policy if exists "Ziele lesen" on public.guild_goals;
create policy "Ziele lesen" on public.guild_goals for select using (true);
drop policy if exists "Beiträge lesen" on public.guild_points;
create policy "Beiträge lesen" on public.guild_points for select using (true);
revoke insert, update, delete, truncate on public.guilds, public.guild_members, public.guild_goals, public.guild_points from anon, authenticated;

-- Regeln (gleiche Werte wie scripts/guild/guild_rules.gd)
create or replace function public.cl_guild_rules() returns jsonb
language sql immutable set search_path = public as $$
  select jsonb_build_object(
    'max_level', 10,
    'xp_per_level', 1000,         -- Stufe n -> n+1 braucht n * 1000 XP
    'goal_xp', 400,               -- XP pro erfülltem Wochenziel
    'event_xp', jsonb_build_object('boss', 20, 'tower', 2, 'marks', 1),
    'banners', 8,                 -- Farben 0..7; frei: 2 + Stufe - 1
    'mark_bonus_level', 5         -- ab Stufe 5: +1 Raid-Marke pro Essenwächter
  )
$$;

create or replace function public.cl_guild_slots(lvl int) returns int
language sql immutable set search_path = public as $$ select 15 + 5 * (least(greatest(lvl, 1), 10) - 1) $$;

-- Ziel-Pool: [id, Ziel] - jede Woche drei davon, für alle Gilden gleich
create or replace function public.cl_guild_goal_pool() returns jsonb
language sql immutable set search_path = public as $$
  select jsonb_build_array(
    jsonb_build_array('boss', 15),     -- Essenwächter besiegen
    jsonb_build_array('tower', 120),   -- Turm-Etagen (neue Wochenrekorde, Summe)
    jsonb_build_array('marks', 100),   -- Raid-Marken verdienen
    jsonb_build_array('guard', 25)     -- Turmwachen besiegen
  )
$$;

create or replace function public.cl_guild_ensure_goals(gid bigint, w date) returns void
language plpgsql volatile security definer set search_path = public as $$
declare pool jsonb := cl_guild_goal_pool(); n int := jsonb_array_length(pool); skip int; i int;
begin
  if exists (select from guild_goals where guild_id = gid and week = w) then return; end if;
  skip := (extract(epoch from w)::bigint / 604800) % n;  -- jede Woche fällt ein anderes Ziel weg
  for i in 0 .. n - 1 loop
    if i <> skip then
      insert into guild_goals (guild_id, week, goal, target)
      values (gid, w, pool -> i ->> 0, (pool -> i ->> 1)::int) on conflict do nothing;
    end if;
  end loop;
end $$;

-- Fortschritt für den Spieler p: Ziel, Beitrag, XP, Stufenaufstieg.
create or replace function public.cl_guild_add(p uuid, kind text, n int) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  gid bigint; w date := cl_week(); rules jsonb := cl_guild_rules(); g public.guilds;
  gained int := 0; newly int := 0; need int;
begin
  if n <= 0 then return; end if;
  select guild_id into gid from guild_members where user_id = p;
  if gid is null then return; end if;
  perform cl_guild_ensure_goals(gid, w);
  insert into guild_points (guild_id, user_id, week, points) values (gid, p, w, n)
    on conflict (guild_id, user_id, week) do update set points = guild_points.points + n;
  with upd as (
    update guild_goals set progress = progress + n,
      done = done or progress + n >= target
    where guild_id = gid and week = w and goal = kind and not done
    returning done
  ) select count(*) filter (where done) into newly from upd;
  gained := coalesce((rules -> 'event_xp' ->> (case when kind = 'guard' then 'boss' else kind end))::int, 0) * n
          + newly * (rules ->> 'goal_xp')::int;
  select * into g from guilds where id = gid for update;
  g.xp := g.xp + gained;
  loop
    need := g.level * (rules ->> 'xp_per_level')::int;
    exit when g.level >= (rules ->> 'max_level')::int or g.xp < need;
    g.xp := g.xp - need;
    g.level := g.level + 1;
  end loop;
  update guilds set xp = g.xp, level = g.level, trophies = trophies + newly where id = gid;
end $$;

-- Trigger: der Server zählt selbst mit, die Spieler melden nichts.
create or replace function public.cl_guild_on_kill() returns trigger
language plpgsql security definer set search_path = public as $$
declare lvl int;
begin
  if new.kills <= coalesce(old.kills, 0) then return new; end if;
  perform cl_guild_add(new.owner, case when new.boss = 'turmwache' then 'guard' else 'boss' end, new.kills - coalesce(old.kills, 0));
  if new.boss = 'essenwaechter' then
    select g.level into lvl from guild_members m join guilds g on g.id = m.guild_id where m.user_id = new.owner;
    if lvl >= (cl_guild_rules() ->> 'mark_bonus_level')::int then
      update profiles set marks = marks + 1 where id = new.owner;  -- Gildenbonus
    end if;
  end if;
  return new;
end $$;
drop trigger if exists cl_guild_kill on public.raid_kills;
create trigger cl_guild_kill after insert or update of kills on public.raid_kills
  for each row execute function public.cl_guild_on_kill();

create or replace function public.cl_guild_on_marks() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.marks > old.marks then perform cl_guild_add(new.id, 'marks', new.marks - old.marks); end if;
  return new;
end $$;
drop trigger if exists cl_guild_marks on public.profiles;
create trigger cl_guild_marks after update of marks on public.profiles
  for each row execute function public.cl_guild_on_marks();

create or replace function public.cl_guild_on_tower() returns trigger
language plpgsql security definer set search_path = public as $$
declare before int := case when tg_op = 'UPDATE' then old.best_floor else 0 end;
begin
  if new.best_floor > before then perform cl_guild_add(new.owner, 'tower', new.best_floor - before); end if;
  return new;
end $$;
drop trigger if exists cl_guild_tower on public.tower_records;
create trigger cl_guild_tower after insert or update of best_floor on public.tower_records
  for each row execute function public.cl_guild_on_tower();

-- Eigene Gilde mit allem für den Bildschirm (null = keine Gilde).
create or replace function public.cl_guild_mine() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare gid bigint; g public.guilds; w date := cl_week(); my_role text;
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  select guild_id, role into gid, my_role from guild_members where user_id = auth.uid();
  if gid is null then return null; end if;
  perform cl_guild_ensure_goals(gid, w);
  select * into g from guilds where id = gid;
  return jsonb_build_object(
    'id', g.id, 'name', g.name, 'tag', g.tag, 'banner', g.banner, 'level', g.level, 'xp', g.xp,
    'xp_next', g.level * (cl_guild_rules() ->> 'xp_per_level')::int, 'trophies', g.trophies,
    'slots', cl_guild_slots(g.level), 'role', my_role, 'week', w,
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', m.user_id, 'name', p.name, 'role', m.role,
        'points', coalesce(gp.points, 0), 'me', m.user_id = auth.uid()) order by coalesce(gp.points, 0) desc, m.joined_at), '[]')
      from guild_members m join profiles p on p.id = m.user_id
      left join guild_points gp on gp.guild_id = m.guild_id and gp.user_id = m.user_id and gp.week = w
      where m.guild_id = gid),
    'goals', (select coalesce(jsonb_agg(jsonb_build_object('goal', goal, 'target', target, 'progress', least(progress, target), 'done', done) order by goal), '[]')
      from guild_goals where guild_id = gid and week = w));
end $$;

create or replace function public.cl_guild_list(search text default '') returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by (x ->> 'level')::int desc, (x ->> 'members')::int desc), '[]') from (
    select jsonb_build_object('id', g.id, 'name', g.name, 'tag', g.tag, 'banner', g.banner, 'level', g.level,
      'members', (select count(*) from guild_members m where m.guild_id = g.id), 'slots', cl_guild_slots(g.level)) x
    from guilds g
    where coalesce(search, '') = '' or g.name ilike '%' || search || '%' or g.tag ilike search
    order by g.level desc, g.id
    limit 30) s
$$;

create or replace function public.cl_guild_create(name text, tag text, banner int default 0) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare gid bigint;
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  name := btrim(name);
  tag := upper(btrim(tag));
  if char_length(name) < 3 or char_length(name) > 20 then raise exception 'Gildenname braucht 3 bis 20 Zeichen'; end if;
  if tag !~ '^[A-Z0-9]{2,4}$' then raise exception 'Kürzel: 2 bis 4 Buchstaben oder Ziffern'; end if;
  if banner < 0 or banner > 1 then raise exception 'Diese Bannerfarbe ist noch nicht frei'; end if;
  insert into profiles (id) values (auth.uid()) on conflict (id) do nothing;
  if exists (select from guild_members where user_id = auth.uid()) then raise exception 'Du bist schon in einer Gilde'; end if;
  if exists (select from guilds g where lower(g.name) = lower(cl_guild_create.name)) then raise exception 'Der Name ist vergeben'; end if;
  if exists (select from guilds g where upper(g.tag) = cl_guild_create.tag) then raise exception 'Das Kürzel ist vergeben'; end if;
  insert into guilds (name, tag, banner) values (cl_guild_create.name, cl_guild_create.tag, cl_guild_create.banner) returning id into gid;
  insert into guild_members (user_id, guild_id, role) values (auth.uid(), gid, 'anfuehrer');
  return cl_guild_mine();
end $$;

create or replace function public.cl_guild_join(gid bigint) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare g public.guilds; n int;
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  insert into profiles (id) values (auth.uid()) on conflict (id) do nothing;
  if exists (select from guild_members where user_id = auth.uid()) then raise exception 'Du bist schon in einer Gilde'; end if;
  select * into g from guilds where id = gid for update;
  if g.id is null then raise exception 'Die Gilde gibt es nicht'; end if;
  select count(*) into n from guild_members where guild_id = gid;
  if n >= cl_guild_slots(g.level) then raise exception 'Die Gilde ist voll'; end if;
  insert into guild_members (user_id, guild_id) values (auth.uid(), gid);
  return cl_guild_mine();
end $$;

-- Verlassen: der Anführer gibt an das älteste Mitglied weiter (Offiziere zuerst);
-- die Gilde verschwindet, wenn niemand bleibt.
create or replace function public.cl_guild_leave() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare m public.guild_members; heir uuid;
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  select * into m from guild_members where user_id = auth.uid();
  if m.user_id is null then return null; end if;
  delete from guild_members where user_id = auth.uid();
  if m.role = 'anfuehrer' then
    select user_id into heir from guild_members where guild_id = m.guild_id
      order by (role = 'offizier') desc, joined_at limit 1;
    if heir is null then
      delete from guilds where id = m.guild_id;
    else
      update guild_members set role = 'anfuehrer' where user_id = heir;
    end if;
  end if;
  return null;
end $$;

-- Anführer und Offiziere: Mitglied entfernen; Anführer: befördern/zurückstufen, Banner.
create or replace function public.cl_guild_manage(action text, target uuid default null, value int default 0) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare me public.guild_members; them public.guild_members; lvl int;
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  select * into me from guild_members where user_id = auth.uid();
  if me.user_id is null then raise exception 'Du bist in keiner Gilde'; end if;
  if action = 'banner' then
    if me.role <> 'anfuehrer' then raise exception 'Nur der Anführer ändert das Banner'; end if;
    select level into lvl from guilds where id = me.guild_id;
    if value < 0 or value > least(1 + lvl, 7) then raise exception 'Diese Bannerfarbe ist noch nicht frei'; end if;
    update guilds set banner = value where id = me.guild_id;
    return cl_guild_mine();
  end if;
  select * into them from guild_members where user_id = target and guild_id = me.guild_id;
  if them.user_id is null or them.user_id = me.user_id then raise exception 'Mitglied nicht gefunden'; end if;
  if action = 'kick' then
    if me.role = 'mitglied' or them.role = 'anfuehrer' or (me.role = 'offizier' and them.role = 'offizier') then
      raise exception 'Dafür fehlt dir der Rang';
    end if;
    delete from guild_members where user_id = them.user_id;
  elsif action in ('promote', 'demote') then
    if me.role <> 'anfuehrer' then raise exception 'Nur der Anführer vergibt Ränge'; end if;
    update guild_members set role = case when action = 'promote' then 'offizier' else 'mitglied' end where user_id = them.user_id;
  elsif action = 'lead' then
    if me.role <> 'anfuehrer' then raise exception 'Nur der Anführer gibt die Führung ab'; end if;
    update guild_members set role = 'offizier' where user_id = me.user_id;
    update guild_members set role = 'anfuehrer' where user_id = them.user_id;
  else
    raise exception 'unbekannte Aktion %', action;
  end if;
  return cl_guild_mine();
end $$;

revoke all on function public.cl_guild_add(uuid, text, int) from public, anon, authenticated;
revoke all on function public.cl_guild_ensure_goals(bigint, date) from public, anon, authenticated;
revoke all on function public.cl_guild_on_kill() from public, anon, authenticated;
revoke all on function public.cl_guild_on_marks() from public, anon, authenticated;
revoke all on function public.cl_guild_on_tower() from public, anon, authenticated;
revoke all on function public.cl_guild_mine() from public, anon;
revoke all on function public.cl_guild_create(text, text, int) from public, anon;
revoke all on function public.cl_guild_join(bigint) from public, anon;
revoke all on function public.cl_guild_leave() from public, anon;
revoke all on function public.cl_guild_manage(text, uuid, int) from public, anon;
grant execute on function public.cl_guild_mine() to authenticated;
grant execute on function public.cl_guild_create(text, text, int) to authenticated;
grant execute on function public.cl_guild_join(bigint) to authenticated;
grant execute on function public.cl_guild_leave() to authenticated;
grant execute on function public.cl_guild_manage(text, uuid, int) to authenticated;
grant execute on function public.cl_guild_list(text) to anon, authenticated;
