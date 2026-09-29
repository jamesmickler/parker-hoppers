// Sends a phone notification to friends when someone arrives at a park.
//
// The app (web or iPhone) calls this right after checking in. It works out who's calling
// from their sign-in, reads their current check-in, and notifies every other person's
// device that has that park in "Your parks". Each arrival is sent once (check_ins.notified).
//
// Deploy: supabase functions deploy notify-arrival --no-verify-jwt --use-api
// Secrets: VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT (supabase secrets set ...)

import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

// Keep in sync with web/data.js and ios/ParkerHoppers/Parks.swift.
const PARK_NAMES: Record<string, string> = {
  "hazel-parker": "Hazel Parker Off-Leash Area",
  "cannon-park": "Cannon Park",
  "brittlebank": "Brittlebank Park",
  "white-point": "White Point Garden",
  "horse-lot": "Horse Lot Off-Leash Area",
  "the-jasper": "The Jasper Dog Park",
  "ackerman": "Ackerman Park Dog Park",
  "james-island": "James Island County Park Dog Park",
};

// Arrivals older than this aren't news anymore.
const FRESH_FOR_MS = 5 * 60_000;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

webpush.setVapidDetails(
  Deno.env.get("VAPID_SUBJECT")!,
  Deno.env.get("VAPID_PUBLIC_KEY")!,
  Deno.env.get("VAPID_PRIVATE_KEY")!,
);

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

function dogNames(names: string[]): string {
  if (names.length <= 1) return names[0] ?? "";
  if (names.length === 2) return `${names[0]} and ${names[1]}`;
  return `${names.slice(0, -1).join(", ")} and ${names.at(-1)}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  // Who's calling: their own sign-in token, checked by Supabase.
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: { user } } = await admin.auth.getUser(token);
  if (!user) return reply({ error: "Not signed in" }, 401);

  const { data: checkIn } = await admin
    .from("check_ins")
    .select("park_id, dog_ids, arrived_at, notified")
    .eq("user_id", user.id)
    .maybeSingle();
  if (!checkIn || checkIn.notified || Date.now() - Date.parse(checkIn.arrived_at) > FRESH_FOR_MS) {
    return reply({ sent: 0, reason: "nothing new" });
  }
  await admin.from("check_ins").update({ notified: true }).eq("user_id", user.id);

  const [{ data: profile }, { data: dogs }, { data: devices }] = await Promise.all([
    admin.from("profiles").select("name").eq("id", user.id).maybeSingle(),
    admin.from("dogs").select("name").in("id", checkIn.dog_ids),
    admin.from("push_subscriptions")
      .select("endpoint, p256dh, auth")
      .neq("user_id", user.id)
      .contains("park_ids", [checkIn.park_id]),
  ]);

  const who = profile?.name ?? "A friend";
  const pups = dogNames((dogs ?? []).map((d) => d.name));
  const park = PARK_NAMES[checkIn.park_id] ?? "the park";
  const payload = JSON.stringify({
    title: pups ? `${pups} just arrived!` : `${who} just arrived!`,
    body: `${who} is at ${park}.`,
    url: `./#/park/${checkIn.park_id}`,
    tag: `arrival-${user.id}`,
  });

  let sent = 0;
  await Promise.all((devices ?? []).map(async (device) => {
    try {
      await webpush.sendNotification(
        { endpoint: device.endpoint, keys: { p256dh: device.p256dh, auth: device.auth } },
        payload,
        { TTL: 60 * 60, urgency: "high" },
      );
      sent++;
    } catch (error) {
      const status = (error as { statusCode?: number }).statusCode;
      // The phone turned notifications off or the app was removed: forget that device.
      if (status === 404 || status === 410) {
        await admin.from("push_subscriptions").delete().eq("endpoint", device.endpoint);
      } else {
        console.error("Push failed", status, (error as Error).message);
      }
    }
  }));

  return reply({ sent, devices: devices?.length ?? 0 });
});
