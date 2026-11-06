-- Chibi Legends: GOD-Stufe (über Mythisch), 48 Teile. Jedes GOD-Teil gibt es weltweit
-- genau EINMAL. Der Server würfelt nach einem echten Sieg (Raid-Boss,
-- Weltboss, Turm-Bestmarke ab Etage 20 in Zehnerschritten), ob man eins
-- bekommt, und vergibt dann ein noch freies Teil. Die Zeile in god_items
-- ist der Besitz; der Primärschlüssel auf item macht Doppelte unmöglich.
-- Wird ein Konto gelöscht, wird sein Teil wieder frei (owner = null).
--
-- Die Teile selbst (Name, Werte, Optik) stehen im Client: scripts/game/god_items.gd
-- (gleiche ids wie cl_god_rules().items).
--
-- Braucht 0001 (Profile, Raid-Siege, Turm) und 0003 (Weltboss). Wiederholt ausführbar.
-- Einspielen: Supabase-Dashboard -> SQL Editor -> Inhalt einfügen -> Run.

create table if not exists public.god_items (
  item text primary key,
  owner uuid references public.profiles (id) on delete set null,
  source text,
  obtained_at timestamptz
);
create unique index if not exists god_items_owner_item on public.god_items (owner, item);

-- Jeder Sieg darf genau einmal würfeln.
create table if not exists public.god_rolls (
  owner uuid not null references public.profiles (id) on delete cascade,
  source text not null,
  ref text not null,
  won text,
  rolled_at timestamptz not null default now(),
  primary key (owner, source, ref)
);

alter table public.god_items enable row level security;
alter table public.god_rolls enable row level security;
drop policy if exists "GOD-Halle lesen" on public.god_items;
create policy "GOD-Halle lesen" on public.god_items for select using (true);
drop policy if exists "eigene GOD-Würfe lesen" on public.god_rolls;
create policy "eigene GOD-Würfe lesen" on public.god_rolls for select using (owner = auth.uid());
revoke insert, update, delete, truncate on public.god_items, public.god_rolls from anon, authenticated;

create or replace function public.cl_god_rules() returns jsonb
language sql immutable set search_path = public as $$
  select jsonb_build_object(
    'items', jsonb_build_array(
      'god_sonnenkrone', 'god_gewand', 'god_beinkleid', 'god_morgenschritte', 'god_seraphfluegel',
      'god_hoernerkrone', 'god_hoellenpanzer', 'god_kettenbeinkleid', 'god_aschewandler', 'god_verdammnisschwingen',
      'god_glockenschwinge', 'god_engelsruf', 'god_sonnenfaeuste', 'god_himmelswirbel',
      'god_hoellenschlund', 'god_mondfresser', 'god_hoellenfaust', 'god_teufelsfeder',
      -- Waffen der 30 Baukasten-Stile
      'god_flutseraph', 'god_himmelsdonner', 'god_engelsfrost', 'god_sonnengericht', 'god_cherubsfeder',
      'god_sternenchor', 'god_prisma', 'god_tausendgebete', 'god_heiligenkreis', 'god_himmelsschleier',
      'god_richterhammer', 'god_paradiesbluete', 'god_ewigestunde', 'god_wahrheitsspiegel', 'god_erzengelhammer',
      'god_hoellenfels', 'god_seelennaht', 'god_verderbnisranke', 'god_blutpakt', 'god_hoellenkette',
      'god_hoellenpauke', 'god_daemonenfuchs', 'god_hoellendrache', 'god_seelenfaden', 'god_weltenbrand',
      'god_aschesturm', 'god_totenlicht', 'god_leviathan', 'god_hoellenklaue', 'god_nichtsklinge'),
    -- Chance je Sieg
    'chance', jsonb_build_object('raid', 0.004, 'world', 0.03, 'tower', 0.01),
    'tower_min', 20, 'tower_step', 10
  )
$$;

-- alle Teile als Zeilen (frei = owner null)
insert into public.god_items (item)
select jsonb_array_elements_text(public.cl_god_rules() -> 'items') on conflict do nothing;

-- Intern: ein freies Teil an p vergeben (zufällig), id oder null wenn alle weg.
create or replace function public.cl_god_give(p uuid, src text) returns text
language plpgsql volatile security definer set search_path = public as $$
declare got text;
begin
  update god_items set owner = p, source = src, obtained_at = now()
  where item = (select g.item from god_items g where g.owner is null order by random() limit 1 for update skip locked)
    and owner is null
  returning item into got;
  return got;
end $$;

-- Nach einem Sieg würfeln. source: raid | world | tower; ref: Tag (raid,
-- frei wählbar, gezählt wird pro Raid-Sieg des Tages), Weltboss-id, Etage.
create or replace function public.cl_god_roll(source text, ref text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  r jsonb := cl_god_rules(); chance float8; key text; kills int; used int; f int; got text := null;
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  if not (r -> 'chance') ? source then raise exception 'unbekannte Quelle %', source; end if;
  chance := (r -> 'chance' ->> source)::float8;
  insert into profiles (id) values (auth.uid()) on conflict (id) do nothing;
  if source = 'raid' then
    select coalesce(sum(k.kills), 0) into kills from raid_kills k
      where k.owner = auth.uid() and k.day = current_date and k.boss = 'essenwaechter';
    select count(*) into used from god_rolls g
      where g.owner = auth.uid() and g.source = 'raid' and g.ref like current_date::text || ':%';
    if used >= kills then raise exception 'Kein Raid-Sieg zum Würfeln offen'; end if;
    key := current_date::text || ':' || (used + 1);
  elsif source = 'world' then
    if not exists (select 1 from world_hits w where w.boss_id = ref::bigint and w.user_id = auth.uid() and w.claimed) then
      raise exception 'Kein Weltboss-Sieg zum Würfeln';
    end if;
    key := ref;
  else
    f := ref::int;
    if f < (r ->> 'tower_min')::int or f % (r ->> 'tower_step')::int <> 0 then raise exception 'Diese Etage zählt nicht'; end if;
    if not exists (select 1 from tower_records t where t.owner = auth.uid() and t.week = cl_week() and t.best_floor >= f) then
      raise exception 'Etage nicht erreicht';
    end if;
    key := cl_week()::text || ':' || f;
  end if;
  begin
    insert into god_rolls (owner, source, ref) values (auth.uid(), source, key);
  exception when unique_violation then
    return jsonb_build_object('won', false, 'chance', chance, 'already', true);
  end;
  if random() < chance then
    got := cl_god_give(auth.uid(), source);
    update god_rolls g set won = got where g.owner = auth.uid() and g.source = cl_god_roll.source and g.ref = key;
  end if;
  return jsonb_build_object('won', got is not null, 'item', got, 'chance', chance,
    'free', (select count(*) from god_items where owner is null));
end $$;

-- Eigene GOD-Teile (Abgleich beim Login).
create or replace function public.cl_god_mine() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(item order by item), '[]'::jsonb) from god_items where owner = auth.uid()
$$;

-- GOD-Halle: jedes Teil mit Besitzername (null = noch frei).
create or replace function public.cl_god_hall() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('item', g.item, 'owner', p.name, 'mine', g.owner = auth.uid(),
    'since', g.obtained_at) order by g.item), '[]'::jsonb)
  from god_items g left join profiles p on p.id = g.owner
$$;

revoke all on function public.cl_god_give(uuid, text) from public, anon, authenticated;
revoke all on function public.cl_god_roll(text, text) from public, anon;
revoke all on function public.cl_god_mine() from public, anon;
revoke all on function public.cl_god_hall() from public, anon;
grant execute on function public.cl_god_roll(text, text) to authenticated;
grant execute on function public.cl_god_mine() to authenticated;
grant execute on function public.cl_god_hall() to authenticated;
