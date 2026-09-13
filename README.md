# EZ Macro

A local-first Flutter app for daily calories, macros, weight, and recipes. Log food by typing, scanning a barcode, photographing a nutrition label, or reusing saved foods and recipes. Optional Google Gemini parsing is available when you add your own API key.

Data stays on the device. There is no account, no backend, and no bundled API key.

## Features

- **Daily calorie and macro log** — calories, protein, carbs, fat, plus saturated fat, fiber, added sugar, and sodium
- **Natural-language logging** — type something like `200g chicken breast` (works offline with a local estimator; uses Gemini when a key is configured)
- **Barcode scan** — camera scan of packaged foods, looked up on [Open Food Facts](https://world.openfoodfacts.org) (no API key)
- **Nutrition label photos** — fill an entry from a label image (Gemini)
- **Saved foods and recipes** — reuse custom foods, scale portions, and log multi-ingredient recipes per serving
- **Log again / copy day** — re-log a recent meal or copy a previous day’s entries
- **Weight tracker** — weigh-ins, goal, and trend chart
- **TDEE calculator** — estimate maintenance calories and apply them as daily targets
- **Weekly and monthly insights** — logging streaks, macro averages, calorie delta, and a weight-goal projection
- **Backup** — export/import JSON, plus CSV export of nutrition history
- **Dark and light themes**

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) 3.13 or later
- A device or emulator with a camera if you want barcode or label scanning

## Run

```bash
flutter pub get
flutter test
flutter run
```

## Optional Gemini API key

Basic logging, saved foods, recipes, barcode lookup, weight, TDEE, and backups work without a key.

A [Google AI Studio](https://aistudio.google.com) Gemini key unlocks better natural-language parsing and nutrition-label photos. Add it in the app (key icon in the app bar). It is stored only on the device via `flutter_secure_storage`.

You can also pass a key at build time instead of (or as a fallback to) the in-app key:

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

`GOOGLE_AI_API_KEY`, `GOOGLE_API_KEY`, and `GOOGLE_AI_STUDIO_API_KEY` are accepted as aliases. Do not put a real key in source, `.env`, or `dart_defines.json` — those files are gitignored.

## Project layout

```
lib/
  main.dart
  features/
    calorie_tracker/   daily log, saved foods, AI parser, label scan
    barcode/           camera scanner and Open Food Facts lookup
    recipes/           multi-ingredient recipes
    weight_tracker/    weigh-ins and goals
    tdee_calculator/   TDEE estimate
    insights/          weekly/monthly insights and backup
test/
```

## License

Personal project. Add a license file if you want others to reuse the code.
