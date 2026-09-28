# Parker Hoppers 🐾

Parker Hoppers turns spontaneous dog park visits into planned reunions. Check in when you get to the park, and friends in your network find out that your pup is there. It works the way parents coordinate playdates, but for dogs.

This is a working prototype. The parks are real Charleston off-leash areas; the people, dogs and posts are made up.

## Try it

Open the live site on a phone for the best experience. On iPhone, tap Share → **Add to Home Screen** and it opens like an app.

- **Parks:** a map and list of dog parks with how many pups are there, and which friends. Tap the 🔔 button to simulate a friend arriving.
- **Check in:** open a park, tap **We're here!** and pick which dogs came along.
- **Find my park:** the 📍 button uses your location to find the nearest dog park.
- **Moments:** share a photo from the park, like posts, and report or hide posts.
- **Plus:** the premium tier, with a home-screen widget preview.

Your data stays in your own browser. **Me → Reset demo data** starts over.

## How it's built

- `web/`: the app. It's plain HTML, CSS and JavaScript with no build step. Maps use [Leaflet](https://leafletjs.com) and [OpenStreetMap](https://www.openstreetmap.org).
  - `data.js`: parks and demo data
  - `store.js`: app state and actions, saved in the browser
  - `app.js`: screens and interactions
- `ios/`: an earlier native iPhone prototype in SwiftUI (not maintained).
- Every push to `main` publishes `web/` to GitHub Pages through `.github/workflows/pages.yml`.

To run it locally:

```bash
python3 -m http.server 5173 --directory web
```

Then open http://localhost:5173.

Park locations and hours come from the [City of Charleston dog park list](https://charleston-sc.gov/DocumentCenter/View/33820/City-of-Charleston-Dog-Park-and-Off-Leash-Area-List-With-Map-Links?bidId=) and Charleston County Parks.
