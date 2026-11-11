-- Park Hoppers: fixes from the November 2026 stress test.
-- Apply with `supabase db push` (GitHub also applies it automatically).

-- ============ 1. Live updates no longer announce who checked out or unfriended ============
-- Supabase's live updates ignore the read rules for DELETEs: they tell every listener (even
-- someone not signed in) the deleted row's primary key. Those keys used to be real account ids
-- (check_ins.user_id) or pairs of them (friendships, post_likes). They're now random ids that
-- mean nothing, so a delete reveals only that "something was removed". Existing code still
-- works: user_id stays unique, so `on_conflict=user_id` upserts keep working.

alter table public.check_ins add column if not exists id uuid not null default gen_random_uuid();
alter table public.check_ins drop constraint if exists check_ins_pkey;
alter table public.check_ins add constraint check_ins_pkey primary key (id);
alter table public.check_ins alter column user_id set not null;
alter table public.check_ins add constraint check_ins_user_id_key unique (user_id);

alter table public.friendships add column if not exists id uuid not null default gen_random_uuid();
alter table public.friendships drop constraint if exists friendships_pkey;
alter table public.friendships add constraint friendships_pkey primary key (id);
alter table public.friendships add constraint friendships_pair_key unique (user_a, user_b);

alter table public.post_likes add column if not exists id uuid not null default gen_random_uuid();
alter table public.post_likes drop constraint if exists post_likes_pkey;
alter table public.post_likes add constraint post_likes_pkey primary key (id);
alter table public.post_likes add constraint post_likes_once unique (post_id, user_id);

-- ============ 2. Only real parks ============
-- A made-up park name used to crash friends' screens. Keep this list in step with
-- web/data.js, ios/ParkerHoppers/Parks.swift and supabase/functions/notify-arrival.

alter table public.check_ins add constraint check_ins_park_known check (park_id in (
  'hazel-parker', 'cannon-park', 'brittlebank', 'white-point',
  'horse-lot', 'the-jasper', 'ackerman', 'james-island'));
alter table public.posts add constraint posts_park_known check (park_id is null or park_id in (
  'hazel-parker', 'cannon-park', 'brittlebank', 'white-point',
  'horse-lot', 'the-jasper', 'ackerman', 'james-island'));

-- ============ 3. Only your own dogs ============
-- Checking in with someone else's dog (or one that doesn't exist) put that dog's name into
-- friends' "just arrived" alerts.

create or replace function public.check_in_dogs_are_mine() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' or new.dog_ids is distinct from old.dog_ids then
    new.dog_ids := array(select distinct d from unnest(new.dog_ids) as d);
    if exists (
      select 1 from unnest(new.dog_ids) as d
      where not exists (select 1 from public.dogs where id = d and owner_id = new.user_id)
    ) then
      raise exception 'You can only check in your own dogs.' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function public.check_in_dogs_are_mine() from public, anon, authenticated;

drop trigger if exists check_in_dogs_are_mine on public.check_ins;
create trigger check_in_dogs_are_mine before insert or update on public.check_ins
  for each row execute function public.check_in_dogs_are_mine();

-- Saving the same visit again no longer counts as a new arrival, and a new arrival right after
-- one was announced isn't announced again, so nobody can re-send alerts to friends over and over.
create or replace function public.stamp_arrival() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and current_user = 'service_role' then
    return new; -- the notification server marking it announced
  end if;
  if tg_op = 'UPDATE' then
    if new.park_id = old.park_id and old.arrived_at > now() - interval '90 minutes' then
      new.arrived_at := old.arrived_at; -- the same visit, saved again
      new.notified := old.notified;
      return new;
    end if;
    new.notified := old.notified and old.arrived_at > now() - interval '2 minutes';
  else
    new.notified := false;
  end if;
  new.arrived_at := now();
  return new;
end;
$$;

-- ============ 4. Photos: only your own uploads, and you can delete them ============
-- A dog's photo link could point at any website, which then learned when friends opened the
-- app. It must now be a file in your own folder of this project's photo storage.

alter table public.dogs add constraint dogs_photo_url_mine check (photo_url is null or photo_url ~
  ('^https://dndbyhphjvumqkjtuncn\.supabase\.co/storage/v1/object/public/photos/' || owner_id::text || '/[0-9a-f-]{36}\.jpg$'));
alter table public.posts add constraint posts_photo_url_mine check (photo_url is null or photo_url ~
  ('^https://dndbyhphjvumqkjtuncn\.supabase\.co/storage/v1/object/public/photos/' || author_id::text || '/[0-9a-f-]{36}\.jpg$'));

-- Uploads must be named <your id>/<random id>.jpg (odd names with ".." are refused), and you
-- can see your own files, which is what lets the app delete them (leaving, replacing, deleting).
drop policy if exists "upload own photos" on storage.objects;
create policy "upload own photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$');
drop policy if exists "see own photos" on storage.objects;
create policy "see own photos" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid()::text));

-- ============ 5. Likes and reports only on posts you can see ============
-- You could like a post you couldn't see, and then never un-like it (the delete was filtered by
-- the read rule). Your own likes are now always visible to you, and other people's likes only
-- when they're friends.

drop policy if exists "like" on public.post_likes;
create policy "like" on public.post_likes for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (select 1 from public.posts p where p.id = post_id));

drop policy if exists "read likes" on public.post_likes;
create policy "read likes" on public.post_likes for select to authenticated
  using (user_id = (select auth.uid())
    or (public.can_see(user_id) and exists (select 1 from public.posts p where p.id = post_id)));

drop policy if exists "report" on public.reports;
create policy "report" on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()) and exists (select 1 from public.posts p where p.id = post_id));

-- ============ 6. Invites don't name the sender of a dead code ============

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
  if invite.used_by is not null or invite.expires_at < now() then
    raise exception 'That invite was already used or has expired. Ask your friend for a new one.';
  end if;
  update public.invites set used_by = me, used_at = now() where code = invite.code;
  insert into public.friendships (user_a, user_b)
  values (least(me, invite.inviter_id), greatest(me, invite.inviter_id))
  on conflict do nothing;
  return inviter_name;
end;
$$;

-- ============ 7. Phone notification addresses ============
-- Only the real push services are accepted (the server sends to whatever is saved here), and
-- signing in on a browser another account used takes over that browser's notification address
-- instead of being refused.

alter table public.push_subscriptions add constraint push_endpoint_known check (endpoint ~
  '^https://(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|web\.push\.apple\.com|[a-z0-9.-]+\.notify\.windows\.com)/');

create or replace function public.save_push_device(p_endpoint text, p_p256dh text, p_auth text, p_park_ids text[])
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
begin
  insert into public.push_subscriptions (endpoint, user_id, p256dh, auth, park_ids, updated_at)
  values (p_endpoint, me, p_p256dh, p_auth, p_park_ids, now())
  on conflict (endpoint) do update
    set user_id = me, p256dh = excluded.p256dh, auth = excluded.auth,
        park_ids = excluded.park_ids, updated_at = now();
end;
$$;
revoke execute on function public.save_push_device(text, text, text, text[]) from public, anon;
grant execute on function public.save_push_device(text, text, text, text[]) to authenticated;
