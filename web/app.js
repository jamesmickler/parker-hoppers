// The screens, and what happens when you tap things.

import { parks, parkById, offLeashStatus, distanceMeters } from './data.js';
import * as store from './store.js';

const $view = document.getElementById('view');
const $tabs = document.getElementById('tabs');
const $banner = document.getElementById('banner');
const $sheetRoot = document.getElementById('sheet-root');

// 'loading' → then 'online' (joined), 'needs-join' (connected, not joined) or 'offline' (demo pack only)
let status = 'loading';
// A photo picked in a form that hasn't been saved yet.
let draftPhoto = null;

// ---------- Small helpers ----------

const svg = (paths) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths}</svg>`;

const icon = {
  map: svg('<path d="M9 4 3 6.5V20l6-2.5 6 2.5 6-2.5V4l-6 2.5z"/><path d="M9 4v13.5M15 6.5V20"/>'),
  photos: svg('<rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="9" cy="10" r="2"/><path d="m21 16-5-5-9 9"/>'),
  friends: svg('<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14a6.5 6.5 0 0 1 3.5 6"/>'),
  paw: svg('<g fill="currentColor" stroke="none"><ellipse cx="5.5" cy="10" rx="2" ry="2.5"/><ellipse cx="9.5" cy="5.5" rx="2" ry="2.5"/><ellipse cx="14.5" cy="5.5" rx="2" ry="2.5"/><ellipse cx="18.5" cy="10" rx="2" ry="2.5"/><path d="M12 11.5c-2.8 0-5.5 3.6-5.5 6.2 0 1.6 1.2 2.6 2.7 2.6 1 0 1.8-.6 2.8-.6s1.8.6 2.8.6c1.5 0 2.7-1 2.7-2.6 0-2.6-2.7-6.2-5.5-6.2z"/></g>'),
  bell: svg('<path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/>'),
  locate: svg('<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="8"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2"/>'),
  plus: svg('<path d="M12 5v14M5 12h14"/>'),
  chevron: svg('<path d="m9 6 6 6-6 6"/>'),
  back: svg('<path d="m15 6-6 6 6 6"/>'),
  heart: svg('<path d="M20.8 4.6a5.5 5.5 0 0 0-7.7 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.7 7.8l1 1L12 21.2l7.8-7.8 1-1a5.5 5.5 0 0 0 0-7.8z"/>'),
  more: svg('<circle cx="5" cy="12" r="1.3" fill="currentColor"/><circle cx="12" cy="12" r="1.3" fill="currentColor"/><circle cx="19" cy="12" r="1.3" fill="currentColor"/>'),
  invite: svg('<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0M19 8v6M16 11h6"/>'),
  directions: svg('<path d="m3 11 18-8-8 18-2-8z"/>'),
  camera: svg('<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>'),
};

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const safeColor = (c) => (/^#[0-9a-f]{6}$/i.test(c) ? c : '#8E8E93');

function avatar(dog, size = 40) {
  if (!dog) return '';
  const inner = dog.photo ? `<img src="${esc(dog.photo)}" alt="">` : esc(dog.name.charAt(0).toUpperCase());
  return `<span class="avatar" style="--c:${safeColor(dog.color)};--s:${size}px" title="${esc(dog.name)}">${inner}</span>`;
}

function avatars(dogs, size = 32, max = 4) {
  const shown = dogs.slice(0, max).map((d) => avatar(d, size)).join('');
  const extra = dogs.length > max
    ? `<span class="avatar more" style="--c:#8E8E93;--s:${size}px">+${dogs.length - max}</span>`
    : '';
  return `<span class="avatars">${shown}${extra}</span>`;
}

/** "Luna", "Waffles and Pickles", "Luna, Waffles, Mochi +2" */
function dogNames(dogs, limit = 3) {
  const names = dogs.map((d) => d.name);
  if (names.length <= limit) return new Intl.ListFormat('en', { type: 'conjunction' }).format(names);
  return `${names.slice(0, limit).join(', ')} +${names.length - limit}`;
}

function timeAgo(t) {
  const minutes = Math.floor((Date.now() - t) / 60_000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} hr ago`;
  return `${Math.floor(hours / 24)} d ago`;
}

function formatDistance(meters) {
  const miles = meters / 1609.34;
  return miles < 0.1 ? `${Math.round(meters * 3.281)} ft` : `${miles.toFixed(1)} mi`;
}

const toggle = (action, on, attrs = '', disabled = false) =>
  `<label class="switch"><input type="checkbox" data-change="${action}" ${attrs} ${on ? 'checked' : ''} ${disabled ? 'disabled' : ''}><span></span></label>`;

const COLORS = ['#F2A23A', '#5B8DEF', '#34A853', '#FF6B8B', '#A77BF3', '#2BB5B8', '#C98A4B', '#8E8E93'];

const swatchPicker = () => `
  <div class="swatches">
    ${COLORS.map((c, i) => `<label class="swatch" style="--c:${c}"><input type="radio" name="color" value="${c}" ${i === 1 ? 'checked' : ''} aria-label="Badge color ${i + 1}"><span></span></label>`).join('')}
  </div>`;

const dogPhotoPicker = () => `
  <label class="dog-photo-pick" aria-label="Add a photo of your dog">
    <span id="dog-photo-preview">${icon.camera}</span>
    <input type="file" accept="image/*" data-change="pick-dog-photo" class="visually-hidden">
  </label>`;

/** Turns a server error into something a person can act on. */
function friendly(error) {
  const message = String(error?.message ?? error);
  if (/anonymous sign-ins are disabled/i.test(message)) return 'Sign-ups are switched off in Supabase (Allow anonymous sign-ins).';
  if (/fetch|network|timed out/i.test(message)) return 'Check your internet connection and try again.';
  if (/rate limit/i.test(message)) return 'Too many sign-ups from this network. Try again in a bit.';
  return message;
}

/** Runs a change that talks to the server; shows a banner instead of failing silently. */
async function run(fn) {
  try {
    await fn();
    return true;
  } catch (error) {
    console.warn(error);
    showBanner('That didn’t go through', friendly(error));
    return false;
  }
}

/** Disables a form's submit button while it saves, so it can't be sent twice. */
async function submitting(form, fn) {
  const button = form.querySelector('[type=submit]');
  const label = button.innerHTML;
  button.disabled = true;
  button.textContent = 'Saving…';
  const ok = await run(fn);
  if (!ok && button.isConnected) {
    button.disabled = false;
    button.innerHTML = label;
  }
  return ok;
}

/** Shrinks a photo so it loads fast and fits in the browser's storage. */
function readImage(file, maxSize) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      const scale = Math.min(1, maxSize / Math.max(img.width, img.height));
      const canvas = document.createElement('canvas');
      canvas.width = Math.round(img.width * scale);
      canvas.height = Math.round(img.height * scale);
      canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height);
      URL.revokeObjectURL(url);
      resolve(canvas.toDataURL('image/jpeg', 0.8));
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('Could not read image'));
    };
    img.src = url;
  });
}

// ---------- Screens ----------

function parksScreen() {
  const mine = store.myCheckIn();
  const busiestFirst = (a, b) => store.dogCount(b.id) - store.dogCount(a.id);
  const myParks = parks.filter((p) => store.alertsOn(p.id)).sort(busiestFirst);
  const otherParks = parks.filter((p) => !store.alertsOn(p.id));
  return `
    <header class="topbar">
      <div><div class="eyebrow">Charleston</div><h1>Parker Hoppers</h1></div>
      <div class="topbar-actions">
        <button class="icon-btn" data-action="locate" aria-label="Find the park I'm at">${icon.locate}</button>
        <button class="icon-btn" data-action="simulate" aria-label="Demo: a friend arrives">${icon.bell}</button>
      </div>
    </header>
    ${mine ? hereCard(mine) : ''}
    <div class="map-slot" id="map-main"></div>
    ${myParks.length ? `<h2 class="section">Your parks</h2><div class="stack">${myParks.map(parkRow).join('')}</div>` : ''}
    ${otherParks.length ? `<h2 class="section">More dog parks</h2><div class="stack">${otherParks.map(parkRow).join('')}</div>` : ''}
    <p class="footnote">Park locations and hours come from the City of Charleston and Charleston County Parks. ${store.isOnline()
      ? 'Maya, Theo, Priya, Sam and Dana are a made-up demo pack; everyone else is a real person who joined.'
      : 'The people and dogs are made up for this demo.'}</p>`;
}

function hereCard(c) {
  const park = parkById(c.parkId);
  return `
    <div class="here-card">
      ${avatars(c.dogs, 40)}
      <div class="grow">
        <b>You're at ${esc(park.name)}</b>
        <div class="small muted">Checked in ${timeAgo(c.arrivedAt)} · auto check-out after 90 min</div>
      </div>
      <button class="pill-btn" data-action="checkout">Leave</button>
    </div>`;
}

function parkRow(p) {
  const dogs = store.visitors(p.id).flatMap((v) => v.dogs);
  return `
    <a class="card park-row" href="#/park/${p.id}">
      <div class="grow">
        <div class="name">${esc(p.name)}${store.alertsOn(p.id) ? ` <span class="bell-mini" title="Arrival alerts on">${icon.bell}</span>` : ''}</div>
        <div class="small muted">${esc(p.area)}</div>
        ${dogs.length
          ? `<div class="who">${avatars(dogs, 24)}<span class="small muted">${esc(dogNames(dogs, 2))}</span></div>`
          : '<div class="who small muted">No friends here yet</div>'}
      </div>
      <div class="count"><b>${store.dogCount(p.id)}</b><span>pups</span></div>
      <span class="chev">${icon.chevron}</span>
    </a>`;
}

function parkScreen(id) {
  const p = parkById(id);
  if (!p) return `<a class="back" href="#/parks">${icon.back}Parks</a><p class="empty">That park doesn't exist.</p>`;
  const visitors = store.visitors(p.id);
  const amHere = store.myCheckIn()?.parkId === p.id;
  const status = offLeashStatus(p);
  const directions = `https://maps.apple.com/?daddr=${p.lat},${p.lng}&q=${encodeURIComponent(p.name)}`;
  return `
    <a class="back" href="#/parks">${icon.back}Parks</a>
    <div class="map-slot small" id="map-detail"></div>
    <h1 class="title">${esc(p.name)}</h1>
    <div class="muted">${esc(p.area)} · ${esc(p.address)}</div>
    <div class="badges">
      ${status ? `<span class="badge ${status.open ? 'open' : ''}">${esc(status.text)}</span>` : ''}
      <span class="badge">${p.fenced ? 'Fenced' : 'Open field'}</span>
    </div>
    <div class="btn-row">
      ${amHere
        ? '<button class="btn btn-danger" data-action="checkout">Check out</button>'
        : `<button class="btn btn-primary" data-action="open-checkin" data-park="${p.id}">${icon.paw} We're here!</button>`}
      <a class="btn btn-plain btn-icon" href="${directions}" target="_blank" rel="noopener" aria-label="Directions">${icon.directions}</a>
    </div>
    <h2 class="section">At the park now</h2>
    <div class="list">
      ${visitors.length ? visitors.map(visitorRow).join('') : '<div class="row muted">None of your friends are here yet.</div>'}
      ${p.otherDogs ? `<div class="row small muted">🐾 ${p.otherDogs} more pups from outside your network</div>` : ''}
    </div>
    <div class="list-title">Park info</div>
    <div class="list">
      <div class="row"><div class="grow">Hours</div><span class="muted small right">${esc(p.hoursText)}</span></div>
      <div class="row">
        <div class="grow">Arrival alerts<div class="small muted">Get a heads-up when friends show up here</div></div>
        ${toggle('toggle-alerts', store.alertsOn(p.id), `data-park="${p.id}"`)}
      </div>
    </div>`;
}

function visitorRow(v) {
  const who = v.personId === store.myId() ? 'You' : `with ${esc(v.person.name)}`;
  return `
    <div class="row">
      ${avatars(v.dogs, 40)}
      <div class="grow"><b>${esc(dogNames(v.dogs))}</b><div class="small muted">${who} · arrived ${timeAgo(v.arrivedAt)}</div></div>
    </div>`;
}

function momentsScreen() {
  const posts = store.posts();
  return `
    <header class="topbar">
      <h1>Park Moments</h1>
      <div class="topbar-actions">
        <button class="icon-btn" data-action="open-newpost" aria-label="Share a moment">${icon.camera}</button>
      </div>
    </header>
    <div class="stack">
      ${posts.length ? posts.map(postCard).join('') : '<p class="empty">No moments yet. Share the first one!</p>'}
    </div>`;
}

function postCard(post) {
  const author = store.person(post.authorId);
  const dog = store.dog(post.dogId);
  const park = parkById(post.parkId);
  if (!author || !dog) return '';
  const isMine = post.authorId === store.myId();
  const photo = post.photo ? `<img src="${esc(post.photo)}" alt="${esc(post.caption)}">` : `<span>${post.emoji}</span>`;
  const [c1, c2] = (post.colors ?? []).map(safeColor);
  return `
    <article class="card post">
      <div class="post-head">
        ${avatar(dog, 38)}
        <div class="grow">
          <b>${esc(dog.name)}</b> <span class="muted">${isMine ? '· you' : `· with ${esc(author.name)}`}</span>
          <div class="small muted">${esc(park?.name ?? '')} · ${timeAgo(post.postedAt)}</div>
        </div>
        <button class="icon-btn flat" data-action="post-menu" data-post="${post.id}" aria-label="More options">${icon.more}</button>
      </div>
      <div class="post-photo" style="background:linear-gradient(135deg, ${c1}, ${c2})">${photo}</div>
      <div class="post-actions">
        <button class="like ${post.likedByMe ? 'on' : ''}" data-action="like" data-post="${post.id}" aria-label="Like">${icon.heart}<span>${post.likes}</span></button>
      </div>
      ${post.caption ? `<p class="caption">${esc(post.caption)}</p>` : ''}
    </article>`;
}

function friendsScreen() {
  const here = store.friendCheckIns();
  const hereRows = here.map((v) => `
    <a class="row" href="#/park/${v.parkId}">
      ${avatars(v.dogs, 40)}
      <div class="grow"><b>${esc(v.person.name)} & ${esc(dogNames(v.dogs))}</b><div class="small muted">${esc(parkById(v.parkId).name)} · ${timeAgo(v.arrivedAt)}</div></div>
      <span class="chev">${icon.chevron}</span>
    </a>`).join('');
  const packRows = store.friends().map((f) => {
    const dogs = f.dogIds.map((id) => store.dog(id)).filter(Boolean);
    return `
      <div class="row">
        ${avatars(dogs, 40)}
        <div class="grow">
          <b>${esc(f.name)}</b>${store.isDemoPerson(f.id) ? ' <span class="demo-tag">demo</span>' : ''}
          <div class="small muted">${esc(dogs.map((d) => `${d.name} the ${d.breed}`).join(', '))}</div>
        </div>
        ${store.checkInFor(f.id) ? '<span class="tag">At park</span>' : ''}
      </div>`;
  }).join('');
  return `
    <header class="topbar">
      <h1>Friends</h1>
      <div class="topbar-actions">
        <button class="icon-btn" data-action="invite" aria-label="Invite a friend">${icon.invite}</button>
      </div>
    </header>
    <div class="list-title">At the park now</div>
    <div class="list">${hereRows || '<div class="row muted">No friends at the park right now.</div>'}</div>
    <div class="list-title">Your pack</div>
    <div class="list">${packRows}</div>`;
}

function meScreen() {
  const { prefs } = store.state;
  const account = {
    online: `<div class="list-title">Account</div>
      <div class="list"><button class="row row-btn danger" data-action="leave">Leave Parker Hoppers</button></div>
      <p class="list-foot">Deletes your name, dogs, check-ins and posts from Parker Hoppers.</p>`,
    'needs-join': `<a class="card join-card" href="#/join">
        <span class="emoji">🐾</span>
        <div class="grow"><b>Join the real pack</b><div class="small muted">Right now you’re looking around with demo data. Join with just your name and your dog’s name.</div></div>
        <span class="chev">${icon.chevron}</span>
      </a>`,
    offline: '<p class="footnote">Couldn’t reach the Parker Hoppers server, so you’re seeing the demo pack only.</p>',
  }[status] ?? '';
  return `
    <header class="topbar"><h1>${store.isOnline() ? esc(store.me().name) : 'Me'}</h1></header>
    ${status === 'needs-join' ? account : ''}
    <div class="list-title">Your pack</div>
    <div class="list">
      ${store.myDogs().map((d) => `
        <div class="row">${avatar(d, 44)}<div class="grow"><b>${esc(d.name)}</b><div class="small muted">${esc(d.breed)}</div></div></div>`).join('')}
      <button class="row row-btn" data-action="open-adddog">${icon.plus} Add a dog</button>
    </div>
    <button class="card plus-card" data-action="open-plus">
      <img src="icons/icon-192.png" alt="" class="plus-icon">
      <div class="grow">
        <b>${prefs.plus ? 'You have Parker Hoppers Plus' : 'Get Parker Hoppers Plus'}</b>
        <div class="small muted">Home-screen widget, instant alerts, AirTag sharing help</div>
      </div>
      <span class="chev">${icon.chevron}</span>
    </button>
    <div class="list-title">At the park</div>
    <div class="list">
      <div class="row"><div class="grow">Friend arrival alerts</div>${toggle('toggle-pref', prefs.alerts, 'data-pref="alerts"')}</div>
      <div class="row">
        <div class="grow">Auto check-in at my parks<div class="small muted">Needs the phone app, coming later</div></div>
        ${toggle('none', false, '', true)}
      </div>
    </div>
    <div class="list-title">Privacy</div>
    <div class="list">
      <div class="row"><div class="grow">Who sees me at the park</div><span class="muted">Friends only</span></div>
      <div class="row"><div class="grow">Who sees my posts</div><span class="muted">Friends only</span></div>
    </div>
    ${status === 'needs-join' ? '' : account}
    <div class="list-title">Demo pack</div>
    <div class="list"><button class="row row-btn danger" data-action="reset">Reset demo pack</button></div>
    <p class="list-foot">Brings back Maya, Theo and the other made-up friends. Real people aren’t affected.</p>
    <p class="footnote center">Parker Hoppers · prototype</p>`;
}

function joinScreen() {
  return `
    <div class="join">
      <img class="join-icon" src="icons/icon-192.png" alt="">
      <h1>Parker Hoppers</h1>
      <p class="muted">See when your friends’ dogs are at the park, so you can meet up.</p>
      <form data-submit="join" class="stack">
        ${dogPhotoPicker()}
        <input class="field" name="name" placeholder="Your first name" required maxlength="40" autocomplete="given-name">
        <input class="field" name="dog" placeholder="Your dog’s name" required maxlength="30" autocomplete="off">
        <input class="field" name="breed" placeholder="Breed (optional)" maxlength="40" autocomplete="off">
        ${swatchPicker()}
        <button class="btn btn-primary" type="submit">${icon.paw} Join the pack</button>
      </form>
      <button class="link-btn look-around" data-action="look-around">Just look around first</button>
      <p class="footnote center">No email or password. Everyone testing Parker Hoppers can see your first name, your dogs, and the park you check in at.</p>
    </div>`;
}

const screens = {
  loading: () => '<div class="splash"><img src="icons/icon-192.png" alt="Parker Hoppers"></div>',
  join: joinScreen,
  parks: parksScreen,
  park: (r) => parkScreen(r.id),
  moments: momentsScreen,
  friends: friendsScreen,
  me: meScreen,
};

// ---------- Sheets (the panels that slide up from the bottom) ----------

let sheet = null;

const sheetHead = (title, { left = 'Cancel', right = '' } = {}) => `
  <div class="sheet-head">
    ${left ? `<button class="link-btn" data-action="close-sheet">${left}</button>` : '<span></span>'}
    <h3>${title}</h3>
    ${right ? `<button class="link-btn" data-action="close-sheet">${right}</button>` : '<span></span>'}
  </div>`;

const sheets = {
  checkin() {
    const p = parkById(sheet.parkId);
    return `
      ${sheetHead('Check in')}
      <form data-submit="checkin">
        <p class="sheet-sub">${esc(p.name)}</p>
        <div class="list-title">Who's coming along?</div>
        <div class="list">
          ${store.myDogs().map((d) => `
            <label class="row check-row">${avatar(d, 36)}<span class="grow">${esc(d.name)}</span><input type="checkbox" name="dog" value="${d.id}" checked></label>`).join('')}
        </div>
        <p class="list-foot">Your friends will see you here. You'll be checked out automatically after 90 minutes.</p>
        <button class="btn btn-primary spaced" type="submit">${icon.paw} Check in</button>
      </form>`;
  },

  nearby() {
    const p = parkById(sheet.parkId);
    const atPark = sheet.meters <= 250;
    return `
      ${sheetHead(atPark ? 'Looks like you’re at the park!' : 'Nearest dog park', { left: '', right: 'Close' })}
      <div class="card center">
        <b>${esc(p.name)}</b>
        <div class="small muted">${esc(p.area)} · ${formatDistance(sheet.meters)} away</div>
      </div>
      <div class="stack spaced">
        <button class="btn btn-primary" data-action="open-checkin" data-park="${p.id}">${icon.paw} ${atPark ? 'Check in here' : 'Pretend I’m there (demo)'}</button>
        <a class="btn btn-plain" href="#/park/${p.id}" data-action="close-sheet">View park</a>
      </div>`;
  },

  newpost() {
    const current = store.myCheckIn()?.parkId;
    return `
      ${sheetHead('New moment')}
      <form data-submit="newpost" class="stack">
        <label class="photo-pick">
          <span class="photo-preview" id="photo-preview">${icon.camera}<span>Add a photo</span></span>
          <input type="file" accept="image/*" data-change="pick-photo" class="visually-hidden">
        </label>
        <select class="field" name="dog" aria-label="Which pup">
          ${store.myDogs().map((d) => `<option value="${d.id}">${esc(d.name)}</option>`).join('')}
        </select>
        <select class="field" name="park" aria-label="Which park">
          ${parks.map((p) => `<option value="${p.id}" ${p.id === current ? 'selected' : ''}>${esc(p.name)}</option>`).join('')}
        </select>
        <textarea class="field" name="caption" placeholder="What happened at the park?" maxlength="280"></textarea>
        <button class="btn btn-primary" type="submit">Share</button>
      </form>`;
  },

  postmenu() {
    const post = store.post(sheet.postId);
    if (!post) return '';
    const author = store.person(post.authorId);
    const isMine = post.authorId === store.myId();
    return `
      <div class="stack">
        ${isMine
          ? `<button class="btn btn-danger" data-action="delete-post" data-post="${post.id}">Delete post</button>`
          : `<button class="btn btn-plain" data-action="report-post" data-post="${post.id}">🚩 Report post</button>
             <button class="btn btn-plain" data-action="hide-author" data-person="${author.id}">🙈 Hide ${esc(author.name)}’s posts</button>`}
        <button class="btn btn-plain" data-action="close-sheet"><b>Cancel</b></button>
      </div>`;
  },

  adddog() {
    return `
      ${sheetHead('Add a dog')}
      <form data-submit="adddog" class="stack">
        ${dogPhotoPicker()}
        <input class="field" name="name" placeholder="Name" required maxlength="30" autocomplete="off">
        <input class="field" name="breed" placeholder="Breed (optional)" maxlength="40" autocomplete="off">
        <div class="list-title flush">Badge color</div>
        ${swatchPicker()}
        <button class="btn btn-primary" type="submit">Save</button>
      </form>`;
  },

  plus() {
    const on = store.state.prefs.plus;
    const busiest = [...parks].sort((a, b) => store.visitors(b.id).length - store.visitors(a.id).length)[0];
    const here = store.visitors(busiest.id);
    const feature = (emoji, title, text) => `
      <div class="feature"><span class="emoji">${emoji}</span><div><b>${title}</b><div class="small muted">${text}</div></div></div>`;
    return `
      ${sheetHead('', { left: '', right: 'Close' })}
      <div class="plus-hero">
        <img src="icons/icon-192.png" alt="">
        <h2>Parker Hoppers Plus</h2>
        <p class="muted">Never miss a playdate.</p>
      </div>
      <div class="widget" aria-label="Home-screen widget preview">
        <div class="widget-top">🐾 Parker Hoppers</div>
        <div class="grow"></div>
        <b>${esc(busiest.name)}</b>
        ${avatars(here.flatMap((v) => v.dogs), 24)}
        <div class="small muted">${here.length} ${here.length === 1 ? 'friend' : 'friends'} here</div>
      </div>
      <p class="small muted center">Home-screen widget preview</p>
      <div class="stack features">
        ${feature('📱', 'Home-screen widget', 'See who’s at your parks without opening the app.')}
        ${feature('⚡️', 'Instant arrival alerts', 'Get pinged the moment a friend’s pup walks in.')}
        ${feature('📍', 'AirTag sharing, made easy', 'Step-by-step help sharing your dog’s AirTag with trusted friends in Apple’s Find My, so they can help if your pup slips away.')}
      </div>
      <button class="btn btn-primary" data-action="toggle-plus">${on ? 'Turn off Plus (demo)' : 'Try Plus (demo)'}</button>
      <p class="footnote center">Prototype only. No payment is taken.</p>`;
  },
};

function openSheet(next) {
  sheet = next;
  draftPhoto = null;
  $sheetRoot.innerHTML = `
    <div class="sheet-backdrop">
      <div class="sheet" role="dialog" aria-modal="true"><div class="grabber"></div>${sheets[sheet.type]()}</div>
    </div>`;
  document.body.classList.add('locked');
}

function closeSheet() {
  sheet = null;
  $sheetRoot.innerHTML = '';
  document.body.classList.remove('locked');
}

// ---------- Banner (the pop-down notification) ----------

let bannerTimer;

function showBanner(title, message, href = '') {
  $banner.innerHTML = `
    <img class="app-icon" src="icons/icon-192.png" alt="">
    <div class="grow"><b>${esc(title)}</b><span>${esc(message)}</span></div>
    <span class="small muted">now</span>`;
  $banner.dataset.href = href;
  $banner.hidden = false;
  $banner.style.animation = 'none';
  void $banner.offsetWidth; // restart the drop-in animation
  $banner.style.animation = '';
  clearTimeout(bannerTimer);
  bannerTimer = setTimeout(hideBanner, 4500);
}

function hideBanner() {
  $banner.hidden = true;
}

$banner.addEventListener('click', () => {
  const href = $banner.dataset.href;
  hideBanner();
  if (href) location.hash = href;
});

// ---------- Maps ----------

// Maps are made once and moved between screens, so they don't flicker on every update.
const maps = {};

// The main map opens on the peninsula; James Island and West Ashley are a drag away.
const DOWNTOWN = ['hazel-parker', 'cannon-park', 'brittlebank', 'white-point'];

function mountMap(slotId, key, list, focus) {
  const slot = document.getElementById(slotId);
  if (!slot) return;
  if (!window.L) {
    slot.innerHTML = '<div class="map-fallback">🗺️ The map needs an internet connection</div>';
    return;
  }
  let m = maps[key];
  if (!m) {
    const el = document.createElement('div');
    el.className = 'map';
    slot.appendChild(el);
    const map = L.map(el, {
      zoomControl: false, scrollWheelZoom: false, boxZoom: false, keyboard: false,
      dragging: !focus, touchZoom: !focus, doubleClickZoom: !focus,
    });
    map.attributionControl.setPrefix(false);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19, attribution: '&copy; OpenStreetMap',
    }).addTo(map);
    m = maps[key] = { el, map, layer: L.layerGroup().addTo(map), placed: false };
  } else {
    slot.appendChild(m.el);
    m.map.invalidateSize();
  }
  m.layer.clearLayers();
  for (const p of list) {
    const n = store.dogCount(p.id);
    const friendsHere = store.visitors(p.id).length > 0;
    const marker = L.marker([p.lat, p.lng], {
      keyboard: false,
      title: p.name,
      icon: L.divIcon({ className: 'pin-wrap', iconSize: null, html: `<span class="pin ${friendsHere ? 'busy' : ''}">🐾 ${n}</span>` }),
    });
    if (!focus) marker.on('click', () => { location.hash = `#/park/${p.id}`; });
    marker.addTo(m.layer);
  }
  if (focus) {
    m.map.setView([focus.lat, focus.lng], 15, { animate: false });
  } else if (!m.placed) {
    const home = list.filter((p) => DOWNTOWN.includes(p.id));
    m.map.fitBounds(L.latLngBounds(home.map((p) => [p.lat, p.lng])), { padding: [30, 30] });
    m.placed = true;
  }
}

// ---------- Rendering and routing ----------

function parseHash() {
  const [, name, arg] = location.hash.split('/');
  if (status === 'loading') return { name: 'loading' };
  const mustJoin = status === 'needs-join' && !store.state.prefs.guest;
  if (mustJoin || (name === 'join' && status === 'needs-join')) return { name: 'join' };
  if (name === 'park') return { name: 'park', id: arg, tab: 'parks' };
  if (screens[name] && name !== 'join' && name !== 'loading') return { name, tab: name };
  return { name: 'parks', tab: 'parks' };
}

let route = parseHash();

function renderTabs() {
  const tabs = [['parks', 'Parks', icon.map], ['moments', 'Moments', icon.photos], ['friends', 'Friends', icon.friends], ['me', 'Me', icon.paw]];
  $tabs.innerHTML = tabs
    .map(([id, label, ic]) => `<a class="tab ${route.tab === id ? 'active' : ''}" href="#/${id}">${ic}<span>${label}</span></a>`)
    .join('');
}

function renderView() {
  // Don't wipe out a half-filled join form when someone else's check-in arrives.
  if (route.name === 'join' && $view.querySelector('form[data-submit=join]')) return;
  $view.innerHTML = screens[route.name](route);
  $tabs.hidden = !route.tab;
  renderTabs();
  if (route.name === 'parks') mountMap('map-main', 'main', parks, null);
  if (route.name === 'park' && parkById(route.id)) mountMap('map-detail', 'detail', [parkById(route.id)], parkById(route.id));
}

window.addEventListener('hashchange', () => {
  route = parseHash();
  renderView();
  window.scrollTo(0, 0);
});

store.subscribe(renderView);

// ---------- What taps do ----------

function announceArrival({ person, dogs, park }) {
  if (!park || !store.state.prefs.alerts || !store.alertsOn(park.id)) return;
  const title = dogs.length ? `${dogNames(dogs)} just arrived!` : `${person.name} just arrived!`;
  showBanner(title, `${person.name} is at ${park.name}.`, `#/park/${park.id}`);
  navigator.vibrate?.(80);
}

function simulate() {
  announceArrival(store.simulateArrival());
}

function locate() {
  if (!navigator.geolocation) {
    showBanner('Location isn’t available', 'This browser can’t share your location.');
    return;
  }
  showBanner('Finding you…', 'Checking which dog park is closest.');
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      const here = { lat: pos.coords.latitude, lng: pos.coords.longitude };
      const [nearest] = parks
        .map((p) => ({ p, meters: distanceMeters(here, p) }))
        .sort((a, b) => a.meters - b.meters);
      hideBanner();
      openSheet({ type: 'nearby', parkId: nearest.p.id, meters: nearest.meters });
    },
    (err) => {
      showBanner('Couldn’t find your location',
        err.code === 1 ? 'Allow location access for this site, then try again.' : 'Try again in a moment.');
    },
    { enableHighAccuracy: true, timeout: 10_000, maximumAge: 60_000 },
  );
}

async function invite() {
  const text = 'Join my pack on Parker Hoppers so our dogs can meet up at the park! 🐾';
  const url = location.origin + location.pathname;
  if (navigator.share) {
    try { await navigator.share({ title: 'Parker Hoppers', text, url }); } catch { /* cancelled */ }
    return;
  }
  try {
    await navigator.clipboard.writeText(`${text} ${url}`);
    showBanner('Invite link copied', 'Paste it into a text to a friend.');
  } catch {
    showBanner('Share this link', url);
  }
}

const actions = {
  simulate,
  locate,
  invite,
  async checkout() {
    if (await run(() => store.checkOut())) showBanner('Checked out', 'Thanks for hopping by! 🐾');
  },
  'look-around'() {
    store.lookAround();
    location.hash = '#/parks';
  },
  async leave() {
    if (!confirm('Leave Parker Hoppers? This deletes your name, dogs, check-ins and posts.')) return;
    if (!(await run(() => store.leave()))) return;
    status = 'needs-join';
    location.hash = '#/join';
    route = parseHash();
    renderView();
  },
  'open-checkin': (el) => openSheet({ type: 'checkin', parkId: el.dataset.park }),
  'open-newpost': () => openSheet({ type: 'newpost' }),
  'open-adddog': () => openSheet({ type: 'adddog' }),
  'open-plus': () => openSheet({ type: 'plus' }),
  'post-menu': (el) => openSheet({ type: 'postmenu', postId: el.dataset.post }),
  'close-sheet': closeSheet,
  like: (el) => run(() => store.toggleLike(el.dataset.post)),
  async 'delete-post'(el) {
    closeSheet();
    await run(() => store.deletePost(el.dataset.post));
  },
  async 'report-post'(el) {
    closeSheet();
    if (await run(() => store.reportPost(el.dataset.post))) {
      showBanner('Thanks for letting us know', 'That post is hidden while we review it.');
    }
  },
  'hide-author'(el) {
    const p = store.person(el.dataset.person);
    store.hidePostsFrom(p.id);
    closeSheet();
    showBanner('Posts hidden', `You won’t see ${p.name}’s posts anymore.`);
  },
  'toggle-plus'() {
    store.setPref('plus', !store.state.prefs.plus);
    closeSheet();
    showBanner(store.state.prefs.plus ? 'Welcome to Plus! ✨' : 'Plus turned off', store.state.prefs.plus ? 'Your widget and instant alerts are on.' : 'You’re back on the free plan.');
  },
  reset() {
    if (!confirm('Reset the demo pack? Made-up friends, their check-ins and posts go back to the start.')) return;
    store.reset();
    showBanner('Demo pack reset', 'Maya, Theo and friends are back where they started.');
  },
};

const changes = {
  'toggle-alerts': (el) => store.toggleAlerts(el.dataset.park),
  'toggle-pref': (el) => store.setPref(el.dataset.pref, el.checked),
  async 'pick-photo'(el) {
    const file = el.files[0];
    if (!file) return;
    try {
      draftPhoto = await readImage(file, 1080);
      document.getElementById('photo-preview').innerHTML = `<img src="${draftPhoto}" alt="">`;
    } catch {
      showBanner('Couldn’t open that photo', 'Try a different one.');
    }
  },
  async 'pick-dog-photo'(el) {
    const file = el.files[0];
    if (!file) return;
    try {
      draftPhoto = await readImage(file, 320);
      document.getElementById('dog-photo-preview').innerHTML = `<img src="${draftPhoto}" alt="">`;
    } catch {
      showBanner('Couldn’t open that photo', 'Try a different one.');
    }
  },
};

const submits = {
  async join(form) {
    const data = new FormData(form);
    const name = data.get('name').trim();
    const dogName = data.get('dog').trim();
    if (!name || !dogName) return;
    const dog = { name: dogName, breed: data.get('breed').trim() || 'Good dog', color: data.get('color') || '#5B8DEF', photo: draftPhoto };
    if (!(await submitting(form, () => store.join(name, dog)))) return;
    draftPhoto = null;
    status = 'online';
    location.hash = '#/parks';
    route = parseHash();
    $view.innerHTML = '';
    renderView();
    showBanner(`Welcome to the pack, ${name}!`, `Tap a park and “We’re here!” when you and ${dogName} arrive.`);
  },
  async checkin(form) {
    const dogIds = new FormData(form).getAll('dog');
    if (!dogIds.length) {
      showBanner('Pick at least one pup', 'Who’s coming to the park?');
      return;
    }
    const park = parkById(sheet.parkId);
    if (!(await submitting(form, () => store.checkIn(park.id, dogIds)))) return;
    closeSheet();
    const names = dogNames(dogIds.map((id) => store.dog(id)).filter(Boolean));
    showBanner('You’re checked in!', `Friends can now see ${names} at ${park.name}.`);
  },
  async newpost(form) {
    const data = new FormData(form);
    const caption = data.get('caption').trim();
    if (!caption && !draftPhoto) {
      showBanner('Add a photo or a caption', 'Share what happened at the park.');
      return;
    }
    const post = { dogId: data.get('dog'), parkId: data.get('park'), caption, photo: draftPhoto };
    if (!(await submitting(form, () => store.addPost(post)))) return;
    closeSheet();
    window.scrollTo(0, 0);
  },
  async adddog(form) {
    const data = new FormData(form);
    const name = data.get('name').trim();
    if (!name) return;
    const dog = { name, breed: data.get('breed').trim() || 'Good dog', color: data.get('color') || '#5B8DEF', photo: draftPhoto };
    if (!(await submitting(form, () => store.addDog(dog)))) return;
    closeSheet();
    showBanner(`${name} joined your pack!`, 'You can bring them when you check in.');
  },
};

document.addEventListener('click', (e) => {
  if (e.target.classList?.contains('sheet-backdrop')) {
    closeSheet();
    return;
  }
  const el = e.target.closest('[data-action]');
  const fn = el && actions[el.dataset.action];
  if (!fn) return;
  if (el.tagName === 'BUTTON') e.preventDefault();
  fn(el, e);
});

document.addEventListener('change', (e) => {
  const el = e.target.closest('[data-change]');
  changes[el?.dataset.change]?.(el, e);
});

document.addEventListener('submit', (e) => {
  const form = e.target.closest('form[data-submit]');
  if (!form) return;
  e.preventDefault();
  submits[form.dataset.submit](form);
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && sheet) closeSheet();
});

// ---------- Start up ----------

renderView(); // splash while we connect
status = await store.start({ onArrival: announceArrival });
route = parseHash();
renderView();
if (status === 'offline') {
  showBanner('Showing the demo pack', 'Couldn’t reach the Parker Hoppers server, so real people won’t appear.');
}

setInterval(store.tick, 60_000);

// Phones pause pages in the background; catch up as soon as the app is open again.
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') store.refresh();
});
