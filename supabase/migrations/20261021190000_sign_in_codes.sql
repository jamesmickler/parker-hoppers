-- Park Hoppers: one-time sign-in codes, so the same person can use the app on their
-- Home Screen, another phone or a laptop.
--
-- On iPhone, a website saved to the Home Screen keeps its own storage, separate from
-- Safari. Someone who joined in Safari therefore looks brand new when they open the icon.
-- A sign-in code made on the device that's signed in lets the other one sign in as the
-- same person. Codes are made and used only by the `sign-in-code` Edge Function.
-- Apply with `supabase db push`.

create table if not exists public.sign_in_codes (
  code text primary key check (code ~ '^[A-Z0-9]{8}$'),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 minutes',
  used_at timestamptz
);
create index if not exists sign_in_codes_user on public.sign_in_codes (user_id);

-- No rules for anyone: only the Edge Function (service role) reads or writes these.
alter table public.sign_in_codes enable row level security;
revoke all on public.sign_in_codes from anon, authenticated;
