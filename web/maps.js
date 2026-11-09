// Google Maps for the Parks map and each park's page, turned on by GOOGLE_MAPS_KEY in
// config.js. Without a key, or if Google can't be reached or refuses the key, app.js uses
// the built-in OpenStreetMap map (vendor/leaflet) instead, so there's always a map.
import { GOOGLE_MAPS_KEY } from './config.js';

// For checking changes on this Mac: http://localhost:5173/?google-maps shows Google Maps even
// without a key (Google marks it "For development purposes only").
const previewWithoutKey = location.hostname === 'localhost' && new URLSearchParams(location.search).has('google-maps');

let failed = false;
let onFailure = () => {};

export const googleMapsOn = () => !failed && (Boolean(GOOGLE_MAPS_KEY) || previewWithoutKey);

/** `fn` runs if Google rejects the key (wrong site, billing off), so app.js can switch maps. */
export function onGoogleMapsFailure(fn) {
  onFailure = fn;
}

// Google calls this when the key is refused.
window.gm_authFailure = () => {
  console.warn('Google Maps refused the key; using the built-in map.');
  failed = true;
  onFailure();
};

let library = null;

/** Loads Google's map code once. Resolves the google.maps namespace, or null if it can't. */
function load() {
  library ??= new Promise((resolve) => {
    window.parkHoppersGoogleMaps = async () => {
      try {
        await google.maps.importLibrary('maps');
        resolve(google.maps);
      } catch {
        resolve(null);
      }
    };
    const params = new URLSearchParams({ loading: 'async', callback: 'parkHoppersGoogleMaps', v: 'weekly' });
    if (GOOGLE_MAPS_KEY) params.set('key', GOOGLE_MAPS_KEY);
    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?${params}`;
    script.async = true;
    script.onerror = () => resolve(null);
    document.head.append(script);
    setTimeout(() => resolve(null), 15000); // no answer: use the built-in map
  });
  return library;
}

const maps = {};

/**
 * Shows a Google map in the element with id `slotId`, with a pin for each place.
 * `focus` centers on one place (and the map can't be dragged); otherwise the map fits
 * `fitTo`, and tapping a pin calls `onPick(place)`. Resolves false if Google isn't available.
 */
export async function mountGoogleMap(slotId, key, places, { focus, fitTo, pinHtml, onPick }) {
  const g = await load();
  if (!g || failed) return false;
  const slot = document.getElementById(slotId);
  if (!slot) return true; // the screen changed while Google was loading
  let m = maps[key];
  if (!m) {
    const el = document.createElement('div');
    el.className = 'map';
    slot.replaceChildren(el);
    const map = new g.Map(el, {
      disableDefaultUI: true,
      clickableIcons: false, // Google's own places don't pop up info boxes
      keyboardShortcuts: false,
      gestureHandling: focus ? 'none' : 'greedy',
      styles: [{ featureType: 'poi.business', stylers: [{ visibility: 'off' }] }],
    });
    m = maps[key] = { el, map, pins: [], placed: false };
  } else {
    slot.replaceChildren(m.el);
  }
  for (const pin of m.pins) pin.setMap(null);
  m.pins = places.map((p) => addPin(g, m.map, p, pinHtml(p), focus ? null : () => onPick(p)));
  if (focus) {
    m.map.setCenter({ lat: focus.lat, lng: focus.lng });
    m.map.setZoom(15);
  } else if (!m.placed) {
    const bounds = new g.LatLngBounds();
    for (const p of fitTo) bounds.extend({ lat: p.lat, lng: p.lng });
    m.map.fitBounds(bounds, 30);
    m.placed = true;
  }
  return true;
}

/** A pin made of our own HTML (the 🐾 bubble with the dog count), placed on the map. */
function addPin(g, map, place, html, onClick) {
  const at = new g.LatLng(place.lat, place.lng);
  const pin = new g.OverlayView();
  pin.onAdd = function onAdd() {
    this.div = document.createElement('div');
    this.div.className = 'gpin';
    this.div.title = place.name;
    this.div.innerHTML = html;
    if (onClick) this.div.addEventListener('click', onClick);
    g.OverlayView.preventMapHitsAndGesturesFrom(this.div);
    this.getPanes().overlayMouseTarget.append(this.div);
  };
  pin.draw = function draw() {
    const point = this.getProjection().fromLatLngToDivPixel(at);
    if (point) {
      this.div.style.left = `${point.x}px`;
      this.div.style.top = `${point.y}px`;
    }
  };
  pin.onRemove = function onRemove() {
    this.div.remove();
  };
  pin.setMap(map);
  return pin;
}
