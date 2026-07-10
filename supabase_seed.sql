-- ============================================================
-- Tournments App — Seed: Sample User
-- Run AFTER supabase_schema.sql in the Supabase SQL Editor
-- Login: demo@tournments.com / Demo1234!
-- ============================================================

do $$
declare
  v_user_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    is_super_admin,
    role,
    aud,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change
  ) values (
    v_user_id,
    '00000000-0000-0000-0000-000000000000',
    'demo@tournments.com',
    crypt('Demo1234!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"username":"DemoPlayer"}',
    false,
    'authenticated',
    'authenticated',
    now(),
    now(),
    '', '', '', ''
  );

  insert into public.profiles (id, username, phone, level, xp, xp_to_next, created_at)
  values (v_user_id, 'DemoPlayer', null, 12, 7200, 10000, now());

  raise notice 'Created user: demo@tournments.com  password: Demo1234!  id: %', v_user_id;
end $$;
