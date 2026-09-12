# Overlap

Overlap is a playful SwiftUI element-combining game for iPhone, iPad, Mac, and Apple TV. Start with four familiar elements, discover recipes from the bundled map, and make new combinations as you play.

Most combinations are bundled with the app. When a pair is not in that map, the app can ask a small Cloudflare Worker for a family-friendly result. The Worker owns the OpenAI credential; the app never includes it.

## What is in this repository

- `Overlap/` — shared SwiftUI game code plus platform entry points and app resources.
- `Overlap.xcodeproj/` — generated Xcode project. Edit `project.yml`, then regenerate it with XcodeGen.
- `worker/` — the Cloudflare Worker used only for missing combinations.
- `combos.json` — the source combination map.
- `docs/` — supporting material.

## Run the macOS app

Prerequisites: Xcode with the macOS 26 SDK and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
./script/build_and_run.sh
```

The script builds the `Overlap-macOS` scheme into `build/local/` and opens the app. It also supports `--debug`, `--logs`, `--telemetry`, and `--verify`.

To work on another platform, open `Overlap.xcodeproj` in Xcode and select `Overlap-iOS` or `Overlap-tvOS`.

## Configure and deploy the Worker

Prerequisites: Node.js 20+ and a Cloudflare account with Workers access.

```bash
cd worker
npm ci
npx wrangler login
npx wrangler secret put OPENAI_API_KEY
npm run deploy
```

The Worker exposes:

- `GET /health`
- `POST /v1/combine` with JSON such as `{ "left": "Water", "right": "Fire" }`

Keep `OPENAI_API_KEY` solely in Cloudflare’s encrypted Worker secrets. Do not add it to an Xcode build setting, source file, `.env` committed to Git, or app bundle.

### Point the app at your Worker

The public repository intentionally has no configured fallback endpoint. To enable one locally, copy the example configuration, replace its value with your Worker URL, and regenerate the project:

```bash
cp Config/ServiceEndpoint.local.xcconfig.example Config/ServiceEndpoint.local.xcconfig
# Edit Config/ServiceEndpoint.local.xcconfig with your Worker URL.
xcodegen generate
```

`Config/ServiceEndpoint.local.xcconfig` is ignored by Git. Its `COMBO_FALLBACK_ENDPOINT` value becomes the app’s `ComboFallbackEndpoint` Info.plist value for every platform target. It must be an HTTPS URL ending in the Worker route. In an `.xcconfig` value, write an HTTPS URL as `https:/$()/your-worker.your-account.workers.dev/v1/combine` because `//` starts a comment. Without that local file—or with an empty or invalid value—the online fallback is disabled and bundled plus locally cached recipes continue to work.

## Privacy and network behavior

The app uses the bundled map first and caches generated results in the player’s local save. A network request is made only when a player combines a pair absent from both the bundled map and that local cache. That request contains only the two element names; no account or player data is sent.

## Development notes

`project.yml` is the source of truth for the Xcode project. After adding or moving Swift files, run:

```bash
xcodegen generate
```

Before deploying a public Worker, configure a Cloudflare rate-limit rule for `POST /v1/combine`. OpenAI project limits control spend, but rate limiting protects the public endpoint from unnecessary traffic.

## License

This project is licensed under the [MIT License](LICENSE).
