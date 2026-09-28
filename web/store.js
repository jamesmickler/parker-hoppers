// Everything the app knows, plus every change it can make.
// For now it's saved in this browser only. When the app gets a server, this is the one
// file that changes so friends on different phones see each other.

import {
  parks, parkById, dogs as seedDogs, people as seedPeople, MY_ID, FRIEND_IDS,
  DEFAULT_ALERT_PARKS, seedCheckIns, seedPosts,
} from './data.js';

const KEY = 'parker-hoppers-demo-v1';
const CHECKOUT_AFTER = 90 * 60_000;
const listeners = new Set();

export let state = load();

function fresh() {
  const now = Date.now();
  return {
    dogs: structuredClone(seedDogs),
    people: structuredClone(seedPeople),
    myId: MY_ID,
    friendIds: [...FRIEND_IDS],
    checkIns: seedCheckIns(now),
    posts: seedPosts(now),
    alertParkIds: [...DEFAULT_ALERT_PARKS],
    prefs: { alerts: true, plus: false },
  };
}

function load() {
  let saved = null;
  try {
    saved = JSON.parse(localStorage.getItem(KEY));
  } catch {
    // Private browsing or blocked storage: start fresh.
  }
  const s = saved?.people && saved?.dogs ? saved : fresh();
  expire(s);
  // Keep the demo lively: if every friend has gone home since the last visit, bring a few back.
  if (!s.checkIns.some((c) => c.personId !== s.myId)) {
    s.checkIns.push(...seedCheckIns(Date.now()));
  }
  return s;
}

function expire(s) {
  const now = Date.now();
  s.checkIns = s.checkIns.filter((c) => now - c.arrivedAt < CHECKOUT_AFTER);
}

function commit() {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch {
    // Storage full (lots of photos) or blocked: keep going in memory.
  }
  listeners.forEach((fn) => fn());
}

export const subscribe = (fn) => listeners.add(fn);

// ---------- Reading ----------

export const dog = (id) => state.dogs[id];
export const person = (id) => state.people[id];
export const me = () => person(state.myId);
export const myDogs = () => me().dogIds.map(dog);
export const friends = () => state.friendIds.map(person);
export const post = (id) => state.posts.find((p) => p.id === id);
export const alertsOn = (parkId) => state.alertParkIds.includes(parkId);

const hydrate = (c) => ({ ...c, person: person(c.personId), dogs: c.dogIds.map(dog).filter(Boolean) });
const newestFirst = (a, b) => b.arrivedAt - a.arrivedAt;

export const visitors = (parkId) =>
  state.checkIns.filter((c) => c.parkId === parkId).sort(newestFirst).map(hydrate);

export const dogCount = (parkId) =>
  visitors(parkId).reduce((n, v) => n + v.dogs.length, parkById(parkId)?.otherDogs ?? 0);

export const checkInFor = (personId) => state.checkIns.find((c) => c.personId === personId);

export const myCheckIn = () => {
  const c = checkInFor(state.myId);
  return c && hydrate(c);
};

export const friendCheckIns = () =>
  state.checkIns.filter((c) => c.personId !== state.myId).sort(newestFirst).map(hydrate);

// ---------- Changing ----------

const uid = () => Math.random().toString(36).slice(2, 10);
const pick = (list) => list[Math.floor(Math.random() * list.length)];

export function checkIn(parkId, dogIds) {
  state.checkIns = state.checkIns.filter((c) => c.personId !== state.myId);
  state.checkIns.push({ id: uid(), personId: state.myId, dogIds, parkId, arrivedAt: Date.now() });
  commit();
}

export function checkOut() {
  state.checkIns = state.checkIns.filter((c) => c.personId !== state.myId);
  commit();
}

/** Pretends a friend just walked into one of your parks, so the alert can be demoed. */
export function simulateArrival() {
  const idle = state.friendIds.filter((id) => !checkInFor(id));
  const friendId = pick(idle.length ? idle : state.friendIds);
  const parkId = pick(state.alertParkIds.length ? state.alertParkIds : parks.map((p) => p.id));
  const friend = person(friendId);
  state.checkIns = state.checkIns.filter((c) => c.personId !== friendId);
  state.checkIns.push({ id: uid(), personId: friendId, dogIds: [...friend.dogIds], parkId, arrivedAt: Date.now() });
  commit();
  return { person: friend, dogs: friend.dogIds.map(dog), park: parkById(parkId) };
}

export function toggleAlerts(parkId) {
  state.alertParkIds = alertsOn(parkId)
    ? state.alertParkIds.filter((id) => id !== parkId)
    : [...state.alertParkIds, parkId];
  commit();
}

export function setPref(key, value) {
  state.prefs[key] = value;
  commit();
}

export function toggleLike(postId) {
  const p = post(postId);
  if (!p) return;
  p.likedByMe = !p.likedByMe;
  p.likes += p.likedByMe ? 1 : -1;
  commit();
}

export function addPost({ dogId, parkId, caption, photo }) {
  const d = dog(dogId);
  state.posts.unshift({
    id: uid(), authorId: state.myId, dogId, parkId, caption, photo,
    postedAt: Date.now(), likes: 0, likedByMe: false, emoji: '📸', colors: [d.color, '#F2762E'],
  });
  commit();
}

export function deletePost(postId) {
  state.posts = state.posts.filter((p) => p.id !== postId);
  commit();
}

export function hidePostsFrom(personId) {
  state.posts = state.posts.filter((p) => p.authorId !== personId);
  commit();
}

export function addDog({ name, breed, color, photo }) {
  const id = uid();
  state.dogs[id] = { id, name, breed, color, photo };
  me().dogIds.push(id);
  commit();
}

/** Called once a minute: ends check-ins older than 90 minutes and refreshes "5 min ago" labels. */
export function tick() {
  expire(state);
  commit();
}

export function reset() {
  state = fresh();
  commit();
}
