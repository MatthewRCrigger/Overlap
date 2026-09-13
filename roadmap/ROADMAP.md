# Overlap Roadmap

## Product direction

Overlap is a casual, single-player, infinite crafting game for iPhone, iPad, Mac, and Apple TV. Players combine items, receive an online-generated result, and retain a durable personal discovery history.

The game is intentionally open-ended. It has no completion percentage, undiscovered silhouettes, fixed end-state recipe map, favorites, search, share cards, or offline crafting.

Each player may create multiple runs. A run has an optional context that influences newly generated combinations. The explicit default context is **None**.

This roadmap intentionally specifies functionality, data, and service behavior only. Product naming, visual design, and interface flows will be defined separately.

## Non-negotiable rules

- Once a recipe is generated for a pair of inputs in a particular context, its result is permanent.
- A recipe identity is `input A + input B + context`, with input order normalized.
- `None` is stored explicitly, rather than treated as a missing value.
- A context is fixed when a run is created. Changing context means creating a new run.
- Every discovery retains its inputs, result, context, and time of discovery.
- New combinations require a connection. Previously discovered items and history remain readable from local storage.
- Context guides creativity; it cannot override output-format, safety, or family-friendly constraints.

## Phase 0 — Establish the durable game contract

**Goal:** Finalize the rules and schemas before expanding platform functionality.

- Define `Run`, `Recipe`, `Discovery`, and `Item` models.
- Decide normalization and versioning for context text.
- Define cache behavior, retries, and unavailable states.
- Permit both custom and named-property context text. Preserve the requested context as recipe metadata; any future presentation label is a separate concern.
- Add a `promptVersion` to generated recipes so later improvements never alter past discoveries.

**Exit criteria:** The app and service agree on a context-aware recipe contract.

## Phase 1 — Online core loop

**Goal:** Deliver a reliable online combination system with the `None` context.

- Resolve every unrecognized pair through the Worker and Luna, then persist the generated response.
- Define loading, timeout, unavailable, and retry states for callers.
- Save successful combinations locally with their inputs, result, timestamp, and source.
- Tune the Luna prompt for concise, familiar, original, family-safe nouns and emojis.
- Verify shared model and service behavior across all platform targets.

**Exit criteria:** A player can keep discovering meaningful new items online in a dependable `None` run.

## Phase 2 — Runs and context

**Goal:** Let players create separate runs with different generation contexts without ambiguity.

### App data work

- Add run creation, selection, and persistence.
- Support a run name and `None`, curated, or concise custom context text.
- Make the active context available to combination requests and discovery records.
- Keep each run’s collection and discovery history separate.

### Service and data work

- Extend `POST /v1/combine` with a `context` field.
- Normalize and validate context on the Worker; enforce a small maximum length.
- Change the D1 cache key from `pair_key` to a normalized, versioned `pair_key + context_key` identity.
- Save the exact normalized context, prompt version, and generated result as recipe metadata.
- Include context in Luna’s creative instructions.

**Exit criteria:** The same pair can intentionally produce distinct, stable results in different runs.

## Phase 3 — Discovery history and lineage

**Goal:** Persist and query personal discovery history as the game’s functional progression system.

- Store an append-only discovery event for every successful combine.
- Persist each event’s two inputs, result, emoji, context, and discovery time.
- Add queries for chronological run history, recent ingredients, an item’s first recipe, and recursive ancestry.
- Keep history and ancestry APIs independent of a specific interface or presentation.

**Exit criteria:** A player can revisit any run and inspect its past discoveries and their ancestry.

## Phase 4 — Private cross-device continuity

**Goal:** Let one player continue their runs across their Apple devices.

- Add private iCloud sync for runs, discoveries, collections, and contexts.
- Favor append-only discovery records to make conflicts and merging predictable.
- Keep previous discoveries visible from local data; only uncached crafting requires a connection.
- Test creation on one device, sync and lineage inspection on another, and concurrent-use conflict behavior.

**Exit criteria:** A player’s runs reliably appear on their signed-in iPhone, iPad, Mac, and Apple TV.

## Phase 5 — Generation quality and operations

**Goal:** Keep an infinite system fun, safe, affordable, and maintainable.

- Add Worker rate limiting and spend/latency monitoring.
- Track operational events: cache hit rate, generation success, latency, failure reason, and moderation rejection.
- Create a server-side override/disable path for unsafe, confusing, duplicate, or low-quality recipes.
- Maintain generation safety checks and original-content rules.
- Review prompt quality periodically without modifying any previously generated player recipe.

**Exit criteria:** The service can be safely operated as a public family game backend.

## Recommended implementation sequence

1. Replace current dead-end behavior with online generation availability states.
2. Define the new models and migrate recipe identity to include `None` context.
3. Implement runs and context across Swift, Worker, D1, and Luna.
4. Persist explicit append-only discovery history.
5. Add discovery-history and lineage storage/query capabilities.
6. Add private iCloud synchronization.
7. Add operational controls, generation review, and quality tooling.

## Current architecture impact

The current Worker cache is global and keyed only by a normalized input pair. It must be changed before contexts launch; otherwise a result created in one context could incorrectly be returned in every other context. The existing client already locally retains generated recipes and includes early ancestry support. Those pieces can be evolved into explicit run-scoped discovery history.
