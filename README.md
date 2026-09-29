# Park Hoppers 🐾

Park Hoppers turns spontaneous dog park visits into planned reunions. Check in when you get to the park, and friends in your network find out that your pup is there. It works the way parents coordinate playdates, but for dogs.

This is a working prototype. The parks are real Charleston off-leash areas, plus The Jasper's residents-only dog run. Everyone and every dog you see at a park is a real friend of yours who joined, shared live between phones. You only see people you've connected with through an invite. The only exception is a made-up "demo pack" (Maya, Theo, Priya, Sam and Dana, marked **demo**), who show up only when **Demo Mode** is on (Me tab), for showing off arrival alerts in a presentation.

## Try it

Open the live site on a phone for the best experience. On iPhone, tap Share → **Add to Home Screen** and it opens like an app.

- **Join:** type your first name, your dog's name, and optionally its size and how it does with other dogs. There's no email or password. Or tap **Just look around first** to explore with demo data.
- **Friends only:** nobody sees you until you connect. On **Friends**, tap **Invite a friend** to make a one-time code (it expires after 7 days) and share the link, or **Enter a friend's code**. Opening an invite link before joining shows who invited you and connects you as soon as you join. The **•••** next to a friend removes them.
- **Dog details:** each dog can have a size (small, medium, large) and a comfort level with other dogs. A park's page sums up the sizes there right now and flags dogs that are shy or need space. Tap a dog on **Me** to edit it.
- **Parks:** a map and list of dog parks with how many pups are there, and which friends. With Demo Mode on, a **🔔 Demo** button makes a made-up friend arrive.
- **Check in:** open a park, tap **We're here!** and pick which dogs came along. Friends with that park's 🔔 alerts on get a "just arrived!" notice within a second or two.
- **Auto check-in:** turn it on under **Me**. While the app is open, it checks you in after about 45 seconds inside a park you have 🔔 alerts on for, and out again 2 minutes after you leave, with an **Undo** button every time. Each park has its own zone; The Jasper's is 20 m and only trusts precise outdoor GPS, so being inside the building doesn't count. On a park's page, **Demo: pretend I just walked in** shows it off in a classroom.
- **Notifications:** flip the switch at the top of Parks to get a phone notification when a friend arrives at one of your parks, even with the app closed. On iPhone, add Park Hoppers to your Home Screen first.
- **Find my park:** the 📍 button uses your location to find the nearest dog park.
- **Moments:** share a photo from the park, like posts, and report or hide posts.
- **Plus:** the premium tier, with a home-screen widget preview.

**Me → Leave Park Hoppers** deletes your name, dogs, check-ins and posts.

## How it's built

- `web/`: the app. It's plain HTML, CSS and JavaScript with no build step. Maps use [Leaflet](https://leafletjs.com) and [OpenStreetMap](https://www.openstreetmap.org).
  - `data.js`: parks and the demo pack
  - `cloud.js`: [Supabase](https://supabase.com) for name-only sign-in, shared data, photo storage and live updates
  - `store.js`: blends real people from Supabase with the demo pack; every change the app can make
  - `app.js`: screens and interactions
- `supabase/functions/notify-arrival`: sends the "just arrived!" phone notifications (Web Push).
- `supabase/migrations/`: the database tables and access rules. People only see themselves and their friends; friendships are created only by using an invite code, and people can only change their own data. Apply with `supabase db push`.
- `ios/`: the native iPhone app in SwiftUI. It uses the same Supabase data as the website, so web and iPhone users see each other live, and it adds automatic check-in that works with your phone in your pocket: iOS wakes the app near one of your parks, then precise GPS confirms you're inside the park's own zone. It has no third-party libraries; `ios/ParkerHoppers/Supabase/` is a small built-in Supabase client.
- Every push to `main` publishes `web/` to GitHub Pages through `.github/workflows/pages.yml`.
- If Supabase can't be reached, the app falls back to the demo pack so a demo never dead-ends.

To run it locally:

```bash
python3 -m http.server 5173 --directory web
```

Then open http://localhost:5173.

Park locations and hours come from the [City of Charleston dog park list](https://charleston-sc.gov/DocumentCenter/View/33820/City-of-Charleston-Dog-Park-and-Off-Leash-Area-List-With-Map-Links?bidId=) and Charleston County Parks.
