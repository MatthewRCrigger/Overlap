# Overlap

Overlap is a playful SwiftUI element-combining game for iPhone, iPad, Mac, and Apple TV. Start with four familiar elements, discover recipes from a shared online cache, and make new combinations as you play.

The app sends a pair to a small Cloudflare Worker. The Worker reads the shared D1 recipe cache first; on a miss it asks OpenAI for a family-friendly result, stores it in D1, and returns it. The Worker owns the OpenAI credential; the app never includes it.

## What is in this repository

- `Overlap/` — shared SwiftUI game code plus platform entry points and app resources.
- `Overlap.xcodeproj/` — generated Xcode project. Edit `project.yml`, then regenerate it with XcodeGen.
- `worker/` — the Cloudflare Worker, D1 migration, and seed script.
- `combos.json` — the original recipe data; the app does not bundle this file.
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
npx wrangler d1 create overlap-recipes
npx wrangler secret put OPENAI_API_KEY
npx wrangler d1 migrations apply overlap-recipes --remote
npm run deploy
```

After creating a D1 database, replace `database_id` in `worker/wrangler.jsonc` with the ID Wrangler prints. To preload this repository's original recipes into D1, run `npm run seed:sql`, then execute the generated `/private/tmp/overlap-recipes-seed.sql` with `wrangler d1 execute <your-database-name> --remote --file=...`. New recipes are then added automatically on global cache misses.

The Worker exposes:

- `GET /health`
- `POST /v1/combine` with JSON such as `{ "left": "Water", "right": "Fire", "context": "Minecraft" }`; omitted context means `none`.

Keep `OPENAI_API_KEY` solely in Cloudflare’s encrypted Worker secrets. Do not add it to an Xcode build setting, source file, `.env` committed to Git, or app bundle.

### Point the app at your Worker

The public repository intentionally has no configured fallback endpoint. To enable one locally, copy the example configuration, replace its value with your Worker URL, and regenerate the project:

```bash
cp Config/ServiceEndpoint.local.xcconfig.example Config/ServiceEndpoint.local.xcconfig
# Edit Config/ServiceEndpoint.local.xcconfig with your Worker URL.
xcodegen generate
```

`Config/ServiceEndpoint.local.xcconfig` is ignored by Git. Its `COMBO_FALLBACK_ENDPOINT` value becomes the app’s `ComboFallbackEndpoint` Info.plist value for every platform target. It must be an HTTPS URL ending in the Worker route. In an `.xcconfig` value, write an HTTPS URL as `https:/$()/your-worker.your-account.workers.dev/v1/combine` because `//` starts a comment. Without that local file—or with an empty or invalid value—the app cannot resolve new combinations.

## Privacy and network behavior

The app retains discovered recipes and history locally and syncs runs through the player's private iCloud database. Combination requests contain the two element names and context; no iCloud account data or personal discovery history is sent to the Worker. The Worker checks D1 first, so an OpenAI request is made only for an unseen pair and context.

## Development notes

The current functional roadmap and build/sync/deployment instructions are in [roadmap/ROADMAP.md](roadmap/ROADMAP.md) and [roadmap/IMPLEMENTATION.md](roadmap/IMPLEMENTATION.md). New runs support explicit contexts, including franchise names, and retain discovery history. The Mac build script now signs the app for private CloudKit sync; unsigned test builds must pass `OVERLAP_CLOUD_SYNC_ENABLED=NO`.

`project.yml` is the source of truth for the Xcode project. After adding or moving Swift files, run:

```bash
xcodegen generate
```

Before deploying a public Worker, configure a Cloudflare rate-limit rule for `POST /v1/combine`. OpenAI project limits control spend, but rate limiting protects the public endpoint from unnecessary traffic.

## License

This project is licensed under the [MIT License](LICENSE).
