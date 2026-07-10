-- ============================================================
-- Tournments App — Supabase Schema
-- Run this in your Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ── Profiles ──────────────────────────────────────────────────────────────
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text not null,
  phone       text,
  avatar_url  text,
  level       int not null default 1,
  xp          int not null default 0,
  xp_to_next  int not null default 1000,
  created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can read any profile"
  on public.profiles for select using (true);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert with check (auth.uid() = id);

-- ── Tournaments ────────────────────────────────────────────────────────────
create table public.tournaments (
  id            uuid primary key default uuid_generate_v4(),
  name          text not null,
  sport         text not null,
  type          text not null default 'teams'
                  check (type in ('teams','individual')),
  status        text not null default 'upcoming'
                  check (status in ('draft','upcoming','live','completed')),
  organizer_id  uuid references public.profiles(id),
  location      text,
  description   text,
  start_date    date,
  end_date      date,
  max_teams     int not null default 16,
  current_teams int not null default 0,
  invite_code   text unique,
  created_at    timestamptz not null default now()
);

alter table public.tournaments enable row level security;

create policy "Anyone can read tournaments"
  on public.tournaments for select using (true);

create policy "Organizer can insert tournament"
  on public.tournaments for insert with check (auth.uid() = organizer_id);

create policy "Organizer can update tournament"
  on public.tournaments for update using (auth.uid() = organizer_id);

-- ── Teams ──────────────────────────────────────────────────────────────────
create table public.teams (
  id           uuid primary key default uuid_generate_v4(),
  name         text not null,
  sport        text not null,
  logo_url     text,
  color_hex    text default '#00E676',
  captain_id   uuid references public.profiles(id),
  player_count int not null default 0,
  created_at   timestamptz not null default now()
);

alter table public.teams enable row level security;

create policy "Anyone can read teams"
  on public.teams for select using (true);

create policy "Captain can insert team"
  on public.teams for insert with check (auth.uid() = captain_id);

create policy "Captain can update team"
  on public.teams for update using (auth.uid() = captain_id);

-- ── Players ────────────────────────────────────────────────────────────────
create table public.players (
  id             uuid primary key default uuid_generate_v4(),
  profile_id     uuid not null references public.profiles(id),
  name           text not null,
  team_id        uuid references public.teams(id) on delete set null,
  sport          text,
  role           text,
  jersey_number  int,
  avatar_url     text,
  stats          jsonb not null default '{}',
  created_at     timestamptz not null default now()
);

alter table public.players enable row level security;

create policy "Anyone can read players"
  on public.players for select using (true);

create policy "Owner can manage player"
  on public.players for all using (auth.uid() = profile_id);

-- ── Tournament Teams (join table) ──────────────────────────────────────────
create table public.tournament_teams (
  tournament_id  uuid not null references public.tournaments(id) on delete cascade,
  team_id        uuid not null references public.teams(id) on delete cascade,
  joined_at      timestamptz not null default now(),
  primary key (tournament_id, team_id)
);

alter table public.tournament_teams enable row level security;

create policy "Anyone can read tournament_teams"
  on public.tournament_teams for select using (true);

create policy "Authenticated can join"
  on public.tournament_teams for insert with check (auth.role() = 'authenticated');

-- ── Matches ────────────────────────────────────────────────────────────────
create table public.matches (
  id              uuid primary key default uuid_generate_v4(),
  tournament_id   uuid not null references public.tournaments(id) on delete cascade,
  home_team_id    uuid references public.teams(id) on delete cascade,
  away_team_id    uuid references public.teams(id) on delete cascade,
  home_team_name  text,
  away_team_name  text,
  sport           text not null,
  status          text not null default 'scheduled'
                    check (status in ('scheduled','live','completed','cancelled')),
  home_score      int,
  away_score      int,
  scheduled_at    timestamptz,
  metadata        jsonb not null default '{}',
  created_at      timestamptz not null default now()
);

alter table public.matches enable row level security;

create policy "Anyone can read matches"
  on public.matches for select using (true);

create policy "Authenticated can update matches"
  on public.matches for update using (auth.role() = 'authenticated');

create policy "Authenticated can insert matches"
  on public.matches for insert with check (auth.role() = 'authenticated');

-- Enable Realtime for live score updates
alter publication supabase_realtime add table public.matches;

-- ── Helper: keep teams.player_count in sync with players table ───────────
create or replace function sync_team_player_count()
returns trigger language plpgsql as $$
begin
  if TG_OP = 'INSERT' then
    update public.teams set player_count = player_count + 1 where id = NEW.team_id;
  elsif TG_OP = 'DELETE' then
    update public.teams set player_count = greatest(player_count - 1, 0) where id = OLD.team_id;
  end if;
  return null;
end;
$$;

create trigger on_player_change
  after insert or delete on public.players
  for each row execute procedure sync_team_player_count();

-- ── Helper: auto-increment current_teams ──────────────────────────────────
create or replace function increment_tournament_teams()
returns trigger language plpgsql as $$
begin
  update public.tournaments
  set current_teams = current_teams + 1
  where id = NEW.tournament_id;
  return NEW;
end;
$$;

create trigger on_team_join
  after insert on public.tournament_teams
  for each row execute procedure increment_tournament_teams();

-- ── Helper: generate invite code on tournament create ─────────────────────
create or replace function generate_invite_code()
returns trigger language plpgsql as $$
begin
  if NEW.invite_code is null then
    NEW.invite_code := upper(substring(md5(random()::text) from 1 for 6));
  end if;
  return NEW;
end;
$$;

create trigger set_invite_code
  before insert on public.tournaments
  for each row execute procedure generate_invite_code();
