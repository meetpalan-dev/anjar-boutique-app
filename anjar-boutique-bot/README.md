# Anjar Boutique — Post Generator

Android app: pick a product photo -> composites it onto the Anjar Boutique
branded template (mandala + logo) -> fill in a short details form -> get a
ready-to-post image + caption, copy or share directly.

## What's in this repo

- `lib/main.dart` — the whole app (photo picker, compositing, form, caption, share)
- `assets/background_template.png` — your branded background (mandala + logo)
- `.github/workflows/build_apk.yml` — builds the APK automatically in the cloud
- `pubspec.yaml` — dependencies

There's no `android/` folder committed — the build workflow generates it
fresh every run with `flutter create .`, so you don't need Android Studio or
the Flutter SDK on your own machine at all.

## One-time setup

1. Create a new GitHub repo (e.g. `anjar-boutique-app`) under your account.
2. Push this folder's contents to it:
   ```
   git init
   git add .
   git commit -m "Initial app"
   git branch -M main
   git remote add origin https://github.com/meetpalan-dev/anjar-boutique-app.git
   git push -u origin main
   ```
3. On GitHub, go to the repo's **Actions** tab — the build should already be
   running (or click "Build APK" → "Run workflow" to trigger it manually).
4. Once it finishes (green check, a few minutes), open that run and download
   the **anjar-boutique-apk** artifact — it's a zip containing `app-release.apk`.
5. Transfer the APK to your phone (or open the Actions page on the phone's
   browser and download directly) and install it. You'll need to allow
   "install from unknown sources" the first time, since it's not from the
   Play Store.

Every time you push a change to `main`, a fresh APK is built automatically —
just re-download the new artifact.

## If the photo placement looks off

Open `lib/main.dart` and adjust the `CompositeConfig` values near the top —
`boxLeft`/`boxTop`/`boxWidth`/`boxHeight` define the rectangle (in template
pixels) that the product photo is scaled to fit inside, centered. The
current values leave the top-left logo badge clear and let the mandala show
around the edges, matching your reference poster. Push the change and a new
APK builds automatically.

## Swapping the template

If you get an updated background design later, just replace
`assets/background_template.png` with the new file (same name) and push —
no code changes needed as long as the new template is the same 1080x1080
size. If it's a different size, update `CompositeConfig` to match.

## Caption format

Caption is a fixed template (not AI-generated) — see `buildCaption()` in
`lib/main.dart`. Any field left blank in the form is simply skipped in the
output. Hashtags are a fixed block, also editable in the same function.
