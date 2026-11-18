-- TEST ONLY: minimal Supabase Auth boundary for a disposable PostgreSQL instance.
-- Never run this file in Supabase: its Auth schemas/roles already exist there.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
-- Simulate broad defaults present on some hosted Supabase projects.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
CREATE SCHEMA auth;
CREATE TABLE auth.users (
    id uuid PRIMARY KEY,
    email text,
    email_confirmed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    last_sign_in_at timestamptz,
    raw_user_meta_data jsonb NOT NULL DEFAULT '{}'
);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
    SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
-- The existing account verifies the migration backfill path.
INSERT INTO auth.users(id,email,email_confirmed_at,raw_user_meta_data) VALUES (
    '10000000-0000-0000-0000-000000000004', 'existing@example.invalid', now(), '{"full_name":"Existing account"}'
);
