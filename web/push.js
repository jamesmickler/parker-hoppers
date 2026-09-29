// Phone notifications when friends arrive, even with the app closed (Web Push).
// The server side is supabase/functions/notify-arrival; sw.js shows the notifications.

import { VAPID_PUBLIC_KEY } from './config.js';

const isIPhone = /iPhone|iPad|iPod/.test(navigator.userAgent)
  || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
const onHomeScreen = window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;

let registration = null;

export const supported = () => 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;

/** iPhones only allow notifications for web apps added to the Home Screen. */
export const needsHomeScreen = () => isIPhone && !onHomeScreen;

export const blocked = () => 'Notification' in window && Notification.permission === 'denied';

export async function register() {
  if (!('serviceWorker' in navigator)) return;
  try {
    registration = await navigator.serviceWorker.register('sw.js');
  } catch (error) {
    console.warn('Background helper failed to start:', error);
  }
}

async function ready() {
  return registration ?? navigator.serviceWorker.ready;
}

export async function current() {
  if (!supported()) return null;
  return (await ready()).pushManager.getSubscription();
}

/**
 * Asks permission and signs this phone up. Call it straight from a tap: phones only show the
 * permission question in response to one.
 */
export async function subscribe() {
  if (needsHomeScreen()) throw new Error('On iPhone, add Park Hoppers to your Home Screen first (Share → Add to Home Screen).');
  if (!supported()) throw new Error('This browser can’t show notifications.');
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') throw new Error('Notifications are blocked. Allow them for Park Hoppers in your phone’s settings.');
  const pushManager = (await ready()).pushManager;
  const existing = await pushManager.getSubscription();
  const subscription = existing ?? await pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: base64UrlToBytes(VAPID_PUBLIC_KEY),
  });
  return subscription.toJSON();
}

/** Signs this phone out of notifications. Resolves the old address, if there was one. */
export async function unsubscribe() {
  const subscription = await current();
  if (!subscription) return null;
  await subscription.unsubscribe();
  return subscription.endpoint;
}

function base64UrlToBytes(text) {
  const padded = text + '='.repeat((4 - (text.length % 4)) % 4);
  const binary = atob(padded.replace(/-/g, '+').replace(/_/g, '/'));
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}
