// Talks to Supabase: sign-in, shared people, dogs, check-ins and posts, and live updates.
// Everything is converted into the same shapes the demo data uses, so screens don't care
// whether a dog is real or made up.

import { SUPABASE_URL, SUPABASE_KEY } from './config.js';

const LIBRARY = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
const CHECKIN_WINDOW = 90 * 60_000;

let sb = null;

export const data = {
  me: null,
  profiles: {},
  dogs: {},
  checkIns: [],
  posts: [],
  reported: new Set(),
};

const timeout = (ms) => new Promise((_, reject) => setTimeout(() => reject(new Error('timed out')), ms));

/** Loads Supabase and restores a previous sign-in. Resolves { available, signedIn }. */
export async function connect() {
  try {
    const { createClient } = await Promise.race([import(LIBRARY), timeout(8000)]);
    sb = createClient(SUPABASE_URL, SUPABASE_KEY);
    const { data: { session } } = await sb.auth.getSession();
    if (session) {
      await refresh(session.user.id);
    }
    return { available: true, signedIn: !!data.me };
  } catch (error) {
    console.warn('Supabase unavailable, using demo data only:', error);
    sb = null;
    return { available: false, signedIn: false };
  }
}

const must = (result) => {
  if (result.error) throw result.error;
  return result.data;
};

/** Reloads everything the app shows from the database. */
export async function refresh(myId = data.me?.id) {
  if (!sb || !myId) return;
  const since = new Date(Date.now() - CHECKIN_WINDOW).toISOString();
  const [profiles, dogs, checkIns, posts, likes, reports] = (await Promise.all([
    sb.from('profiles').select('id, name'),
    sb.from('dogs').select('id, owner_id, name, breed, color, photo_url, size, comfort').order('created_at'),
    sb.from('check_ins').select('user_id, park_id, dog_ids, arrived_at').gt('arrived_at', since),
    sb.from('posts').select('id, author_id, dog_id, park_id, caption, photo_url, created_at')
      .order('created_at', { ascending: false }).limit(60),
    sb.from('post_likes').select('post_id, user_id'),
    sb.from('reports').select('post_id'),
  ])).map(must);

  data.profiles = Object.fromEntries(profiles.map((p) => [p.id, { id: p.id, name: p.name, dogIds: [] }]));
  data.dogs = {};
  for (const d of dogs) {
    data.dogs[d.id] = {
      id: d.id, name: d.name, breed: d.breed, color: d.color, photo: d.photo_url, size: d.size, comfort: d.comfort,
    };
    data.profiles[d.owner_id]?.dogIds.push(d.id);
  }
  data.me = data.profiles[myId] ?? null;
  data.checkIns = checkIns.map((c) => ({
    id: c.user_id, personId: c.user_id, parkId: c.park_id, dogIds: c.dog_ids, arrivedAt: Date.parse(c.arrived_at),
  }));
  data.posts = posts.map((p) => {
    const postLikes = likes.filter((l) => l.post_id === p.id);
    return {
      id: p.id, authorId: p.author_id, dogId: p.dog_id, parkId: p.park_id, caption: p.caption, photo: p.photo_url,
      postedAt: Date.parse(p.created_at), likes: postLikes.length, likedByMe: postLikes.some((l) => l.user_id === myId),
      emoji: '📸', colors: [data.dogs[p.dog_id]?.color ?? '#F2762E', '#F2762E'], cloud: true,
    };
  });
  data.reported = new Set(reports.map((r) => r.post_id));
}

/**
 * Listens for changes other people make. `onArrival` gets { personId, parkId } when
 * someone else checks in; `onChange` runs after the data has been reloaded.
 */
export function listen({ onChange, onArrival }) {
  if (!sb) return;
  let timer;
  let arrivals = [];
  const reload = () => {
    clearTimeout(timer);
    timer = setTimeout(async () => {
      try {
        await refresh();
      } catch (error) {
        console.warn('Refresh failed:', error);
        return;
      }
      onChange();
      arrivals.forEach(onArrival);
      arrivals = [];
    }, 300);
  };
  sb.channel('parker-hoppers')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'check_ins' }, (change) => {
      const row = change.new;
      if (change.eventType !== 'DELETE' && row?.user_id && row.user_id !== data.me?.id) {
        arrivals.push({ personId: row.user_id, parkId: row.park_id });
      }
      reload();
    })
    .on('postgres_changes', { event: '*', schema: 'public', table: 'posts' }, reload)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'post_likes' }, reload)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'dogs' }, reload)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, reload)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'friendships' }, reload)
    .subscribe();
}

async function uploadPhoto(dataUrl, userId) {
  const blob = await (await fetch(dataUrl)).blob();
  const path = `${userId}/${crypto.randomUUID()}.jpg`;
  must(await sb.storage.from('photos').upload(path, blob, { contentType: 'image/jpeg' }));
  return sb.storage.from('photos').getPublicUrl(path).data.publicUrl;
}

/** Name-only sign-up: no email or password. Creates the person and their first dog. */
export async function join(name, dog) {
  let { data: { session } } = await sb.auth.getSession();
  if (!session) {
    session = must(await sb.auth.signInAnonymously()).session;
  }
  const userId = session.user.id;
  must(await sb.from('profiles').upsert({ id: userId, name }));
  const photoUrl = dog.photo ? await uploadPhoto(dog.photo, userId) : null;
  must(await sb.from('dogs').insert({
    name: dog.name, breed: dog.breed, color: dog.color, photo_url: photoUrl, size: dog.size ?? null, comfort: dog.comfort ?? null,
  }));
  await refresh(userId);
}

export async function addDog({ name, breed, color, photo, size, comfort }) {
  const photoUrl = photo ? await uploadPhoto(photo, data.me.id) : null;
  must(await sb.from('dogs').insert({ name, breed, color, photo_url: photoUrl, size: size ?? null, comfort: comfort ?? null }));
  await refresh();
}

/** Saves changes to one of my dogs (name, breed, color, size, comfort, and optionally a new photo). */
export async function updateDog(id, { name, breed, color, size, comfort, photo }) {
  const changes = { name, breed, color, size: size ?? null, comfort: comfort ?? null };
  if (photo) changes.photo_url = await uploadPhoto(photo, data.me.id);
  must(await sb.from('dogs').update(changes).eq('id', id));
  await refresh();
}

// ---------- Friends ----------

/** Makes a new invite code (works once, for 7 days). */
export async function createInvite() {
  return must(await sb.rpc('create_invite'));
}

/** Uses a friend's invite code. Resolves the friend's name. */
export async function acceptInvite(code) {
  const name = must(await sb.rpc('accept_invite', { invite_code: code }));
  await refresh();
  return name;
}

/** Who sent an invite, if it's still valid. Works before joining. */
export async function invitePreview(code) {
  if (!sb) return null;
  const { data: name } = await sb.rpc('invite_preview', { invite_code: code });
  return name ?? null;
}

export async function removeFriend(friendId) {
  const pair = [data.me.id, friendId];
  must(await sb.from('friendships').delete().in('user_a', pair).in('user_b', pair));
  await refresh();
}

export async function checkIn(parkId, dogIds) {
  must(await sb.from('check_ins').upsert({ user_id: data.me.id, park_id: parkId, dog_ids: dogIds }, { onConflict: 'user_id' }));
  await refresh();
}

/** Asks the server to notify friends' phones about my check-in (sent once per arrival). */
export async function notifyArrival() {
  if (!sb) return;
  const { error } = await sb.functions.invoke('notify-arrival', { body: {} });
  if (error) console.warn('Couldn’t send arrival notifications:', error);
}

/** Saves this phone's notification address and which parks it wants to hear about. */
export async function savePushDevice(subscription, parkIds) {
  must(await sb.from('push_subscriptions').upsert({
    endpoint: subscription.endpoint,
    user_id: data.me.id,
    p256dh: subscription.keys.p256dh,
    auth: subscription.keys.auth,
    park_ids: parkIds,
    updated_at: new Date().toISOString(),
  }, { onConflict: 'endpoint' }));
}

export async function removePushDevice(endpoint) {
  must(await sb.from('push_subscriptions').delete().eq('endpoint', endpoint));
}

export async function checkOut() {
  must(await sb.from('check_ins').delete().eq('user_id', data.me.id));
  await refresh();
}

export async function addPost({ dogId, parkId, caption, photo }) {
  const photoUrl = photo ? await uploadPhoto(photo, data.me.id) : null;
  must(await sb.from('posts').insert({ dog_id: dogId, park_id: parkId, caption, photo_url: photoUrl }));
  await refresh();
}

export async function deletePost(postId) {
  must(await sb.from('posts').delete().eq('id', postId));
  await refresh();
}

export async function setLike(postId, liked) {
  if (liked) must(await sb.from('post_likes').insert({ post_id: postId }));
  else must(await sb.from('post_likes').delete().match({ post_id: postId, user_id: data.me.id }));
  await refresh();
}

export async function report(postId) {
  const result = await sb.from('reports').insert({ post_id: postId });
  if (result.error && result.error.code !== '23505') throw result.error; // 23505: already reported
  data.reported.add(postId);
}

/** Deletes the person, their dogs, check-ins, posts and likes, then signs out. */
export async function leave() {
  must(await sb.from('profiles').delete().eq('id', data.me.id));
  await sb.auth.signOut();
  data.me = null;
}
