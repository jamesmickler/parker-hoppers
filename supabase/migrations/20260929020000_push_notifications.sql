-- Park Hoppers: phone notifications when a friend arrives at one of your parks.
-- Apply with `supabase db push`.

-- One row per phone/browser that turned notifications on. `park_ids` are that phone's
-- "Your parks" (alerts on), kept in sync by the app.
create table if not exists public.push_subscriptions (
  endpoint text primary key check (char_length(endpoint) <= 1000),
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  p256dh text not null check (char_length(p256dh) <= 200),
  auth text not null check (char_length(auth) <= 100),
  park_ids text[] not null default '{}' check (cardinality(park_ids) <= 50),
  updated_at timestamptz not null default now()
);

alter table public.push_subscriptions enable row level security;

-- People manage only their own devices. Sending is done by the notify-arrival function,
-- which reads this table with the server's own key.
drop policy if exists "see own devices" on public.push_subscriptions;
drop policy if exists "add own devices" on public.push_subscriptions;
drop policy if exists "update own devices" on public.push_subscriptions;
drop policy if exists "remove own devices" on public.push_subscriptions;
create policy "see own devices" on public.push_subscriptions for select to authenticated using (user_id = (select auth.uid()));
create policy "add own devices" on public.push_subscriptions for insert to authenticated with check (user_id = (select auth.uid()));
create policy "update own devices" on public.push_subscriptions for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "remove own devices" on public.push_subscriptions for delete to authenticated using (user_id = (select auth.uid()));

-- Each arrival notifies friends once: the function marks it, and checking in again resets it.
alter table public.check_ins add column if not exists notified boolean not null default false;

create or replace function public.stamp_arrival() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.arrived_at := now();
  new.notified := false;
  return new;
end;
$$;
