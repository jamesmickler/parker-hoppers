// One-time sign-in codes: use the same Park Hoppers account on another phone, a laptop,
// or the iPhone Home Screen app (which doesn't share Safari's storage).
//
//   POST { action: "create" }          signed in → { code, expiresAt }
//   POST { action: "redeem", code }    anyone    → { tokenHash, name }
//
// The app turns `tokenHash` into its own session with auth.verifyOtp({ token_hash, type:
// "magiclink" }), so each device has a separate session for the same person. Codes work
// once and last 30 minutes (table public.sign_in_codes, migration 20261021190000).
//
// Deploy: supabase functions deploy sign-in-code --no-verify-jwt --use-api

import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

// No 0/O or 1/I, so codes are easy to read out and type.
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const newCode = () => Array.from(crypto.getRandomValues(new Uint8Array(8)), (b) => ALPHABET[b % 32]).join("");

async function create(req: Request) {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: { user } } = await admin.auth.getUser(token);
  if (!user) return reply({ error: "Join Park Hoppers first." }, 401);
  const { data: profile } = await admin.from("profiles").select("id").eq("id", user.id).maybeSingle();
  if (!profile) return reply({ error: "Join Park Hoppers first." }, 401);

  // One live code per person: making a new one cancels the old.
  await admin.from("sign_in_codes").delete().eq("user_id", user.id).is("used_at", null);
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = newCode();
    const { data, error } = await admin.from("sign_in_codes").insert({ code, user_id: user.id })
      .select("expires_at").single();
    if (!error) return reply({ code, expiresAt: data.expires_at });
    if (error.code !== "23505") throw error; // 23505: that code is taken, try another
  }
  throw new Error("Couldn't make a code");
}

async function redeem(raw: unknown) {
  const code = String(raw ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");
  // Mark it used in the same step that checks it, so a code can't be used twice.
  const { data: row } = await admin.from("sign_in_codes")
    .update({ used_at: new Date().toISOString() })
    .eq("code", code).is("used_at", null).gt("expires_at", new Date().toISOString())
    .select("user_id").maybeSingle();
  if (!row) {
    return reply({ error: "That sign-in code doesn’t work. Codes last 30 minutes and work once, so make a new one." }, 400);
  }

  const { data: { user }, error } = await admin.auth.admin.getUserById(row.user_id);
  if (error || !user) return reply({ error: "That account no longer exists." }, 400);

  // Sign-in links need an email address, and name-only accounts don't have one. Give the
  // account a private placeholder that can never receive mail (.invalid is reserved).
  let email = user.email;
  if (!email) {
    email = `${user.id}@users.parkhoppers.invalid`;
    const { error: updateError } = await admin.auth.admin.updateUserById(user.id, { email, email_confirm: true });
    if (updateError) throw updateError;
  }
  // Makes a one-time sign-in token without sending any email.
  const { data: link, error: linkError } = await admin.auth.admin.generateLink({ type: "magiclink", email });
  if (linkError) throw linkError;

  const { data: profile } = await admin.from("profiles").select("name").eq("id", user.id).maybeSingle();
  return reply({ tokenHash: link.properties.hashed_token, name: profile?.name ?? null });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const body = await req.json().catch(() => ({}));
    if (body.action === "create") return await create(req);
    if (body.action === "redeem") return await redeem(body.code);
    return reply({ error: "Unknown action" }, 400);
  } catch (error) {
    console.error("sign-in-code failed:", error);
    return reply({ error: "Something went wrong. Try again in a moment." }, 500);
  }
});
