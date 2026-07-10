-- ============================================================
-- Tournments App — Role Grants
-- Run this in Supabase SQL Editor if you see "permission denied"
-- errors on any table (tournaments, teams, players, matches, etc.)
-- ============================================================

-- Schema usage (required before any table access)
grant usage on schema public to anon, authenticated;

-- ── SELECT grants (anon + authenticated can read everything) ───────────────
grant select on public.profiles         to anon, authenticated;
grant select on public.tournaments      to anon, authenticated;
grant select on public.teams            to anon, authenticated;
grant select on public.players          to anon, authenticated;
grant select on public.tournament_teams to anon, authenticated;
grant select on public.matches          to anon, authenticated;

-- ── INSERT / UPDATE / DELETE grants (authenticated only) ──────────────────
grant insert, update, delete on public.profiles         to authenticated;
grant insert, update, delete on public.tournaments      to authenticated;
grant insert, update, delete on public.teams            to authenticated;
grant insert, update, delete on public.players         to authenticated;
grant insert, delete         on public.tournament_teams to authenticated;
grant insert, update, delete on public.matches          to authenticated;

-- Sequence grants (needed for uuid default generation in some Postgres versions)
grant usage, select on all sequences in schema public to anon, authenticated;
