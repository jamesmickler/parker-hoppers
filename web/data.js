// Parks are real Charleston off-leash areas (City of Charleston dog park list and
// Charleston County Parks), plus The Jasper's residents-only dog park. The demo pack's
// people, dogs and posts are made up.

export const parks = [
  {
    id: 'hazel-parker', name: 'Hazel Parker Off-Leash Area', area: 'French Quarter',
    address: '70 E Bay St', lat: 32.77483, lng: -79.92624,
    hours: [['dawn', 9], [17, 'dusk']], hoursText: 'Dawn–9 AM and 5 PM–dusk',
    fenced: false, otherDogs: 3,
  },
  {
    id: 'cannon-park', name: 'Cannon Park', area: 'Harleston Village',
    address: '131 Rutledge Ave', lat: 32.78287, lng: -79.94416,
    hours: [['dawn', 9], [17, 'dusk']], hoursText: 'Dawn–9 AM and 5 PM–dusk',
    fenced: false, otherDogs: 5,
  },
  {
    id: 'brittlebank', name: 'Brittlebank Park', area: 'West Side',
    address: '185 Lockwood Dr', lat: 32.78802, lng: -79.96057,
    hours: [['dawn', 'dusk']], hoursText: 'Dawn–dusk',
    fenced: false, otherDogs: 2,
  },
  {
    id: 'white-point', name: 'White Point Garden', area: 'South of Broad',
    address: '2 Murray Blvd', lat: 32.76981, lng: -79.93035,
    hours: [['dawn', 9], [17, 23]], hoursText: 'Dawn–9 AM and 5–11 PM',
    fenced: false, otherDogs: 4,
  },
  {
    id: 'horse-lot', name: 'Horse Lot Off-Leash Area', area: 'Harleston Village',
    address: '2 Chisolm St', lat: 32.77442, lng: -79.94154,
    hours: [['dawn', 'dusk']], hoursText: 'Dawn–dusk',
    fenced: false, otherDogs: 2,
  },
  {
    // Amenity at The Jasper apartments, not on the city's public list.
    id: 'the-jasper', name: 'The Jasper Dog Park', area: 'Harleston Village',
    address: '310 Broad St', lat: 32.77644, lng: -79.94311,
    hours: null, hoursText: 'Set by the building', access: 'Residents only',
    fenced: null, otherDogs: 2,
  },
  {
    id: 'ackerman', name: 'Ackerman Park Dog Park', area: 'West Ashley',
    address: '55 Sycamore Ave', lat: 32.78940, lng: -79.98879,
    hours: [['dawn', 'dusk']], hoursText: 'Dawn–dusk',
    fenced: true, otherDogs: 1,
  },
  {
    id: 'james-island', name: 'James Island County Park Dog Park', area: 'James Island',
    address: '871 Riverland Dr', lat: 32.73485, lng: -79.98947,
    hours: null, hoursText: 'County park hours · small entry fee',
    fenced: true, otherDogs: 6,
  },
];

export const parkById = (id) => parks.find((p) => p.id === id);

export const dogs = {
  biscuit: { id: 'biscuit', name: 'Biscuit', breed: 'Golden Retriever', color: '#F2A23A' },
  pepper: { id: 'pepper', name: 'Pepper', breed: 'Australian Shepherd', color: '#8E8E93' },
  luna: { id: 'luna', name: 'Luna', breed: 'Border Collie', color: '#5B5FD6' },
  waffles: { id: 'waffles', name: 'Waffles', breed: 'Corgi', color: '#C98A4B' },
  pickles: { id: 'pickles', name: 'Pickles', breed: 'Dachshund', color: '#34A853' },
  mochi: { id: 'mochi', name: 'Mochi', breed: 'Shiba Inu', color: '#E5484D' },
  bruno: { id: 'bruno', name: 'Bruno', breed: 'Boxer', color: '#2BB5B8' },
  olive: { id: 'olive', name: 'Olive', breed: 'Labradoodle', color: '#FF6B8B' },
};

export const MY_ID = 'me';

export const people = {
  me: { id: 'me', name: 'You', dogIds: ['biscuit', 'pepper'] },
  maya: { id: 'maya', name: 'Maya', dogIds: ['luna'] },
  theo: { id: 'theo', name: 'Theo', dogIds: ['waffles', 'pickles'] },
  priya: { id: 'priya', name: 'Priya', dogIds: ['mochi'] },
  sam: { id: 'sam', name: 'Sam', dogIds: ['bruno'] },
  dana: { id: 'dana', name: 'Dana', dogIds: ['olive'] },
};

export const FRIEND_IDS = ['maya', 'theo', 'priya', 'sam', 'dana'];

// Parks you get arrival alerts for when you first open the app.
export const DEFAULT_ALERT_PARKS = ['hazel-parker', 'cannon-park'];

const MIN = 60_000;
const HOUR = 60 * MIN;

export function seedCheckIns(now) {
  return [
    { id: `c1-${now}`, personId: 'maya', dogIds: ['luna'], parkId: 'hazel-parker', arrivedAt: now - 12 * MIN },
    { id: `c2-${now}`, personId: 'theo', dogIds: ['waffles', 'pickles'], parkId: 'hazel-parker', arrivedAt: now - 35 * MIN },
    { id: `c3-${now}`, personId: 'priya', dogIds: ['mochi'], parkId: 'brittlebank', arrivedAt: now - 5 * MIN },
  ];
}

export function seedPosts(now) {
  return [
    {
      id: 'p1', authorId: 'maya', dogId: 'luna', parkId: 'hazel-parker',
      caption: 'Luna finally caught the frisbee mid-air 🥏 Three weeks of practice!',
      postedAt: now - 50 * MIN, likes: 14, likedByMe: false, emoji: '🥏', colors: ['#5B5FD6', '#A77BF3'],
    },
    {
      id: 'p2', authorId: 'theo', dogId: 'waffles', parkId: 'cannon-park',
      caption: 'Waffles vs. the puddle. The puddle won.',
      postedAt: now - 3 * HOUR, likes: 23, likedByMe: false, emoji: '💦', colors: ['#C98A4B', '#F2A23A'],
    },
    {
      id: 'p3', authorId: 'priya', dogId: 'mochi', parkId: 'brittlebank',
      caption: 'Mochi made three new friends and refused to leave 🐾',
      postedAt: now - 6 * HOUR, likes: 9, likedByMe: false, emoji: '🐕', colors: ['#E5484D', '#FF6B8B'],
    },
    {
      id: 'p4', authorId: 'sam', dogId: 'bruno', parkId: 'james-island',
      caption: "Bruno's first swim in the lake at James Island. Zoomies achieved.",
      postedAt: now - 26 * HOUR, likes: 31, likedByMe: false, emoji: '🌊', colors: ['#2BB5B8', '#5B8DEF'],
    },
    {
      id: 'p5', authorId: 'dana', dogId: 'olive', parkId: 'white-point',
      caption: 'Golden hour at the Battery with Olive.',
      postedAt: now - 50 * HOUR, likes: 18, likedByMe: false, emoji: '🌅', colors: ['#FF6B8B', '#F2A23A'],
    },
  ];
}

// Rough Charleston sunrise/sunset by month, in hours (local time). Good enough for "dawn" and "dusk".
const SUN = [
  [7.3, 17.6], [7.1, 18.1], [7.4, 19.4], [6.9, 19.8], [6.4, 20.2], [6.2, 20.5],
  [6.4, 20.5], [6.7, 20.1], [7.0, 19.5], [7.3, 18.9], [6.8, 17.4], [7.2, 17.3],
];

/** Whether dogs can be off-leash right now, e.g. "Off-leash now · until 9 AM". */
export function offLeashStatus(park, date = new Date()) {
  if (!park.hours) return null;
  const [dawn, dusk] = SUN[date.getMonth()];
  const now = date.getHours() + date.getMinutes() / 60;
  const resolve = (t) => (t === 'dawn' ? dawn : t === 'dusk' ? dusk : t);
  const label = (t) => (typeof t === 'string' ? t : clock(t));
  for (const [a, b] of park.hours) {
    if (now >= resolve(a) && now < resolve(b)) return { open: true, text: `Off-leash now · until ${label(b)}` };
    if (now < resolve(a)) return { open: false, text: `Off-leash from ${label(a)}` };
  }
  return { open: false, text: 'Off-leash again tomorrow at dawn' };
}

function clock(h) {
  const hh = Math.floor(h);
  const mm = Math.round((h - hh) * 60);
  const suffix = hh >= 12 && hh < 24 ? 'PM' : 'AM';
  const h12 = ((hh + 11) % 12) + 1;
  return mm ? `${h12}:${String(mm).padStart(2, '0')} ${suffix}` : `${h12} ${suffix}`;
}

/** Straight-line distance between two {lat, lng} points, in meters. */
export function distanceMeters(a, b) {
  const R = 6371000;
  const rad = (x) => (x * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}
