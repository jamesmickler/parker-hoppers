// Which version of the app this is, shown at the bottom of the Me tab. Filled in on every
// publish by .github/workflows/pages.yml (commit and date); '__BUILD__' in local preview.
export const APP_VERSION = '__BUILD__';

// Connection details for the Supabase project. Both are meant to be public: they ship in
// the website either way, and what each person can read or change is enforced by the
// rules in supabase/migrations/. Never put the "secret" key or the database password here.
export const SUPABASE_URL = 'https://dndbyhphjvumqkjtuncn.supabase.co';
export const SUPABASE_KEY = 'sb_publishable_CPvPGu-xoE7FlLkOmzgpNg_UMLeWgnA';

// Public half of the key pair phone notifications are signed with. The private half lives
// only in Supabase's secrets, used by supabase/functions/notify-arrival.
export const VAPID_PUBLIC_KEY = 'BFIAMQxFpI-5IMrZR6af8OSfzRraFKo53LjIT-nOXtyesgE38E7L0wyRhm28sVe9zC3aCqho9Qv3TPwp-hIml2E';
