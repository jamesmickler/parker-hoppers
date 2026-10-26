// Parks are real Charleston off-leash areas (City of Charleston dog park list and
// Charleston County Parks), plus The Jasper's residents-only dog park. The demo pack's
// people and dogs are made up; they only show up at a park when the 🔔 demo button is tapped.

// `zone` is the circle (in meters) where automatic check-in kicks in, and `accuracy` the
// worst GPS precision it will trust there. `zone: null` means manual check-in only.
export const parks = [
  {
    id: 'hazel-parker', name: 'Hazel Parker Off-Leash Area', area: 'French Quarter',
    address: '70 E Bay St', lat: 32.77483, lng: -79.92624,
    hours: [['dawn', 9], [17, 'dusk']], hoursText: 'Dawn–9 AM and 5 PM–dusk',
    fenced: false, zone: { radius: 60 },
  },
  {
    id: 'cannon-park', name: 'Cannon Park', area: 'Harleston Village',
    address: '131 Rutledge Ave', lat: 32.78287, lng: -79.94416,
    hours: [['dawn', 9], [17, 'dusk']], hoursText: 'Dawn–9 AM and 5 PM–dusk',
    fenced: false, zone: { radius: 80 },
  },
  {
    id: 'brittlebank', name: 'Brittlebank Park', area: 'West Side',
    address: '185 Lockwood Dr', lat: 32.78802, lng: -79.96057,
    hours: [['dawn', 'dusk']], hoursText: 'Dawn–dusk',
    fenced: false, zone: { radius: 120 },
  },
  {
    id: 'white-point', name: 'White Point Garden', area: 'South of Broad',
    address: '2 Murray Blvd', lat: 32.76981, lng: -79.93035,
    hours: [['dawn', 9], [17, 23]], hoursText: 'Dawn–9 AM and 5–11 PM',
    fenced: false, zone: { radius: 100 },
  },
  {
    id: 'horse-lot', name: 'Horse Lot Off-Leash Area', area: 'Harleston Village',
    address: '2 Chisolm St', lat: 32.77442, lng: -79.94154,
    hours: [['dawn', 'dusk']], hoursText: 'Dawn–dusk',
    fenced: false, zone: { radius: 50 },
  },
  {
    // Amenity at The Jasper apartments, not on the city's public list.
    id: 'the-jasper', name: 'The Jasper Dog Park', area: 'Harleston Village',
    address: '310 Broad St', lat: 32.776453, lng: -79.943101,
    hours: null, hoursText: 'Set by the building', access: 'Residents only',
    fenced: null,
    // Tight circle on the dog run itself, trusting only precise (outdoor) GPS, so being
    // inside the building doesn't count.
    zone: { radius: 20, accuracy: 15 },
  },
  {
    id: 'ackerman', name: 'Ackerman Park Dog Park', area: 'West Ashley',
    address: '55 Sycamore Ave', lat: 32.78940, lng: -79.98879,
    hours: [['dawn', 'dusk']], hoursText: 'Dawn–dusk',
    fenced: true, zone: { radius: 90 },
  },
  {
    id: 'james-island', name: 'James Island County Park Dog Park', area: 'James Island',
    address: '871 Riverland Dr', lat: 32.73485, lng: -79.98947,
    hours: null, hoursText: 'County park hours · small entry fee',
    fenced: true,
    // Where the dog park sits inside the 600-acre county park isn't mapped, so no auto check-in.
    zone: null,
  },
];

export const parkById = (id) => parks.find((p) => p.id === id);

export const dogs = {
  biscuit: { id: 'biscuit', name: 'Biscuit', breed: 'Golden Retriever', color: '#F2A23A', size: 'large', comfort: 'loves_all' },
  pepper: { id: 'pepper', name: 'Pepper', breed: 'Australian Shepherd', color: '#8E8E93', size: 'medium', comfort: 'shy' },
  luna: { id: 'luna', name: 'Luna', breed: 'Border Collie', color: '#5B5FD6', size: 'medium', comfort: 'loves_all' },
  waffles: { id: 'waffles', name: 'Waffles', breed: 'Corgi', color: '#C98A4B', size: 'small', comfort: 'big_dogs' },
  pickles: { id: 'pickles', name: 'Pickles', breed: 'Dachshund', color: '#34A853', size: 'small', comfort: 'small_dogs' },
  mochi: { id: 'mochi', name: 'Mochi', breed: 'Shiba Inu', color: '#E5484D', size: 'medium', comfort: 'needs_space' },
  bruno: { id: 'bruno', name: 'Bruno', breed: 'Boxer', color: '#2BB5B8', size: 'large', comfort: 'loves_all' },
  olive: { id: 'olive', name: 'Olive', breed: 'Labradoodle', color: '#FF6B8B', size: 'large', comfort: 'shy' },
};

// Dog details. Keys are stored in the database (dogs.size, dogs.comfort); keep them in sync
// with ios/ParkerHoppers/Models.swift.
export const SIZES = {
  small: { label: 'Small', hint: 'under 25 lb' },
  medium: { label: 'Medium', hint: '25–50 lb' },
  large: { label: 'Large', hint: 'over 50 lb' },
};

export const COMFORT = {
  loves_all: 'Loves all dogs',
  small_dogs: 'Best with small dogs',
  big_dogs: 'Best with big dogs',
  shy: 'Shy, warms up slowly',
  needs_space: 'Needs space from other dogs',
};

// ---------- Perks ----------
// How Park Hoppers makes money: local dog businesses near each park pay for a spot on that
// park's page, and shopping picks matched to your dog could earn a small commission.
// These partners are SAMPLES for the prototype: made-up businesses with made-up offers.
// Partners never see who you are, your friends or your check-ins.

export const PARTNERS = [
  { id: 'harbor-hound', name: 'Harbor Hound Grooming', kind: 'Grooming', emoji: '🛁',
    offer: '10% off a bath', detail: 'Bath, brush and nail trim. Walk-ins welcome after park time.',
    code: 'HOPBATH10', parks: ['hazel-parker', 'white-point'], walk: '4 min walk' },
  { id: 'pup-and-pour', name: 'Pup & Pour Coffee', kind: 'Dog-friendly café', emoji: '☕️',
    offer: 'Free pup cup with any drink', detail: 'A little cup of whipped cream for your dog. Patio seating, water bowls out front.',
    code: 'HOPCUP', parks: ['cannon-park', 'horse-lot', 'the-jasper'], walk: '3 min walk' },
  { id: 'village-bark', name: 'Village Bark Supply', kind: 'Pet store', emoji: '🦴',
    offer: '15% off treats and toys', detail: 'Local pet shop with treats, toys and leashes. Free water refills.',
    code: 'HOPTREATS15', parks: ['cannon-park', 'horse-lot', 'the-jasper', 'brittlebank'], walk: '6 min walk' },
  { id: 'westside-daycare', name: 'Westside Dog Daycare', kind: 'Daycare', emoji: '🏡',
    offer: 'First day of daycare free', detail: 'Supervised playgroups sorted by size and temperament.',
    code: 'HOPDAY1', parks: ['brittlebank', 'ackerman'], walk: '5 min drive' },
  { id: 'live-oak-vet', name: 'Live Oak Animal Clinic', kind: 'Vet', emoji: '🩺',
    offer: 'Free nail trim with a checkup', detail: 'Checkups, vaccines and a friendly front desk.',
    code: 'HOPVET', parks: ['ackerman', 'james-island', 'white-point'], walk: '7 min drive' },
];

export const partnersNear = (parkId) => PARTNERS.filter((p) => p.parks.includes(parkId));

const chewySearch = (query) => `https://www.chewy.com/s?query=${encodeURIComponent(query)}`;

/** Up to three shopping picks for a dog, based on its size and how it does with other dogs. */
export function picksFor(dog) {
  const name = dog.name;
  const picks = [];
  if (dog.size === 'large') {
    picks.push({ emoji: '🦴', title: 'Tough chew toys', why: `${name} is a big dog`,
      url: 'https://www.chewy.com/f/tough-chewer-dog-chew-toys_c316_f58v382923' });
  } else if (dog.size === 'small') {
    picks.push({ emoji: '🧸', title: 'Toys for small dogs', why: `Sized for ${name}`,
      url: 'https://www.chewy.com/f/small-dog-toys_c315_f6v13790' });
  } else {
    picks.push({ emoji: '🎾', title: 'Fetch toys', why: 'For open fields like the off-leash areas',
      url: chewySearch('dog fetch toys') });
  }
  if (dog.comfort === 'shy' || dog.comfort === 'needs_space') {
    picks.push({ emoji: '💛', title: 'Yellow “I need space” leash', why: 'A sign other owners recognize',
      url: chewySearch('yellow dog leash give me space') });
    picks.push({ emoji: '🌿', title: 'Calming treats', why: 'For busy park days',
      url: chewySearch('calming treats for dogs') });
  } else if (dog.comfort === 'loves_all') {
    picks.push({ emoji: '🥏', title: 'Flying discs', why: `${name} loves a crowd`, url: chewySearch('dog frisbee') });
  }
  picks.push({ emoji: '💧', title: 'Collapsible water bowl', why: 'For long park days',
    url: 'https://www.chewy.com/f/travel-dog-bowls-dishes_c1422_f86v69996' });
  return picks.slice(0, 3);
}

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

// "Your parks" (arrival alerts on) when you first open the app.
export const DEFAULT_ALERT_PARKS = ['hazel-parker', 'cannon-park', 'horse-lot', 'the-jasper'];

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
