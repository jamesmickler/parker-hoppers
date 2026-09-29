// Everything the app knows, plus every change it can make.
//
// Two sources are blended together:
// - the demo pack (Maya, Theo, ...): made up, lives only in this browser, and only shows up at
//   a park when the 🔔 demo button is tapped;
// - real people who joined, from Supabase (cloud.js), shared live between everyone's phones.

import {
  parks, parkById, dogs as seedDogs, people as seedPeople, MY_ID, FRIEND_IDS, DEFAULT_ALERT_PARKS,
} from './data.js';
import * as cloud from './cloud.js';

const KEY = 'parker-hoppers-demo-v1';
const CHECKOUT_AFTER = 90 * 60_000;
const listeners = new Set();

export let state = load();
let online = false; // true once connected to Supabase and joined

function fresh() {
  return {
    version: 2,
    dogs: structuredClone(seedDogs),
    people: structuredClone(seedPeople),
    myId: MY_ID,
    friendIds: [...FRIEND_IDS],
    checkIns: [],
    posts: [],
    alertParkIds: [...DEFAULT_ALERT_PARKS],
    hiddenAuthorIds: [],
    autoParkId: null, // the park you were checked into automatically, if any
    prefs: { alerts: true, plus: false, guest: false, autoCheckIn: false },
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
  s.hiddenAuthorIds ??= [];
  s.autoParkId ??= null;
  s.prefs.autoCheckIn ??= false;
  // Version 2: the demo pack no longer starts out at the parks or with posts, and Horse Lot and
  // The Jasper joined "Your parks". Clean that out of browsers that saved the old version.
  if ((s.version ?? 1) < 2) {
    s.posts = s.posts.filter((p) => !['p1', 'p2', 'p3', 'p4', 'p5'].includes(p.id));
    s.checkIns = s.checkIns.filter((c) => !s.friendIds.includes(c.personId));
    s.alertParkIds = [...new Set([...s.alertParkIds, 'horse-lot', 'the-jasper'])];
    s.version = 2;
  }
  expire(s);
  return s;
}

function expire(s) {
  const now = Date.now();
  s.checkIns = s.checkIns.filter((c) => now - c.arrivedAt < CHECKOUT_AFTER);
}

function save() {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch {
    // Storage full (lots of photos) or blocked: keep going in memory.
  }
}

function notify() {
  listeners.forEach((fn) => fn());
}

function commit() {
  save();
  notify();
}

export const subscribe = (fn) => listeners.add(fn);

// ---------- Connecting ----------

/**
 * Connects to Supabase. Resolves 'online' (joined), 'needs-join' (connected but not joined yet)
 * or 'offline' (no connection: demo pack only).
 */
let arrivalHandler = () => {};
let listening = false;

export async function start({ onArrival }) {
  arrivalHandler = onArrival;
  const { available, signedIn } = await cloud.connect();
  if (!available) return 'offline';
  online = signedIn;
  if (online) listen();
  return online ? 'online' : 'needs-join';
}

// Live updates start once signed in, so the database knows who's listening.
function listen() {
  if (listening) return;
  listening = true;
  cloud.listen({
    onChange: notify,
    onArrival: ({ personId, parkId }) => {
      const who = person(personId);
      if (who) arrivalHandler({ person: who, dogs: dogsOf(personId, parkId), park: parkById(parkId) });
    },
  });
}

export const isOnline = () => online;

export async function join(name, dog) {
  await cloud.join(name, dog);
  online = true;
  state.prefs.guest = false;
  listen();
  commit();
}

export function lookAround() {
  state.prefs.guest = true;
  commit();
}

export async function leave() {
  await cloud.leave();
  online = false;
  state.prefs.guest = false;
  commit();
}

export async function refresh() {
  if (!online) return;
  try {
    await cloud.refresh();
    notify();
  } catch (error) {
    console.warn('Refresh failed:', error);
  }
}

// ---------- Reading ----------

const isDemoMe = (id) => online && id === state.myId;

export const myId = () => (online ? cloud.data.me.id : state.myId);
export const dog = (id) => (online && cloud.data.dogs[id]) || state.dogs[id];
export const person = (id) => (online && cloud.data.profiles[id]) || state.people[id];
export const isDemoPerson = (id) => !(online && cloud.data.profiles[id]);
export const me = () => person(myId());
export const myDogs = () => (me()?.dogIds ?? []).map(dog).filter(Boolean);
export const alertsOn = (parkId) => state.alertParkIds.includes(parkId);

export function friends() {
  const real = online ? Object.values(cloud.data.profiles).filter((p) => p.id !== myId()) : [];
  return [...real, ...state.friendIds.map((id) => state.people[id])];
}

function allCheckIns() {
  const demo = state.checkIns.filter((c) => !isDemoMe(c.personId));
  return online ? [...demo, ...cloud.data.checkIns] : demo;
}

const hydrate = (c) => ({ ...c, person: person(c.personId), dogs: c.dogIds.map(dog).filter(Boolean) });
const newestFirst = (a, b) => b.arrivedAt - a.arrivedAt;
const current = (c) => Date.now() - c.arrivedAt < CHECKOUT_AFTER;

function dogsOf(personId, parkId) {
  const c = allCheckIns().find((x) => x.personId === personId && x.parkId === parkId);
  return c ? hydrate(c).dogs : [];
}

export const visitors = (parkId) =>
  allCheckIns().filter((c) => c.parkId === parkId && current(c) && person(c.personId)).sort(newestFirst).map(hydrate);

export const dogCount = (parkId) => visitors(parkId).reduce((n, v) => n + v.dogs.length, 0);

export const checkInFor = (personId) => allCheckIns().find((c) => c.personId === personId && current(c));

export const myCheckIn = () => {
  const c = checkInFor(myId());
  return c && hydrate(c);
};

/** The park you were checked into automatically, while you're still checked in there. */
export const autoParkId = () =>
  state.autoParkId && myCheckIn()?.parkId === state.autoParkId ? state.autoParkId : null;

export const friendCheckIns = () =>
  allCheckIns().filter((c) => c.personId !== myId() && current(c) && person(c.personId)).sort(newestFirst).map(hydrate);

export function posts() {
  const demo = state.posts.filter((p) => !isDemoMe(p.authorId));
  const real = online ? cloud.data.posts.filter((p) => !cloud.data.reported.has(p.id)) : [];
  return [...real, ...demo]
    .filter((p) => !state.hiddenAuthorIds.includes(p.authorId) && person(p.authorId))
    .sort((a, b) => b.postedAt - a.postedAt);
}

export const post = (id) => posts().find((p) => p.id === id);
const isCloudPost = (id) => online && cloud.data.posts.some((p) => p.id === id);

// ---------- Changing ----------
// Real (online) changes go to Supabase; everything else stays in this browser.

const uid = () => Math.random().toString(36).slice(2, 10);
const pick = (list) => list[Math.floor(Math.random() * list.length)];

export async function checkIn(parkId, dogIds, { auto = false } = {}) {
  if (online) {
    await cloud.checkIn(parkId, dogIds);
  } else {
    state.checkIns = state.checkIns.filter((c) => c.personId !== state.myId);
    state.checkIns.push({ id: uid(), personId: state.myId, dogIds, parkId, arrivedAt: Date.now() });
  }
  state.autoParkId = auto ? parkId : null;
  commit();
}

export async function checkOut() {
  if (online) {
    await cloud.checkOut();
  } else {
    state.checkIns = state.checkIns.filter((c) => c.personId !== state.myId);
  }
  state.autoParkId = null;
  commit();
}

/** Pretends a demo friend just walked into one of your parks, so the alert can be shown off. */
export function simulateArrival() {
  const idle = state.friendIds.filter((id) => !checkInFor(id));
  const friendId = pick(idle.length ? idle : state.friendIds);
  const parkId = pick(state.alertParkIds.length ? state.alertParkIds : parks.map((p) => p.id));
  const friend = state.people[friendId];
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

export async function toggleLike(postId) {
  const p = post(postId);
  if (!p) return;
  if (isCloudPost(postId)) {
    await cloud.setLike(postId, !p.likedByMe);
    notify();
    return;
  }
  const demo = state.posts.find((x) => x.id === postId);
  demo.likedByMe = !demo.likedByMe;
  demo.likes += demo.likedByMe ? 1 : -1;
  commit();
}

export async function addPost({ dogId, parkId, caption, photo }) {
  if (online) {
    await cloud.addPost({ dogId, parkId, caption, photo });
    notify();
    return;
  }
  const d = dog(dogId);
  state.posts.unshift({
    id: uid(), authorId: state.myId, dogId, parkId, caption, photo,
    postedAt: Date.now(), likes: 0, likedByMe: false, emoji: '📸', colors: [d.color, '#F2762E'],
  });
  commit();
}

export async function deletePost(postId) {
  if (isCloudPost(postId)) {
    await cloud.deletePost(postId);
    notify();
    return;
  }
  state.posts = state.posts.filter((p) => p.id !== postId);
  commit();
}

export async function reportPost(postId) {
  if (isCloudPost(postId)) {
    await cloud.report(postId);
    notify();
    return;
  }
  state.posts = state.posts.filter((p) => p.id !== postId);
  commit();
}

export function hidePostsFrom(personId) {
  state.hiddenAuthorIds.push(personId);
  commit();
}

export async function addDog({ name, breed, color, photo }) {
  if (online) {
    await cloud.addDog({ name, breed, color, photo });
    notify();
    return;
  }
  const id = uid();
  state.dogs[id] = { id, name, breed, color, photo };
  state.people[state.myId].dogIds.push(id);
  commit();
}

/** Called once a minute: ends old check-ins, refreshes "5 min ago" labels and re-syncs. */
export async function tick() {
  expire(state);
  save();
  if (online) await refresh();
  else notify();
}

/** Resets the demo pack. Real people and their data aren't touched. */
export function reset() {
  const { prefs, autoParkId: auto } = state;
  state = fresh();
  state.prefs = prefs;
  state.autoParkId = auto;
  commit();
}
