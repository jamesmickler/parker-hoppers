-- Park Hoppers: a heartbeat that keeps the free Supabase project from pausing.
--
-- Free projects pause after a week without "sufficient user database activity". A read every
-- other day wasn't enough (the project paused around 2026-11-02), so the keep-awake workflow
-- now calls keep_alive() four times a day, which writes one row: real database work.
-- Apply with `supabase db push`.

create table if not exists public.keep_alive (
  id int primary key default 1 check (id = 1), -- always exactly one row
  pinged_at timestamptz not null default now(),
  pings bigint not null default 0
);

-- Nobody reads or writes the table directly; only keep_alive() below touches it.
alter table public.keep_alive enable row level security;
revoke all on public.keep_alive from anon, authenticated;

-- Updates the heartbeat and returns its time. Safe to leave open: it only ever changes this
-- one row.
create or replace function public.keep_alive() returns timestamptz
language sql volatile security definer set search_path = '' as $$
  insert into public.keep_alive (id, pinged_at, pings) values (1, now(), 1)
  on conflict (id) do update set pinged_at = now(), pings = public.keep_alive.pings + 1
  returning pinged_at;
$$;

revoke execute on function public.keep_alive() from public;
grant execute on function public.keep_alive() to anon, authenticated;
