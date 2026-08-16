# READ THIS FIRST

This zip has every `lib/` file and `pubspec.yaml` currently known to be
correct — everything we've built together, all in one place, in case your
repo has drifted from what's actually been applied.

## What's NOT in here (still only exists in your GitHub repo)

- `assets/background_template.png` — your actual mandala/logo template image
- `.github/workflows/build_apk.yml` — your CI build workflow
- `.gitignore`, `README.md`

I don't have working copies of these anymore (lost in sandbox resets along
the way) and can't pull them from your repo directly. **Do not let this zip
overwrite those files or folders** — only copy in what's listed below.

## What to actually do with this zip

1. Copy every file inside `lib/` here into your repo's `lib/` folder,
   overwriting what's there.
2. Copy `pubspec.yaml` into your repo's root, overwriting what's there.
3. Copy `assets/icon/app_icon.png` into your repo's `assets/icon/` folder
   (create that folder if it doesn't exist) — this is separate from
   `assets/background_template.png`, which you should leave untouched.
4. Do NOT touch `.github/`, `.gitignore`, or `README.md` — those aren't
   included here and your existing versions are the only copies.

## Full file list in this zip

lib/
  main.dart
  bg_removal.dart
  touchup_screen.dart
  cutout_review_screen.dart
  checkerboard.dart
  positioning_screen.dart
  templates.dart
  settings_screen.dart
  suggestions_store.dart
assets/icon/app_icon.png
pubspec.yaml

After copying, push and rebuild as usual. If the build complains about a
missing file, it's one of the three items listed above under "What's NOT
in here" — check that your existing repo still has it.
