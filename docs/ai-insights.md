# AI Energy Advisor (Gemini)

Once a day (06:00, Africa/Lusaka) the `dailyInsights` Cloud Function turns the last 24 hours of data into a short plain-language report and shows it on the Flutter dashboard under **Energy advisor**, immediately below the energy overview.

```
RTDB (readings, energy, alerts) -> buildSummary() -> GeminiService (key x model chain) -> systems/<id>/insights/latest -> app card
      numbers only, no names/IDs      insights.js          gemini_service.js                       text only
```

**What the AI can and cannot do**
- It only writes text (headline, summary, up to 3 tips, up to 2 things to watch).
- It cannot switch a relay, change a setting, reset the safety cut-off or write anywhere except `insights/latest` (database rules do not allow apps to write there; only the function can).
- If the readings look wrong (for example about 20 V or 25 A on a 12 V battery) it says so and only suggests checking or calibrating the sensors. It is told not to give energy advice on data it cannot trust.
- If every model/key fails, a simple rule-based summary is written instead. The app labels it **Summary · no AI**, so you can always tell which one you are looking at.

## How the fallback chain works (same format as the Steadfast service)

| File | Role | Steadfast equivalent |
|---|---|---|
| `functions/gemini_service.js` | `GeminiModelConfig`, `GeminiService`, the exception classes | `gemini_service.dart` |
| `functions/gemini_service_setup.js` | `buildGeminiService(...)`: keys x models, each key's models grouped together | `gemini_service_setup.dart` |

The chain is tried top to bottom: key 1 with every model, then key 2 with every model, and so on (up to 6 keys x 5 models = 30 configs).

| Response | What happens |
|---|---|
| 429 rate limit / quota | next config |
| 404 model not found | next config |
| 401/403, or 400 "API key not valid" | next config (the next KEY may work). *Small extension to the Dart version* |
| anything else (400 bad request, 5xx, blocked prompt, empty answer) | thrown immediately; the advisor writes the rule-based summary |

The key is sent in the `x-goog-api-key` header (not in the URL, unlike `?key=` in the Dart version) so it cannot end up in request logs, and error messages never contain it. Default models are the same five as the Steadfast chain; Google retires model names from time to time, so check them with `tools/check_gemini.js`.

Why this runs in the Cloud Function and not in the Flutter app: the job runs daily even when nobody opens the app, and a key inside an app can be extracted from the APK. Here the keys live in Firebase Secret Manager.

## 1. Check your keys (no deployment needed)

Create keys at https://aistudio.google.com/apikey (use separate Google Cloud projects: rate limits are per project, so separate projects give separate quotas). On your computer (Node 18+):

```bash
GEMINI_API_KEYS="key1,key2,key3" node tools/check_gemini.js
```

It prints one line per key (accepted or rejected, and how many chain models that key can use), then makes one real call through the chain and tells you **which key and model answered**.

| Message | Meaning / fix |
|---|---|
| `No key set` | Run with `GEMINI_API_KEYS="..."` in front |
| `key #n: rejected by Google (HTTP 400/401/403)` | That key is wrong or disabled: create a new one. Other keys still work |
| `not available to this key: ...` | That model name is not valid for this key. Set `GEMINI_MODELS=<names it lists>` |
| `None of the models in the chain exist` | Same, for every key |
| `rate limited right now (HTTP 429)` | Free-tier quota used up; the chain moves to the next config |
| `cannot reach generativelanguage.googleapis.com` | No internet or a firewall is blocking it |

## 2. See what the advisor writes (still no deployment)

```bash
GEMINI_API_KEYS="key1,key2" node tools/try_insights.js normal
GEMINI_API_KEYS="key1,key2" node tools/try_insights.js evening-low
GEMINI_API_KEYS="key1,key2" node tools/try_insights.js bad-sensors
node tools/try_insights.js no-key        # rule-based fallback, Gemini is not called
```

Each run prints the exact summary that is sent to Gemini and then the result with `source: gemini` (and the model) or `source: rules` (and the reason).

**How to judge the result (pass / fail)**

| Scenario | The answer should... |
|---|---|
| `normal` | mention the battery range and use numbers from the summary; tips about running big loads when solar produces; no invented values |
| `evening-low` | say the battery ran low in the evening; one tip about the evening drain; mention the low-battery alerts |
| `bad-sensors` | say the **readings look unreliable**, name the voltage/current problem, suggest checking or calibrating, and give **no** energy-saving advice. This is the most important test |
| `no-key` | work without AI and be labelled `source: rules` |

Also confirm every number in the tips can be found in the printed summary (the AI must not make numbers up). Keep the printed outputs: they are your evidence for the report (add a test T-AI to Chapter 6).

## 3. Deploy

```bash
cd functions && npm install && cd ..
firebase functions:secrets:set GEMINI_API_KEYS      # paste ALL keys on one line, separated by commas (up to 6)
firebase deploy --only functions
```

For local Functions Emulator testing, add the same comma-separated keys to `functions/.secret.local`:

```
GEMINI_API_KEYS=key1,key2
```

This local file is excluded from Git and is only for the emulator. Production Functions read the Firebase Secret Manager value set by `firebase functions:secrets:set`; editing `.secret.local` does not update the deployed secret. Never commit or share either secret.

Optional settings (asked for at deploy, or put them in `functions/.env`):

```
GEMINI_MODELS=gemini-3.6-flash,gemini-3.5-flash     # empty = the default chain
BATTERY_NOMINAL_V=12
BATTERY_AH=20
```

To switch it off for one system, set `systems/<id>/settings/aiInsights` to `false` in the database.

## 4. Test it end to end (is the AI really being used?)

The job normally runs at 06:00. To run it now: Google Cloud console > **Cloud Scheduler** > job `firebase-schedule-dailyInsights-...` > **Force run**. (Or: `gcloud scheduler jobs run firebase-schedule-dailyInsights-<region> --location=<region>`.)

Then check three places:

1. **Database:** `systems/<id>/insights/latest`
   - `source: "gemini"` and `model: "<name>"` = the AI wrote it.
   - `source: "rules"` = fallback. The reason is in the function log (step 3).
   - `generatedAt` should be the current time in milliseconds.
2. **App:** Dashboard > Energy advisor. The chip must say **AI · advisory only** (not "Summary · no AI").
3. **Function log:** `firebase functions:log --only dailyInsights`. Look for `insight generated` with `source`, `model`, `configIndex` (0-based position in the chain) and `error` (empty when Gemini answered). Lines `gemini config #N (model) skipped: GeminiRateLimitException` show every fallback. The log also contains the exact summary and answer, with no key and no identifiers.

**Proof that the AI, and not the fallback, wrote the text.** Do both runs and compare:
- Normal run: `source: gemini`, wording differs from the rule-based sentences ("Battery ranged from X% to Y%...").
- Negative test: set `GEMINI_API_KEYS` to `bad`, force-run again. The card must change to **Summary · no AI** with the rule-based text, and the log must show `error: ... key rejected (400/403)`. Restore the real keys afterwards and force-run again. This shows the fallback works and that the label tells the truth.
- Chain test: set the first model in `GEMINI_MODELS` to a name that does not exist (for example `not-a-model`). The log shows `config #1 ... skipped: GeminiModelUnavailableException`, and `configIndex` is 1 with the second model's name.

**Data needed.** The advisor needs readings in `readings/history` for the last 24 h (and energy totals from `onReading` for the energy lines). With less than 6 h of data it says so. You can generate data without hardware with `tools/simulate_device.js` (see `docs/testing-guide.md`).

## 5. Cost, privacy and limits

- One call per system per day, about 1,000-1,500 tokens: far below the free-tier limits for a single home (check the current limits in Google AI Studio).
- Only aggregated numbers (battery %, volts, amps, watts, Wh, alert titles) leave your Firebase project. No e-mail, system name, UID or password is sent. Do not add personal data to the summary.
- The keys live in Firebase Secret Manager, not in the app or the repository. Never put them in `lib/`.
- If the daily log shows `HTTP 404` for every config, run `tools/check_gemini.js`, pick the listed model names and redeploy with `GEMINI_MODELS=<names>`.
- The AI can still be wrong in wording. The card says "advisory only" and the advisor is not allowed to recommend bypassing safety devices, opening equipment or changing wiring.
