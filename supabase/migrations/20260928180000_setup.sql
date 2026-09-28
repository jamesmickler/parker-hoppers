-- Parker Hoppers: shared data for the prototype.
-- Apply with `supabase db push`, or paste into Supabase's SQL Editor and click Run.
-- Safe to run again; it only adds what's missing and refreshes the access rules.

-- ============ Tables ============

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 40),
  created_at timestamptz not null default now()
);

create table if not exists public.dogs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 30),
  breed text not null default 'Good dog' check (char_length(breed) <= 40),
  color text not null default '#5B8DEF' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  photo_url text check (char_length(photo_url) <= 500),
  created_at timestamptz not null default now()
);

-- One row per person: checking in again replaces it, checking out deletes it.
create table if not exists public.check_ins (
  user_id uuid primary key default auth.uid() references public.profiles (id) on delete cascade,
  park_id text not null check (char_length(park_id) <= 40),
  dog_ids uuid[] not null check (cardinality(dog_ids) between 1 and 10),
  arrived_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  dog_id uuid references public.dogs (id) on delete set null,
  park_id text check (char_length(park_id) <= 40),
  caption text not null default '' check (char_length(caption) <= 280),
  photo_url text check (char_length(photo_url) <= 500),
  created_at timestamptz not null default now()
);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  primary key (post_id, user_id)
);

-- Reported posts land here for review (visible in the Supabase Table Editor).
create table if not exists public.reports (
  post_id uuid not null references public.posts (id) on delete cascade,
  reporter_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, reporter_id)
);

-- The server sets the arrival time, so nobody can fake how long they've been at the park.
create or replace function public.stamp_arrival() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.arrived_at := now();
  return new;
end;
$$;

drop trigger if exists stamp_arrival on public.check_ins;
create trigger stamp_arrival before insert or update on public.check_ins
  for each row execute function public.stamp_arrival();

-- ============ Who can see and change what ============
-- Anyone signed in (including name-only "anonymous" sign-ins) can see the community.
-- People can only create, change or delete their own rows.

alter table public.profiles enable row level security;
alter table public.dogs enable row level security;
alter table public.check_ins enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.reports enable row level security;

drop policy if exists "read profiles" on public.profiles;
drop policy if exists "create own profile" on public.profiles;
drop policy if exists "edit own profile" on public.profiles;
drop policy if exists "delete own profile" on public.profiles;
create policy "read profiles" on public.profiles for select to authenticated using (true);
create policy "create own profile" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy "edit own profile" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "delete own profile" on public.profiles for delete to authenticated using (id = (select auth.uid()));

drop policy if exists "read dogs" on public.dogs;
drop policy if exists "add own dogs" on public.dogs;
drop policy if exists "edit own dogs" on public.dogs;
drop policy if exists "remove own dogs" on public.dogs;
create policy "read dogs" on public.dogs for select to authenticated using (true);
create policy "add own dogs" on public.dogs for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "edit own dogs" on public.dogs for update to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "remove own dogs" on public.dogs for delete to authenticated using (owner_id = (select auth.uid()));

drop policy if exists "read check-ins" on public.check_ins;
drop policy if exists "check in" on public.check_ins;
drop policy if exists "move check-in" on public.check_ins;
drop policy if exists "check out" on public.check_ins;
create policy "read check-ins" on public.check_ins for select to authenticated using (true);
create policy "check in" on public.check_ins for insert to authenticated with check (user_id = (select auth.uid()));
create policy "move check-in" on public.check_ins for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "check out" on public.check_ins for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "read posts" on public.posts;
drop policy if exists "write own posts" on public.posts;
drop policy if exists "delete own posts" on public.posts;
create policy "read posts" on public.posts for select to authenticated using (true);
create policy "write own posts" on public.posts for insert to authenticated with check (author_id = (select auth.uid()));
create policy "delete own posts" on public.posts for delete to authenticated using (author_id = (select auth.uid()));

drop policy if exists "read likes" on public.post_likes;
drop policy if exists "like" on public.post_likes;
drop policy if exists "unlike" on public.post_likes;
create policy "read likes" on public.post_likes for select to authenticated using (true);
create policy "like" on public.post_likes for insert to authenticated with check (user_id = (select auth.uid()));
create policy "unlike" on public.post_likes for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "see own reports" on public.reports;
drop policy if exists "report" on public.reports;
create policy "see own reports" on public.reports for select to authenticated using (reporter_id = (select auth.uid()));
create policy "report" on public.reports for insert to authenticated with check (reporter_id = (select auth.uid()));

-- ============ Live updates ============
-- Lets phones hear about check-ins and posts the moment they happen.

do $$
declare t text;
begin
  foreach t in array array['profiles', 'dogs', 'check_ins', 'posts', 'post_likes'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- ============ Photos ============
-- Public bucket: anyone with a photo's link can view it. People upload only into their own folder.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists "upload own photos" on storage.objects;
drop policy if exists "delete own photos" on storage.objects;
create policy "upload own photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "delete own photos" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid()::text));
