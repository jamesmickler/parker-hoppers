-- Park Hoppers: friends-only sharing through invite codes, and dog details.
-- Apply with `supabase db push`.

-- ============ Dog details ============

alter table public.dogs add column if not exists size text
  check (size in ('small', 'medium', 'large'));
alter table public.dogs add column if not exists comfort text
  check (comfort in ('loves_all', 'small_dogs', 'big_dogs', 'shy', 'needs_space'));

-- ============ Friends ============
-- One row per pair of friends, stored with the smaller id first so each pair appears once.

create table if not exists public.friendships (
  user_a uuid not null references public.profiles (id) on delete cascade,
  user_b uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
create index if not exists friendships_user_b on public.friendships (user_b);

alter table public.friendships enable row level security;
drop policy if exists "see own friendships" on public.friendships;
drop policy if exists "end own friendships" on public.friendships;
create policy "see own friendships" on public.friendships for select to authenticated
  using ((select auth.uid()) in (user_a, user_b));
create policy "end own friendships" on public.friendships for delete to authenticated
  using ((select auth.uid()) in (user_a, user_b));
-- No insert rule on purpose: friendships are only created by accept_invite() below.

-- True when `other` is the signed-in person or one of their friends.
create or replace function public.can_see(other uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select other = (select auth.uid())
    or exists (
      select 1 from public.friendships f
      where (f.user_a = (select auth.uid()) and f.user_b = other)
         or (f.user_b = (select auth.uid()) and f.user_a = other)
    );
$$;

-- ============ Only friends see each other ============
-- Replaces "anyone signed in can see everyone".

drop policy if exists "read profiles" on public.profiles;
create policy "read profiles" on public.profiles for select to authenticated using (public.can_see(id));

drop policy if exists "read dogs" on public.dogs;
create policy "read dogs" on public.dogs for select to authenticated using (public.can_see(owner_id));

drop policy if exists "read check-ins" on public.check_ins;
create policy "read check-ins" on public.check_ins for select to authenticated using (public.can_see(user_id));

drop policy if exists "read posts" on public.posts;
create policy "read posts" on public.posts for select to authenticated using (public.can_see(author_id));

-- Likes are visible on posts you can see.
drop policy if exists "read likes" on public.post_likes;
create policy "read likes" on public.post_likes for select to authenticated
  using (exists (select 1 from public.posts p where p.id = post_id));

-- ============ Invites ============
-- A short code that works once and expires after 7 days.

create table if not exists public.invites (
  code text primary key check (code ~ '^[A-Z0-9]{8}$'),
  inviter_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_by uuid references public.profiles (id) on delete set null,
  used_at timestamptz
);

alter table public.invites enable row level security;
drop policy if exists "see own invites" on public.invites;
create policy "see own invites" on public.invites for select to authenticated
  using (inviter_id = (select auth.uid()));
-- Invites are created and used only through the functions below.

create or replace function public.create_invite() returns text
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- no 0/O or 1/I mix-ups
  random_bytes bytea;
  new_code text;
begin
  if me is null or not exists (select 1 from public.profiles where id = me) then
    raise exception 'Join Park Hoppers first.';
  end if;
  if (select count(*) from public.invites
      where inviter_id = me and used_by is null and expires_at > now()) >= 20 then
    raise exception 'You have 20 unused invites already. Wait for some to be used or expire.';
  end if;
  loop
    random_bytes := extensions.gen_random_bytes(8);
    new_code := '';
    for i in 0..7 loop
      new_code := new_code || substr(alphabet, 1 + (get_byte(random_bytes, i) % 32), 1);
    end loop;
    begin
      insert into public.invites (code, inviter_id) values (new_code, me);
      return new_code;
    exception when unique_violation then
      -- Astronomically unlikely; just pick another code.
    end;
  end loop;
end;
$$;

-- Makes the signed-in person and the inviter friends. Returns the inviter's name.
create or replace function public.accept_invite(invite_code text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  wanted text := upper(regexp_replace(coalesce(invite_code, ''), '[^A-Za-z0-9]', '', 'g'));
  invite public.invites%rowtype;
  inviter_name text;
begin
  if me is null or not exists (select 1 from public.profiles where id = me) then
    raise exception 'Join Park Hoppers first.';
  end if;
  select * into invite from public.invites where code = wanted for update;
  if not found then
    raise exception 'That invite code doesn’t exist. Check it and try again.';
  end if;
  if invite.inviter_id = me then
    raise exception 'That’s your own invite. Send it to a friend!';
  end if;
  select name into inviter_name from public.profiles where id = invite.inviter_id;
  if exists (select 1 from public.friendships
             where user_a = least(me, invite.inviter_id) and user_b = greatest(me, invite.inviter_id)) then
    return inviter_name; -- already friends
  end if;
  if invite.used_by is not null then
    raise exception 'That invite was already used. Ask % for a new one.', inviter_name;
  end if;
  if invite.expires_at < now() then
    raise exception 'That invite expired. Ask % for a new one.', inviter_name;
  end if;
  update public.invites set used_by = me, used_at = now() where code = invite.code;
  insert into public.friendships (user_a, user_b)
  values (least(me, invite.inviter_id), greatest(me, invite.inviter_id))
  on conflict do nothing;
  return inviter_name;
end;
$$;

-- Who sent a still-valid invite, so the join screen can say "Maya invited you".
-- Works before signing in.
create or replace function public.invite_preview(invite_code text) returns text
language sql stable security definer set search_path = '' as $$
  select p.name
  from public.invites i join public.profiles p on p.id = i.inviter_id
  where i.code = upper(regexp_replace(coalesce(invite_code, ''), '[^A-Za-z0-9]', '', 'g'))
    and i.used_by is null and i.expires_at > now();
$$;

revoke execute on function public.create_invite() from public, anon;
revoke execute on function public.accept_invite(text) from public, anon;
grant execute on function public.create_invite() to authenticated;
grant execute on function public.accept_invite(text) to authenticated;
grant execute on function public.invite_preview(text) to anon, authenticated;

-- ============ Live updates ============
-- So both phones reload the moment a friendship starts or ends.

do $$
begin
  alter publication supabase_realtime add table public.friendships;
exception when duplicate_object then null;
end $$;
