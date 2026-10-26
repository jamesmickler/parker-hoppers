// The screens, and what happens when you tap things.

import { parks, parkById, offLeashStatus, distanceMeters, SIZES, COMFORT, PARTNERS, partnersNear, picksFor } from './data.js';
import * as store from './store.js';
import * as auto from './autocheckin.js';
import * as push from './push.js';

const $view = document.getElementById('view');
const $tabs = document.getElementById('tabs');
const $banner = document.getElementById('banner');
const $sheetRoot = document.getElementById('sheet-root');

// 'loading' → then 'online' (joined), 'needs-join' (connected, not joined) or 'offline' (no server)
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

/** "Large · Loves all dogs" (whatever's known about the dog). */
function dogDetails(dog) {
  return [SIZES[dog?.size]?.label, COMFORT[dog?.comfort]].filter(Boolean).join(' · ');
}

/** "K7P29QXM" → "K7P2-9QXM", easier to read out loud. */
const prettyCode = (code) => (/^[A-Z0-9]{8}$/i.test(code) ? `${code.slice(0, 4)}-${code.slice(4)}`.toUpperCase() : code);

/** The breed, unless it's the "Good dog" filler used when none was given. */
const breedOf = (dog) => (dog.breed === 'Good dog' ? '' : dog.breed);

/** Size buttons and a "with other dogs" menu, for joining and for adding or editing a dog. */
function dogDetailsFields(dog = {}) {
  return `
    <div class="list-title flush">Size</div>
    <div class="chips">
      ${Object.entries(SIZES).map(([key, size]) => `
        <label class="chip"><input type="radio" name="size" value="${key}" ${dog.size === key ? 'checked' : ''}><span><b>${size.label}</b><small>${size.hint}</small></span></label>`).join('')}
    </div>
    <div class="list-title flush">With other dogs</div>
    <select class="field" name="comfort" aria-label="Comfort with other dogs">
      <option value="">Choose one…</option>
      ${Object.entries(COMFORT).map(([key, label]) => `<option value="${key}" ${dog.comfort === key ? 'selected' : ''}>${label}</option>`).join('')}
    </select>`;
}

/** Partner offers as a list, each opening its coupon. Empty when there are none. */
function perksList(partners, title, parkId = '') {
  if (!partners.length) return '';
  return `
    <div class="list-title">${title}</div>
    <div class="list">
      ${partners.map((x) => `
        <button class="row row-link" data-action="open-perk" data-partner="${x.id}" data-park="${parkId}">
          <span class="perk-emoji">${x.emoji}</span>
          <div class="grow"><b>${esc(x.offer)}</b> <span class="demo-tag">sample</span>
            <div class="small muted">${esc(x.name)}${parkId ? ` · ${esc(x.walk)}` : ''}</div></div>
          <span class="chev">${icon.chevron}</span>
        </button>`).join('')}
    </div>`;
}

/** "Right now: 2 large · 1 small", plus a heads-up about dogs that need space or are shy. */
function parkMix(visitors) {
  const dogs = visitors.flatMap((v) => v.dogs);
  const mix = Object.entries(SIZES)
    .map(([key, size]) => [dogs.filter((d) => d.size === key).length, size.label.toLowerCase()])
    .filter(([n]) => n)
    .map(([n, label]) => `${n} ${label}`)
    .join(' · ');
  const careful = dogs.filter((d) => d.comfort === 'needs_space' || d.comfort === 'shy');
  return `
    ${mix ? `<p class="mix small muted">🐕 Right now: ${mix}</p>` : ''}
    ${careful.map((d) => `<p class="heads-up small">⚠️ ${esc(d.name)} ${d.comfort === 'needs_space' ? 'needs space from other dogs' : 'is shy and warms up slowly'}</p>`).join('')}`;
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

const swatchPicker = (selected = COLORS[1]) => `
  <div class="swatches">
    ${COLORS.map((c, i) => `<label class="swatch" style="--c:${c}"><input type="radio" name="color" value="${c}" ${c === selected ? 'checked' : ''} aria-label="Badge color ${i + 1}"><span></span></label>`).join('')}
  </div>`;

const dogPhotoPicker = (dog) => `
  <label class="dog-photo-pick" aria-label="Add a photo of your dog">
    <span id="dog-photo-preview">${dog?.photo ? `<img src="${esc(dog.photo)}" alt="">` : icon.camera}</span>
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
      <div><div class="eyebrow">Charleston</div><h1>Park Hoppers</h1></div>
      <div class="topbar-actions">
        ${store.demoMode() ? `<button class="demo-btn" data-action="simulate" aria-label="Demo: a friend arrives">${icon.bell} Demo</button>` : ''}
        <button class="icon-btn" data-action="locate" aria-label="Find the park I'm at">${icon.locate}</button>
      </div>
    </header>
    ${store.isOnline() && push.needsHomeScreen() ? `
      <button class="card home-card" data-action="open-homescreen">
        <span class="emoji">📲</span>
        <div class="grow"><b>Put Park Hoppers on your Home Screen</b>
          <div class="small muted">For notifications, and so it opens like an app. You’ll stay signed in.</div></div>
        <span class="chev">${icon.chevron}</span>
      </button>` : ''}
    ${controlsCard()}
    ${mine ? hereCard(mine) : ''}
    <div class="map-slot" id="map-main"></div>
    ${myParks.length ? `<h2 class="section">Your parks</h2><div class="stack">${myParks.map(parkRow).join('')}</div>` : ''}
    ${otherParks.length ? `<h2 class="section">More dog parks</h2><div class="stack">${otherParks.map(parkRow).join('')}</div>` : ''}
    <p class="footnote">Public park locations and hours come from the City of Charleston and Charleston County Parks.${store.demoMode()
      ? ' Demo Mode is on: tap Demo to have a made-up friend (Maya, Theo, Priya, Sam or Dana) arrive.'
      : ''}</p>`;
}

/** What the Notifications switch says, and whether it can be flipped on this phone. */
function pushInfo() {
  const p = store.pushStatus();
  if (!store.isOnline()) return { text: 'Join Park Hoppers to get notified when friends arrive', disabled: true };
  if (p.on) return { text: 'On · you’ll get a notification when friends arrive at your parks', disabled: false };
  if (p.needsHomeScreen) return { text: 'On iPhone, first add Park Hoppers to your Home Screen: tap Share, then Add to Home Screen', disabled: true };
  if (!p.supported) return { text: 'This browser can’t show notifications', disabled: true };
  if (p.blocked) return { text: 'Blocked. Allow notifications for Park Hoppers in your phone’s settings', disabled: true };
  return { text: 'Get a notification when friends arrive at your parks, even with the app closed', disabled: false };
}

/** The two switches at the top of Parks: location tracking and notifications. */
function controlsCard() {
  const { prefs } = store.state;
  const pushNow = pushInfo();
  return `
    <div class="list controls">
      <div class="row">
        <span class="control-icon">📍</span>
        <div class="grow"><b>Auto check-in</b>
          <div class="small muted">${prefs.autoCheckIn
            ? 'On · uses your location to check you in at your parks while the app is open'
            : 'Off · your location isn’t used. Turn on to check in automatically at your parks'}</div>
        </div>
        ${toggle('toggle-auto', prefs.autoCheckIn, 'aria-label="Auto check-in"')}
      </div>
      <div class="row">
        <span class="control-icon">🔔</span>
        <div class="grow"><b>Notifications</b><div class="small muted">${esc(pushNow.text)}</div></div>
        ${toggle('toggle-push', prefs.push, 'aria-label="Notifications"', pushNow.disabled && !prefs.push)}
      </div>
    </div>`;
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
        <div class="small muted">${esc(p.area)}${p.access ? ` · ${esc(p.access)}` : ''}</div>
        ${dogs.length
          ? `<div class="who">${avatars(dogs, 24)}<span class="small muted">${esc(dogNames(dogs, 2))}</span></div>`
          : '<div class="who small muted">No one here yet</div>'}
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
      ${p.access ? `<span class="badge">🔒 ${esc(p.access)}</span>` : ''}
      ${status ? `<span class="badge ${status.open ? 'open' : ''}">${esc(status.text)}</span>` : ''}
      ${p.fenced == null ? '' : `<span class="badge">${p.fenced ? 'Fenced' : 'Open field'}</span>`}
    </div>
    <div class="btn-row">
      ${amHere
        ? '<button class="btn btn-danger" data-action="checkout">Check out</button>'
        : `<button class="btn btn-primary" data-action="open-checkin" data-park="${p.id}">${icon.paw} We're here!</button>`}
      <a class="btn btn-plain btn-icon" href="${directions}" target="_blank" rel="noopener" aria-label="Directions">${icon.directions}</a>
    </div>
    <h2 class="section">At the park now</h2>
    ${parkMix(visitors)}
    <div class="list">
      ${visitors.length ? visitors.map(visitorRow).join('') : '<div class="row muted">No one’s checked in here yet.</div>'}
    </div>
    ${store.state.prefs.autoCheckIn && p.zone && !amHere
      ? `<button class="link-btn demo-arrive" data-action="pretend-arrive" data-park="${p.id}">Demo: pretend I just walked in</button>`
      : ''}
    ${perksList(partnersNear(p.id), 'Perks nearby', p.id)}
    <div class="list-title">Park info</div>
    <div class="list">
      <div class="row"><div class="grow">Hours</div><span class="muted small right">${esc(p.hoursText)}</span></div>
      <div class="row">
        <div class="grow">Auto check-in</div>
        <span class="muted small right">${p.zone ? `Within ${p.zone.radius} m${p.zone.accuracy ? ', outdoors only' : ''}` : 'Check in by hand here'}</span>
      </div>
      <div class="row">
        <div class="grow">Arrival alerts<div class="small muted">Get a heads-up when friends show up here</div></div>
        ${toggle('toggle-alerts', store.alertsOn(p.id), `data-park="${p.id}"`)}
      </div>
    </div>`;
}

function visitorRow(v) {
  const who = v.personId === store.myId() ? 'You' : `with ${esc(v.person.name)}`;
  const details = v.dogs.length === 1
    ? dogDetails(v.dogs[0])
    : v.dogs.filter((d) => dogDetails(d)).map((d) => `${d.name}: ${dogDetails(d)}`).join(' · ');
  return `
    <div class="row">
      ${avatars(v.dogs, 40)}
      <div class="grow">
        <b>${esc(dogNames(v.dogs))}</b>
        <div class="small muted">${who} · arrived ${timeAgo(v.arrivedAt)}</div>
        ${details ? `<div class="small muted">${esc(details)}</div>` : ''}
      </div>
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
    const demo = store.isDemoPerson(f.id);
    return `
      <div class="row">
        ${avatars(dogs, 40)}
        <div class="grow">
          <b>${esc(f.name)}</b>${demo ? ' <span class="demo-tag">demo</span>' : ''}
          <div class="small muted">${esc(dogs.map((d) => [d.name, dogDetails(d) || breedOf(d)].filter(Boolean).join(': ')).join(' · '))}</div>
        </div>
        ${store.checkInFor(f.id) ? '<span class="tag">At park</span>' : ''}
        ${demo ? '' : `<button class="icon-btn flat" data-action="friend-menu" data-person="${f.id}" aria-label="Options for ${esc(f.name)}">${icon.more}</button>`}
      </div>`;
  }).join('');
  return `
    <header class="topbar">
      <h1>Friends</h1>
      <div class="topbar-actions">
        <button class="icon-btn" data-action="invite" aria-label="Invite a friend">${icon.invite}</button>
      </div>
    </header>
    ${store.isOnline() ? `
      <div class="list">
        <button class="row row-btn" data-action="invite">${icon.invite} Invite a friend</button>
        <button class="row row-btn" data-action="enter-code">${icon.plus} Enter a friend’s code</button>
      </div>
      <p class="list-foot">Only friends see your name, your dogs and where you check in.</p>`
    : '<p class="footnote">Join Park Hoppers to add friends. Only friends see each other at the park.</p>'}
    <div class="list-title">At the park now</div>
    <div class="list">${hereRows || '<div class="row muted">No friends at the park right now.</div>'}</div>
    <div class="list-title">Your pack</div>
    <div class="list">${packRows || '<div class="row muted">No friends yet. Invite someone you know from the park!</div>'}</div>`;
}

function meScreen() {
  const { prefs } = store.state;
  const account = {
    online: `<div class="list-title">Account</div>
      <div class="list">
        <button class="row row-btn" data-action="open-device">${icon.invite} Use on another phone or computer</button>
        <button class="row row-btn danger" data-action="leave">Leave Park Hoppers</button>
      </div>
      <p class="list-foot">Deletes your name, dogs, check-ins and posts from Park Hoppers.</p>`,
    'needs-join': `<a class="card join-card" href="#/join">
        <span class="emoji">🐾</span>
        <div class="grow"><b>Join the real pack</b><div class="small muted">Right now you’re looking around with demo data. Join with just your name and your dog’s name.</div></div>
        <span class="chev">${icon.chevron}</span>
      </a>`,
    offline: '<p class="footnote">Couldn’t reach the Park Hoppers server, so real people won’t appear. Demo Mode still works.</p>',
  }[status] ?? '';
  return `
    <header class="topbar"><h1>${store.isOnline() ? esc(store.me().name) : 'Me'}</h1></header>
    ${status === 'needs-join' ? account : ''}
    <div class="list-title">Your pack</div>
    <div class="list">
      ${store.myDogs().map((d) => `
        <button class="row row-link" data-action="edit-dog" data-dog="${d.id}">
          ${avatar(d, 44)}
          <div class="grow"><b>${esc(d.name)}</b><div class="small muted">${esc([breedOf(d), dogDetails(d) || 'Tap to add size and comfort with other dogs'].filter(Boolean).join(' · '))}</div></div>
          <span class="chev">${icon.chevron}</span>
        </button>`).join('')}
      <button class="row row-btn" data-action="open-adddog">${icon.plus} Add a dog</button>
    </div>
    <button class="card perks-card" data-action="open-perks">
      <span class="perks-icon">🎁</span>
      <div class="grow">
        <b>Perks${store.myDogs()[0] ? ` for ${esc(store.myDogs()[0].name)}` : ''}</b>
        <div class="small muted">Deals from dog businesses near your parks, and picks for your pack</div>
      </div>
      <span class="chev">${icon.chevron}</span>
    </button>
    <div class="list-title">At the park</div>
    <div class="list">
      <div class="row">
        <div class="grow">Friend arrival pop-ups<div class="small muted">The banner at the top while Park Hoppers is open</div></div>
        ${toggle('toggle-pref', prefs.alerts, 'data-pref="alerts"')}
      </div>
      <div class="row">
        <div class="grow">Phone notifications<div class="small muted">${esc(pushInfo().text)}</div></div>
        ${toggle('toggle-push', prefs.push, '', pushInfo().disabled && !prefs.push)}
      </div>
      <div class="row">
        <div class="grow">Auto check-in at my parks<div class="small muted">While Park Hoppers is open, checks you in when you arrive at a park with 🔔 alerts on</div></div>
        ${toggle('toggle-auto', prefs.autoCheckIn)}
      </div>
    </div>
    <div class="list-title">Privacy</div>
    <div class="list">
      <div class="row"><div class="grow">Who sees me at the park</div><span class="muted">Friends only</span></div>
      <div class="row"><div class="grow">Who sees my posts</div><span class="muted">Friends only</span></div>
    </div>
    ${status === 'needs-join' ? '' : account}
    <div class="list-title">Presenting</div>
    <div class="list">
      <div class="row">
        <div class="grow">Demo Mode<div class="small muted">Adds a Demo button on the Parks tab that makes a made-up friend arrive, so you can show off alerts without a second phone</div></div>
        ${toggle('toggle-demo', prefs.demoMode)}
      </div>
      ${prefs.demoMode ? '<button class="row row-btn danger" data-action="demo-home">Send demo friends home</button>' : ''}
    </div>
    <p class="footnote center">Park Hoppers · prototype</p>`;
}

function joinScreen() {
  return `
    <div class="join">
      <img class="join-icon" src="icons/icon-192.png" alt="">
      <h1>Park Hoppers</h1>
      <p class="muted">See when your friends’ dogs are at the park, so you can meet up.</p>
      <p class="invite-note" id="invite-note" hidden></p>
      ${push.onHomeScreenApp() ? `
        <button class="card home-card" data-action="open-signin">
          <span class="emoji">🔑</span>
          <div class="grow"><b>Already joined in Safari?</b>
            <div class="small muted">Sign in with your code to pick up where you left off.</div></div>
          <span class="chev">${icon.chevron}</span>
        </button>
        <div class="list-title flush">New to Park Hoppers?</div>` : ''}
      <form data-submit="join" class="stack">
        ${dogPhotoPicker()}
        <input class="field" name="name" placeholder="Your first name" required maxlength="40" autocomplete="given-name">
        <input class="field" name="dog" placeholder="Your dog’s name" required maxlength="30" autocomplete="off">
        <input class="field" name="breed" placeholder="Breed (optional)" maxlength="40" autocomplete="off">
        ${dogDetailsFields()}
        <div class="list-title flush">Badge color</div>
        ${swatchPicker()}
        <div class="list-title flush">Invite code from a friend (optional)</div>
        <input class="field code-field" name="invite" placeholder="e.g. K7P2-9QXM" maxlength="12" autocomplete="off" autocapitalize="characters"
          value="${esc(prettyCode(store.pendingInvite() ?? ''))}">
        <button class="btn btn-primary" type="submit">${icon.paw} Join the pack</button>
      </form>
      <button class="link-btn look-around" data-action="open-signin">Already joined on another phone? Sign in with a code</button>
      <button class="link-btn look-around" data-action="look-around">Just look around first</button>
      <p class="footnote center">No email or password. Only friends (people you invite, or who invite you) can see your name, your dogs and where you check in.</p>
    </div>`;
}

const screens = {
  loading: () => '<div class="splash"><img src="icons/icon-192.png" alt="Park Hoppers"></div>',
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
    const atPark = sheet.meters <= (p.zone?.radius ?? 150);
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
        ${dogDetailsFields()}
        <div class="list-title flush">Badge color</div>
        ${swatchPicker()}
        <button class="btn btn-primary" type="submit">Save</button>
      </form>`;
  },

  editdog() {
    const d = store.dog(sheet.dogId);
    return `
      ${sheetHead(`Edit ${esc(d.name)}`)}
      <form data-submit="editdog" class="stack">
        ${dogPhotoPicker(d)}
        <input class="field" name="name" value="${esc(d.name)}" placeholder="Name" required maxlength="30" autocomplete="off">
        <input class="field" name="breed" value="${esc(breedOf(d))}" placeholder="Breed (optional)" maxlength="40" autocomplete="off">
        ${dogDetailsFields(d)}
        <div class="list-title flush">Badge color</div>
        ${swatchPicker(d.color)}
        <button class="btn btn-primary" type="submit">Save</button>
      </form>`;
  },

  invite() {
    const made = sheet.invite;
    return `
      ${sheetHead('Invite a friend', { left: '', right: 'Done' })}
      <p class="sheet-sub">Only friends see your name, your dogs and where you check in.</p>
      ${made ? `
        <div class="card center invite-card">
          <div class="qr-tile" id="invite-qr" role="img" aria-label="QR code for your invite link"></div>
          <div class="small muted">Have your friend point their phone’s camera here, or give them this code:</div>
          <div class="invite-code">${prettyCode(made.code)}</div>
          <div class="small muted">Works once, for 7 days. Only share it with people you know.</div>
        </div>
        <div class="stack spaced">
          <button class="btn btn-primary" data-action="share-invite">Share invite</button>
          <button class="btn btn-plain" data-action="copy-invite">Copy link</button>
          <button class="link-btn" data-action="make-invite">Used it? Make another invite</button>
        </div>`
      : `<button class="btn btn-primary spaced" data-action="make-invite">${icon.invite} Make an invite</button>`}
      <div class="list-title">Got a code from a friend?</div>
      <form data-submit="use-code" class="code-form">
        <input class="field" name="code" placeholder="e.g. K7P2-9QXM" maxlength="12" autocomplete="off" autocapitalize="characters" ${sheet.focusCode ? 'autofocus' : ''}>
        <button class="btn btn-plain" type="submit">Add</button>
      </form>`;
  },

  device() {
    const made = sheet.signIn;
    return `
      ${sheetHead('Use on another device', { left: '', right: 'Done' })}
      <p class="sheet-sub">Sign in as ${esc(store.me()?.name ?? 'you')} on another phone, a computer, or your Home Screen.</p>
      ${signInCodeCard(made, 'On the other device, open Park Hoppers and tap “Sign in with a code”. Or scan this with its camera.')}`;
  },

  homescreen() {
    const made = sheet.signIn;
    return `
      ${sheetHead('Add to Home Screen', { left: '', right: 'Done' })}
      <ol class="steps">
        <li>Tap the <b>Share</b> button. On newer iPhones, tap the <b>⋯</b> or <b>≡</b> menu next to the address first.</li>
        <li>Choose <b>Add to Home Screen</b> (it may be under <b>View More</b>), then <b>Add</b>.</li>
        <li>Open Park Hoppers from your Home Screen, tap <b>Already joined in Safari?</b>, and enter this code:</li>
      </ol>
      ${signInCodeCard(made, '')}`;
  },

  signin() {
    return `
      ${sheetHead('Sign in with a code')}
      <p class="sheet-sub">On the phone or browser where you already use Park Hoppers, open <b>Me → Use on another phone or computer</b>. Enter the code it shows.</p>
      <form data-submit="signin" class="stack spaced">
        <div class="code-form">
          <input class="field code-field" name="code" placeholder="e.g. K7P2-9QXM" maxlength="12" autocomplete="one-time-code" autocapitalize="characters" required>
          ${navigator.clipboard?.readText ? '<button class="btn btn-plain" type="button" data-action="paste-code">Paste</button>' : ''}
        </div>
        <button class="btn btn-primary" type="submit">Sign in</button>
      </form>`;
  },

  friendmenu() {
    const friend = store.person(sheet.personId);
    return `
      <div class="stack">
        <button class="btn btn-danger" data-action="remove-friend" data-person="${friend.id}">Remove ${esc(friend.name)} as a friend</button>
        <p class="list-foot center">You’ll stop seeing each other’s check-ins, dogs and posts.</p>
        <button class="btn btn-plain" data-action="close-sheet"><b>Cancel</b></button>
      </div>`;
  },

  perks() {
    const dogs = store.myDogs().slice(0, 2);
    const near = PARTNERS.filter((x) => x.parks.some((id) => store.alertsOn(id)));
    return `
      ${sheetHead('Perks', { left: '', right: 'Close' })}
      <p class="sheet-sub">Deals from dog businesses near your parks, and picks matched to your pack.</p>
      ${dogs.map((d) => `
        <div class="list-title">Picked for ${esc(d.name)}</div>
        <div class="list">
          ${picksFor(d).map((pick) => `
            <a class="row row-link" href="${pick.url}" target="_blank" rel="noopener">
              <span class="perk-emoji">${pick.emoji}</span>
              <div class="grow"><b>${esc(pick.title)}</b><div class="small muted">${esc(pick.why)}</div></div>
              <span class="small muted">Chewy ↗</span>
            </a>`).join('')}
        </div>
        ${dogDetails(d) ? '' : `<p class="list-foot">Add ${esc(d.name)}’s size and comfort with other dogs on the Me tab for better picks.</p>`}`).join('')}
      ${perksList(near.length ? near : PARTNERS, 'Near your parks')}
      <p class="privacy-note">🔒 Partners never see your name, your friends or where you check in. Perks only use the park you’re looking at and your dog’s size, and that stays in the app.</p>
      <button class="btn btn-plain spaced" data-action="open-partner">Own a dog business? Partner with Park Hoppers</button>
      <p class="footnote center">Prototype: the local partners and offers are samples, not real businesses. Shopping links go to Chewy.</p>`;
  },

  perk() {
    const x = PARTNERS.find((p) => p.id === sheet.partnerId);
    const from = parkById(sheet.parkId);
    const where = from
      ? `${x.walk} from ${from.name}`
      : `Near ${x.parks.map((id) => parkById(id)?.name).filter(Boolean).join(', ')}`;
    return `
      ${sheetHead('', { left: '', right: 'Done' })}
      <div class="perk-hero">
        <span class="perk-big">${x.emoji}</span>
        <h2>${esc(x.offer)}</h2>
        <p class="muted">${esc(x.name)} · ${esc(x.kind)} <span class="demo-tag">sample</span></p>
      </div>
      <div class="card center invite-card">
        <div class="small muted">Show this at the counter</div>
        <div class="invite-code">${esc(x.code)}</div>
        <div class="small muted">For Park Hoppers members</div>
      </div>
      <p class="perk-detail">${esc(x.detail)}</p>
      <p class="small muted">${esc(where)}</p>
      <p class="footnote center">Sample offer for the prototype. ${esc(x.name)} is a made-up business.</p>`;
  },

  partner() {
    const point = (emoji, title, text) => `
      <div class="feature"><span class="emoji">${emoji}</span><div><b>${title}</b><div class="small muted">${text}</div></div></div>`;
    return `
      ${sheetHead('For businesses', { left: '', right: 'Close' })}
      <div class="perk-hero">
        <span class="perk-big">🤝</span>
        <h2>Reach dog owners at the park</h2>
        <p class="muted">Groomers, daycares, vets, pet stores and dog-friendly cafés.</p>
      </div>
      <div class="stack features">
        ${point('📍', 'Show up where your customers already are', 'Your offer sits on the page of each dog park near you, seen by owners who are there or headed there.')}
        ${point('🐕', 'Reach the right dogs', 'Offers can be shown by dog size, like large-dog toys for big-dog owners.')}
        ${point('💵', 'One simple monthly price', 'A flat fee per park, for example $100 a month. No bidding, no ad auctions.')}
        ${point('🔒', 'No tracking, ever', 'You see how many people opened and used your offer, never who they are or where they’ve been.')}
      </div>
      <p class="footnote center">Prototype: partner sign-up isn’t open yet, and the price is an example.</p>`;
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
let bannerAction = null;

/** `action` adds a button to the banner, e.g. { label: 'Undo', run() {...} }. */
function showBanner(title, message, href = '', action = null) {
  bannerAction = action;
  $banner.innerHTML = `
    <img class="app-icon" src="icons/icon-192.png" alt="">
    <div class="grow"><b>${esc(title)}</b><span>${esc(message)}</span></div>
    ${action ? `<button class="banner-action">${esc(action.label)}</button>` : '<span class="small muted">now</span>'}`;
  $banner.dataset.href = href;
  $banner.hidden = false;
  $banner.style.animation = 'none';
  void $banner.offsetWidth; // restart the drop-in animation
  $banner.style.animation = '';
  clearTimeout(bannerTimer);
  bannerTimer = setTimeout(hideBanner, action ? 8000 : 4500);
}

function hideBanner() {
  $banner.hidden = true;
  bannerAction = null;
}

$banner.addEventListener('click', (e) => {
  const href = $banner.dataset.href;
  const action = bannerAction;
  hideBanner();
  if (action && e.target.closest('.banner-action')) action.run();
  else if (href) location.hash = href;
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
      icon: L.divIcon({ className: 'pin-wrap', iconSize: null, html: `<span class="pin ${friendsHere ? 'busy' : ''}">🐾${n ? ` ${n}` : ''}</span>` }),
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
  if (route.name === 'join') showInvitePreview();
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

/** The sign-in code with a QR code and a Copy button, or a placeholder while it's being made. */
function signInCodeCard(made, hint) {
  if (!made) return '<div class="card center invite-card"><div class="small muted">Making your code…</div></div>';
  return `
    <div class="card center invite-card">
      ${hint ? `<div class="qr-tile" id="signin-qr" role="img" aria-label="QR code that signs in as you"></div>
      <div class="small muted">${hint}</div>` : ''}
      <div class="invite-code">${prettyCode(made.code)}</div>
      <div class="small muted">Works once, for 30 minutes. Don’t share it: it signs in as you.</div>
    </div>
    <button class="btn btn-primary spaced" data-action="copy-signin">Copy code</button>`;
}

/** Makes a sign-in code and shows it in the sheet that asked for it. */
async function openSignInCodeSheet(type) {
  openSheet({ type });
  let made;
  if (!(await run(async () => { made = await store.createSignInCode(); }))) return closeSheet();
  if (sheet?.type !== type) return; // closed while the code was being made
  openSheet({ type, signIn: made });
  if (type === 'device') drawQr('signin-qr', made.link);
}

const QR_LIBRARY = './vendor/qrcode-generator.mjs'; // qrcode-generator 1.4.4

/** Draws a link as a QR code in the element with this id. The library loads the first time. */
async function drawQr(id, link) {
  const box = document.getElementById(id);
  try {
    const { default: qrcode } = await import(QR_LIBRARY);
    const qr = qrcode(0, 'M');
    qr.addData(link);
    qr.make();
    box.innerHTML = qr.createSvgTag({ cellSize: 4, margin: 0, scalable: true });
  } catch (error) {
    console.warn('Couldn’t draw the QR code:', error);
    box.hidden = true; // the code and the Share button still work
  }
}

/** After signing in with a code: straight to the parks, signed in as before. */
function signedIn(name) {
  status = 'online';
  location.hash = '#/parks';
  route = parseHash();
  $view.innerHTML = '';
  renderView();
  showBanner(`Welcome back${name ? `, ${name}` : ''}! 🐾`, 'You’re signed in, with your dogs and friends.');
  acceptInviteFromLink();
}

async function showInvitePreview() {
  const code = store.pendingInvite();
  if (!code) return;
  const name = await store.invitePreview(code);
  const note = document.getElementById('invite-note');
  if (!name || !note) return;
  note.textContent = `🎉 ${name} invited you to their pack. Join to become friends.`;
  note.hidden = false;
}

/** If this phone opened an invite link, use it now (once joined). */
async function acceptInviteFromLink() {
  try {
    const name = await store.acceptPendingInvite();
    if (name) showBanner(`You and ${name} are now friends! 🐾`, 'You’ll see each other’s dogs at the park.');
  } catch (error) {
    showBanner('That invite didn’t work', friendly(error));
  }
}

function announceArrival({ person, dogs, park }) {
  if (!park || !store.state.prefs.alerts || !store.alertsOn(park.id)) return;
  const title = dogs.length ? `${dogNames(dogs)} just arrived!` : `${person.name} just arrived!`;
  showBanner(title, `${person.name} is at ${park.name}.`, `#/park/${park.id}`);
  navigator.vibrate?.(80);
}

function simulate() {
  announceArrival(store.simulateArrival());
}

// ---------- Automatic check-in ----------

async function autoArrive(park) {
  const dogs = store.myDogs();
  if (!dogs.length || route.name === 'join' || store.myCheckIn()) return;
  if (!(await run(() => store.checkIn(park.id, dogs.map((d) => d.id), { auto: true })))) return;
  navigator.vibrate?.(60);
  showBanner(`You’re at ${park.name}`, `Checked in ${dogNames(dogs)} automatically.`, `#/park/${park.id}`, {
    label: 'Undo',
    run: () => run(() => store.checkOut()),
  });
}

async function autoLeave(park) {
  if (await run(() => store.checkOut())) {
    showBanner('Checked out', `Looks like you left ${park.name}. See you next time! 🐾`);
  }
}

function startAutoCheckIn() {
  return auto.start({
    watching: () => (store.myCheckIn() ? [] : parks.filter((p) => store.alertsOn(p.id))),
    autoParkId: store.autoParkId,
    arrive: autoArrive,
    leave: autoLeave,
    denied() {
      store.setPref('autoCheckIn', false);
      showBanner('Location is off', 'Allow location access for this site to use auto check-in.');
    },
  });
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


const actions = {
  simulate,
  locate,
  invite() {
    if (!store.isOnline()) {
      showBanner('Join first', 'Join Park Hoppers to invite friends.');
      return;
    }
    openSheet({ type: 'invite' });
  },
  'enter-code'() {
    openSheet({ type: 'invite', focusCode: true });
    document.querySelector('form[data-submit=use-code] input')?.focus();
  },
  async 'make-invite'() {
    let made;
    if (await run(async () => { made = await store.createInvite(); })) {
      openSheet({ type: 'invite', invite: made });
      drawQr('invite-qr', made.link);
    }
  },
  async 'share-invite'() {
    const { code, link } = sheet.invite;
    const text = `Join my pack on Park Hoppers so our dogs can meet up at the park! 🐾 Tap the link, or enter code ${code.slice(0, 4)}-${code.slice(4)} on the Friends tab.`;
    if (navigator.share) {
      try { await navigator.share({ title: 'Park Hoppers invite', text, url: link }); } catch { /* cancelled */ }
      return;
    }
    await actions['copy-invite']();
  },
  async 'copy-invite'() {
    try {
      await navigator.clipboard.writeText(sheet.invite.link);
      showBanner('Invite link copied', 'Paste it into a text to a friend. It works once.');
    } catch {
      showBanner('Copy this link', sheet.invite.link);
    }
  },
  'friend-menu': (el) => openSheet({ type: 'friendmenu', personId: el.dataset.person }),
  async 'remove-friend'(el) {
    const friend = store.person(el.dataset.person);
    closeSheet();
    if (await run(() => store.removeFriend(friend.id))) {
      showBanner('Friend removed', `You and ${friend.name} no longer see each other.`);
    }
  },
  'edit-dog': (el) => openSheet({ type: 'editdog', dogId: el.dataset.dog }),
  'open-device': () => openSignInCodeSheet('device'),
  'open-homescreen': () => openSignInCodeSheet('homescreen'),
  'open-signin': () => openSheet({ type: 'signin' }),
  async 'copy-signin'() {
    try {
      await navigator.clipboard.writeText(sheet.signIn.code);
      showBanner('Code copied', 'Paste it on the other device within 30 minutes.');
    } catch {
      showBanner('Your code', prettyCode(sheet.signIn.code));
    }
  },
  async 'paste-code'() {
    try {
      const text = await navigator.clipboard.readText();
      const code = text.match(/[A-Z0-9]{4}-?[A-Z0-9]{4}/i)?.[0];
      if (code) document.querySelector('form[data-submit=signin] input').value = prettyCode(code.replace('-', ''));
      else showBanner('Nothing to paste', 'Copy your code on the other device first.');
    } catch {
      // Paste was declined: the code can still be typed.
    }
  },
  async checkout() {
    if (await run(() => store.checkOut())) showBanner('Checked out', 'Thanks for hopping by! 🐾');
  },
  'pretend-arrive'(el) {
    autoArrive(parkById(el.dataset.park));
  },
  'look-around'() {
    store.lookAround();
    location.hash = '#/parks';
  },
  async leave() {
    if (!confirm('Leave Park Hoppers? This deletes your name, dogs, check-ins and posts.')) return;
    if (!(await run(() => store.leave()))) return;
    status = 'needs-join';
    location.hash = '#/join';
    route = parseHash();
    renderView();
  },
  'open-checkin': (el) => openSheet({ type: 'checkin', parkId: el.dataset.park }),
  'open-newpost': () => openSheet({ type: 'newpost' }),
  'open-adddog': () => openSheet({ type: 'adddog' }),
  'open-perks': () => openSheet({ type: 'perks' }),
  'open-perk': (el) => openSheet({ type: 'perk', partnerId: el.dataset.partner, parkId: el.dataset.park }),
  'open-partner': () => openSheet({ type: 'partner' }),
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
  'demo-home'() {
    store.sendDemoPackHome();
    showBanner('Demo friends went home', 'Maya, Theo and friends left the parks.');
  },
};

const changes = {
  'toggle-alerts': (el) => store.toggleAlerts(el.dataset.park),
  'toggle-pref': (el) => store.setPref(el.dataset.pref, el.checked),
  'toggle-demo'(el) {
    store.setDemoMode(el.checked);
    showBanner(el.checked ? 'Demo Mode is on' : 'Demo Mode is off',
      el.checked ? 'Tap Demo on the Parks tab to have a made-up friend arrive.' : 'The demo friends are gone.');
  },
  async 'toggle-push'(el) {
    const on = el.checked;
    // Straight into enablePush: phones only ask for permission in direct response to a tap.
    const ok = await run(() => (on ? store.enablePush() : store.disablePush()));
    if (!ok) {
      renderView(); // put the switch back
      return;
    }
    showBanner(on ? 'Notifications are on' : 'Notifications are off', on
      ? 'You’ll get a notification when friends arrive at your parks, even with the app closed.'
      : 'You won’t get notifications when friends arrive.');
  },
  'toggle-auto'(el) {
    store.setPref('autoCheckIn', el.checked);
    if (!el.checked) {
      auto.stop();
      return;
    }
    if (!startAutoCheckIn()) {
      store.setPref('autoCheckIn', false);
      showBanner('Location isn’t available', 'This browser can’t share your location.');
      return;
    }
    const mine = parks.filter((p) => store.alertsOn(p.id) && p.zone).map((p) => p.name);
    showBanner('Auto check-in is on', mine.length
      ? `While the app is open, you’ll be checked in at ${new Intl.ListFormat('en').format(mine)}.`
      : 'Turn on 🔔 Arrival alerts for a park to use it there.');
  },
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
    const dog = {
      name: dogName, breed: data.get('breed').trim() || 'Good dog', color: data.get('color') || '#5B8DEF', photo: draftPhoto,
      size: data.get('size') || null, comfort: data.get('comfort') || null,
    };
    store.rememberInvite(data.get('invite').trim());
    if (!(await submitting(form, () => store.join(name, dog)))) return;
    draftPhoto = null;
    status = 'online';
    location.hash = '#/parks';
    route = parseHash();
    $view.innerHTML = '';
    renderView();
    showBanner(`Welcome to the pack, ${name}!`, `Tap a park and “We’re here!” when you and ${dogName} arrive.`);
    acceptInviteFromLink();
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
    const dog = {
      name, breed: data.get('breed').trim() || 'Good dog', color: data.get('color') || '#5B8DEF', photo: draftPhoto,
      size: data.get('size') || null, comfort: data.get('comfort') || null,
    };
    if (!(await submitting(form, () => store.addDog(dog)))) return;
    closeSheet();
    showBanner(`${name} joined your pack!`, 'You can bring them when you check in.');
  },
  async editdog(form) {
    const data = new FormData(form);
    const name = data.get('name').trim();
    if (!name) return;
    const changes = {
      name, breed: data.get('breed').trim() || 'Good dog', color: data.get('color') || '#5B8DEF', photo: draftPhoto,
      size: data.get('size') || null, comfort: data.get('comfort') || null,
    };
    if (!(await submitting(form, () => store.updateDog(sheet.dogId, changes)))) return;
    closeSheet();
    showBanner(`${name} is updated`, 'Friends see the new details at the park.');
  },
  async signin(form) {
    const code = new FormData(form).get('code').trim();
    if (!code) return;
    let name;
    if (!(await submitting(form, async () => { name = await store.signInWithCode(code); }))) return;
    closeSheet();
    signedIn(name);
  },
  async 'use-code'(form) {
    const code = new FormData(form).get('code').trim();
    if (!code) return;
    let name;
    if (!(await submitting(form, async () => { name = await store.acceptInvite(code); }))) return;
    closeSheet();
    showBanner(`You and ${name} are now friends! 🐾`, 'You’ll see each other’s dogs at the park.');
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
window.parkHoppersStarted = true; // stops index.html's "taking a while" message
push.register(); // the background helper that shows notifications while the app is closed
status = await store.start({ onArrival: announceArrival });
route = parseHash();
renderView();
if (status === 'offline') {
  showBanner('You’re offline', 'Couldn’t reach the Park Hoppers server, so real people won’t appear.');
}
if (store.state.prefs.autoCheckIn) startAutoCheckIn();
if (status === 'online') acceptInviteFromLink();
if (status === 'needs-join' && store.linkSignIn()) {
  let name;
  if (await run(async () => { name = await store.signInWithCode(store.linkSignIn()); })) signedIn(name);
}

setInterval(store.tick, 60_000);

// Phones pause pages in the background; catch up as soon as the app is open again.
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') store.refresh();
});
