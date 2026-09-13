# Implementation and validation

## App behavior

- `CraftRun`, `CraftContext`, `CraftRecipe`, `CraftItem`, and `Discovery` define the shared data contract.
- Context is NFC-normalized and trimmed, limited to 256 UTF-16 code units, and cannot contain control characters. Empty or case-insensitive `none` maps to the explicit `none` value. Context identity is `v1:` plus the lowercased value; franchise names remain intact in the stored text and model input.
- Unordered recipe keys use JSON arrays, avoiding collisions between names containing `+`. Identical inputs remain two ingredients.
- Run context is immutable. New runs begin with the four base ingredients; switching runs preserves each collection, recipes, history, and board.
- `runs.json` uses ordered atomic writes. `progress.json` is read for migration and left intact. Imported discoveries have unknown timestamps because the old save did not contain them; imported recipe ordering is not claimed to be historical.
- Every successful combine appends a discovery UUID, even for an already-owned result. Undo restores board placement but never erases learned recipes or history.
- Network failures preserve ingredients for retry, leave the pair unconsumed, and never become cached recipes. Typed errors distinguish offline, timeout, rate limit, service failure, and invalid responses.
- A plain shared panel exposes run creation, selection, discovery history, and sync. Existing ancestry views use explicit discovery records. Apple TV exposes all collected ingredients.
- Game state is shared between app windows to avoid competing saves.

## Private iCloud sync

The signed app uses `iCloud.com.crggr.overlap`, private database zone `OverlapRuns`, and `OverlapRunSnapshot` records. One asset-backed snapshot per device/run prevents devices from replacing each other's records. Discovery UUIDs are merged by union and sorted by time, with stable UUID ordering for ties. Board position and active-run selection remain local.

Sync occurs on activation, after discovery/run changes, and on manual request. Record-zone changes are paginated and require no custom query index. Local progress survives sync errors. Switching iCloud accounts stops uploads to avoid unintentionally copying the old account's runs to the new account.

The first implementation uploads run snapshots and reads the whole zone per sync. This is intentionally simple for family use; large histories may eventually warrant incremental record/token syncing.

The Mac was registered with the configured Apple development team, its CloudKit provisioning profile was generated, and the signed app successfully reported `Synced`. Physical cross-device testing remains outstanding. Development and distribution builds must use the same intended CloudKit environment; distribute the development schema before testing a production environment.

## Service behavior

- Migration `0002_context_recipes.sql` adds the cache keyed by pair and context and imports existing recipes under `v1:none`. The legacy table remains available for rollback.
- Migration `0003_operations.sql` adds recipe controls and daily generation usage.
- Old requests without context still resolve under `none`. Old service responses without context metadata are accepted only in `none` runs.
- Luna receives the actual franchise context and may return franchise names. Structured output and family-friendly instructions apply to every context.
- `INSERT OR IGNORE` plus rereading the winning row makes concurrent generations return the same saved result. Prompt-version changes do not change recipe identity or overwrite stored discoveries.
- Default limits are 60 requests per minute per IP and 500 generation attempts per UTC day. The IP limit is regional and approximate; the D1 daily reservation is atomic and global. Failed generation attempts still consume the daily budget. Cached recipes remain available when the generation budget is exhausted.
- `DAILY_GENERATION_LIMIT=0` pauses generation. Adjust the configured value for family usage.
- Logs expose request status/latency, cache hits, generation failures, refusals, and rate limits. Daily D1 totals store attempts, successes, and reported input/output tokens. These are usage measurements, not an exact dollar billing ledger.
- `recipe_controls` can disable a recipe or supply a separate override. The original recipe stays intact; existing local discoveries are never silently rewritten.
- The controls helper emits SQL for review: `node scripts/recipe-control.mjs disable Fire Fire Minecraft` or `node scripts/recipe-control.mjs override Fire Fire Minecraft Nether '🔥' 'Reviewed result'`. Apply reviewed SQL through authenticated Wrangler. `clear` removes the control and reveals the original recipe again.

## Validation commands

```sh
xcodegen generate
./script/build_and_run.sh --verify
xcodebuild -quiet -project Overlap.xcodeproj -scheme OverlapTests -destination 'platform=macOS' -derivedDataPath build/tests CODE_SIGNING_ALLOWED=NO OVERLAP_CLOUD_SYNC_ENABLED=NO test
xcodebuild -quiet -project Overlap.xcodeproj -scheme Overlap-iOS -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios CODE_SIGNING_ALLOWED=NO OVERLAP_CLOUD_SYNC_ENABLED=NO build
xcodebuild -quiet -project Overlap.xcodeproj -scheme Overlap-tvOS -destination 'generic/platform=tvOS Simulator' -derivedDataPath build/tvos CODE_SIGNING_ALLOWED=NO OVERLAP_CLOUD_SYNC_ENABLED=NO build
```

From `worker/` with Node 24 or later:

```sh
npm ci
npm run types
npm run check
npm test
npm run deploy:dry-run
npx wrangler d1 migrations apply overlap-recipes --local
```

App tests cover migration, run isolation/reloading, repeated history, undo, cancellation during a run switch, self-pair ancestry, context validation, typed network errors, and concurrent merge idempotence. Service tests execute the real SQL migrations in SQLite and cover context cache isolation, recipe controls, budgets, validation, and transient generation failures. Local Wrangler migration checks additionally exercise D1. Model calls are mocked in service tests, so they do not validate live Luna content quality.

## Activation pending approval

Automatic approval review blocked changing the shared service because the request authorized implementation and builds. No remote migration or deployment was performed. The existing database was read-only inspected and held 5,157 recipes.

After deployment approval, from `worker/`:

```sh
npx wrangler d1 migrations apply overlap-recipes --remote
npm run deploy
```

Then verify `Fire + Fire` under `none`, `Minecraft`, and `How To Train Your Dragon`, repeat each request to verify stability, and inspect generation/cache metrics. Run the same saved run on signed physical devices to complete the cross-device acceptance check.

For ongoing quality review, inspect a small sample of newly generated recipes after prompt changes, record the prompt version and context, and use recipe controls for corrections. This is a manual operational task, not a scheduled automation.
