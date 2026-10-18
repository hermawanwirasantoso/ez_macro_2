# EZ Macro

A local-first Flutter app for daily calories, macros, weight, and recipes. Log food by typing, scanning a barcode, photographing a nutrition label, or reusing saved foods and recipes. Optional Claude parsing is available when you add your own API key, with Google Gemini and QwenCloud DeepSeek V4.1 as backups if Claude fails.

Data stays on the device. There is no account, no backend, and no bundled API key.

## Features

- **Daily calorie and macro log** — calories, protein, carbs, fat, plus saturated fat, fiber, added sugar, and sodium
- **Natural-language logging** — type something like `200g chicken breast` (works offline with a local estimator; uses Claude when a key is configured, then Gemini and QwenCloud DeepSeek V4.1 as backups)
- **Barcode scan** — camera scan of packaged foods, looked up on [Open Food Facts](https://world.openfoodfacts.org) (no API key)
- **Nutrition label photos** — fill an entry from a label image (Claude, with Gemini and QwenCloud backups)
- **Saved foods and recipes** — reuse custom foods, scale portions, and log multi-ingredient recipes per serving
- **Edit saved foods** — correct names, nutrition, and base portions from Quick Add → Saved Foods without changing past logs
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

## Optional AI API keys (Very Recommended for the app to fully work, since this is the core of the app)

Basic logging, saved foods, recipes, barcode lookup, weight, TDEE, and backups work without a key.

A [Claude API](https://platform.claude.com) key is the main AI provider. It unlocks natural-language parsing and nutrition-label photos using `claude-haiku-5-5` at medium effort. Add it in the app (key icon in the app bar). Keys entered there are stored only on the device in the system keychain/keystore via `flutter_secure_storage`, are never shown again after saving (only the last 4 characters), and are sent only to their own provider.

If Claude fails or is unavailable, the app falls back to a [Google AI Studio](https://aistudio.google.com) Gemini key, then to [QwenCloud](https://home.qwencloud.com/api-keys) `deepseek-v4.1-flash` at `https://dashscope-intl.aliyuncs.com/compatible-mode/v1`. Add those backup keys in the same API key sheet.

For local development you can also pass keys at build time instead of (or as a fallback to) the in-app keys. Keys passed this way are compiled into the app binary, so use them only for your own debug builds:

```bash
flutter run --dart-define=ANTHROPIC_API_KEY=your_claude_key_here --dart-define=GEMINI_API_KEY=your_gemini_key_here --dart-define=QWEN_API_KEY=your_qwen_key_here
```

`CLAUDE_API_KEY` is accepted as a Claude alias, and `CLAUDE_MODEL` overrides the model (for example `claude-opus-5-5` for better estimates on vague or mixed dishes, at roughly 40× the cost). `GOOGLE_AI_API_KEY`, `GOOGLE_API_KEY`, and `GOOGLE_AI_STUDIO_API_KEY` are accepted as Gemini aliases. `DASHSCOPE_API_KEY` and `QWENCLOUD_API_KEY` are accepted as QwenCloud aliases. Do not put a real key in source, `.env`, or `dart_defines.json` — those files are gitignored.

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
