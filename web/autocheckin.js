// Automatic check-in while the app is open. Watches your location and checks you in once
// you've stayed inside one of your parks' zones for a bit, and out again once you've
// clearly left. Phones stop sharing a website's location when the screen locks, so this
// only works while Park Hoppers is on screen; true background check-in needs a native app.

import { parks, distanceMeters } from './data.js';

const STAY_FOR = 45_000;        // inside the zone this long before checking in
const LEAVE_AFTER = 2 * 60_000; // well outside the zone this long before checking out
const LEAVE_BUFFER = 100;       // meters past the zone's edge that count as "left"
const RECHECK_EVERY = 10_000;   // phones sit still without new readings, so re-judge the last one

let watchId = null;
let timer = null;
let lastReading = null;
let arriving = null; // { parkId, since }
let leaving = null;  // when we first saw you well outside the park you were auto-checked into

/** Whether a reading puts you inside a park's zone, with GPS precise enough to trust. */
export function isInside(park, { lat, lng, accuracy }) {
  if (!park.zone) return false;
  const { radius, accuracy: maxAccuracy = Math.max(30, radius) } = park.zone;
  return accuracy <= maxAccuracy && distanceMeters({ lat, lng }, park) <= radius;
}

/**
 * Starts watching. `rules` supplies, at each reading:
 * - watching(): parks you could be auto-checked into right now (empty if you're checked in)
 * - autoParkId(): the park you were automatically checked into, if still checked in there
 * - arrive(park) / leave(park): do the check-in or check-out
 * - denied(): location permission was refused
 */
export function start(rules) {
  stop();
  if (!navigator.geolocation) return false;
  watchId = navigator.geolocation.watchPosition(
    ({ coords }) => {
      lastReading = { lat: coords.latitude, lng: coords.longitude, accuracy: coords.accuracy };
      judge(rules);
    },
    (error) => {
      if (error.code === error.PERMISSION_DENIED) {
        stop();
        rules.denied();
      }
    },
    { enableHighAccuracy: true, maximumAge: 10_000, timeout: 30_000 },
  );
  timer = setInterval(() => lastReading && judge(rules), RECHECK_EVERY);
  return true;
}

export function stop() {
  if (watchId != null) navigator.geolocation.clearWatch(watchId);
  clearInterval(timer);
  watchId = timer = lastReading = arriving = leaving = null;
}

function judge(rules, now = Date.now()) {
  const reading = lastReading;
  const autoParkId = rules.autoParkId();

  if (autoParkId) {
    arriving = null;
    const park = parks.find((p) => p.id === autoParkId);
    const farAway = distanceMeters(reading, park) > park.zone.radius + LEAVE_BUFFER && reading.accuracy < 100;
    if (!farAway) {
      leaving = null;
    } else if (!leaving) {
      leaving = now;
    } else if (now - leaving >= LEAVE_AFTER) {
      leaving = null;
      rules.leave(park);
    }
    return;
  }

  leaving = null;
  const park = rules.watching().find((p) => isInside(p, reading));
  if (!park) {
    arriving = null;
  } else if (arriving?.parkId !== park.id) {
    arriving = { parkId: park.id, since: now };
  } else if (now - arriving.since >= STAY_FOR) {
    arriving = null;
    rules.arrive(park);
  }
}
