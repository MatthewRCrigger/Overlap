# The seed problem

**Status:** resolved — Option A applied to `combos.json` on 2026-08-23
**Date:** 2026-08-23
**Resolution:** 14 hand-authored bridges added; franchise trees and dead-end
residue pruned; `base: true` on exactly Water, Fire, Wind, Earth;
`discovered_from` regenerated breadth-first so every chain roots at the four.
Result: **3,746 elements / 4,879 combos**, all reachable from the four seeds.
Intermediate curation snapshots are not retained in this repository.

**Amendment (same day):** the Minecraft tree (53 elements) was grafted back in
via three canon-flavored bridges — `plant + explosion → Creeper`,
`diamond + pickaxe → Diamond Pickaxe`, `electricity + stone → Redstone` —
bringing the file to **3,799 elements / 4,944 combos**, still fully reachable
from the four seeds. The other 29 franchise trees remain cut.

The 14 bridges:

| Recipe                       | Produces    |     | Recipe                | Produces |
| ---------------------------- | ----------- | --- | --------------------- | -------- |
| `lava + obsidian`            | Metal       |     | `clay + plant`        | Human    |
| `metal + tornado`            | Electricity |     | `clay + metal`        | Tool     |
| `mud + rain`                 | Plant       |     | `human + smoke signal`| Story    |
| `erosion + planet`           | Time        |     | `human + rain`        | Emotion  |
| `plant + swamp`              | Animal      |     | `echo + emotion`      | Music    |
| `inferno + tornado`          | Magic       |     | `human + love`        | Family   |
| `animal + volcano`           | Dragon      |     | `planet + planet`     | Space    |


---

## The goal

Start the player with **Water, Fire, Wind, Earth** and nothing else, exactly as
Infinite Craft does, and still let them reach hundreds to thousands of elements.

## The finding

`combos.json` cannot currently do this. Starting from those four elements, the
player can reach **57 of 5,447 elements (1.0%)** using **66 of 7,105 combos
(0.9%)**. The remaining 99% is unreachable — not hidden, not hard, _impossible_.

The game would dead-end after roughly a dozen moves.

### The entire on-ramp

Ten combos take the four elements anywhere:

| Pair          | Result  |     | Pair          | Result  |
| ------------- | ------- | --- | ------------- | ------- |
| `earth+earth` | Planet  |     | `fire+wind`   | Smoke   |
| `earth+fire`  | Lava    |     | `water+water` | Ocean   |
| `earth+water` | Mud     |     | `water+wind`  | Wave    |
| `earth+wind`  | Dust    |     | `wind+wind`   | Tornado |
| `fire+fire`   | Inferno |     | `fire+water`  | Steam   |

### Everything reachable today (57 elements)

Ash, Beach, Bonfire, Canyon, Cataclysm, Clay, Coastline, Desert, Dirt, Drought,
Dust, Earth, Erosion, Eruption, Everglades, Fertile Soil, Fire, Firestorm, Fog,
Geyser, Golem, Great Flood, Heat Wave, Hill, Hot Spring, Inferno, Kiln,
Landslide, Lava, Mud, Mudslide, Obsidian, Obsidian Cliff, Ocean, Planet,
Pottery, Rain, Sand Kingdom, Sandcastle, Sandstorm, Smog, Smoke, Smoke Signal,
Steam, Steamboat, Steamship Fleet, Supervolcano, Swamp, Tornado, Tsunami,
Volcanic Ash, Volcano, Water, Wave, Wildfire, Wind, Yellowstone

It is a coherent little geology/weather game. It is not the game we specced.

---

## Why this happened

The generator did not grow one tree from four elements. It grew **55 separate
trees from 55 seeds**, then sampled combinations within each. `combos.json`
marks all 55 with `base: true`:

> Water, Fire, Wind, Earth, Plant, Animal, Human, Time, Space, Star, Metal,
> Tool, Electricity, Story, Music, Family, Magic, Dragon, Ghost, Emotion,
> Memory, Arcade, Pixel, High Score, Joystick, Light Cycle, The Grid, Punk Rock,
> Mohawk, Skateboard, Mixtape, Creeper, Diamond Pickaxe, Redstone, Animal
> Crossing, Tom Nook, Pokemon, Pikachu, Pokeball, Trainer, Comic Book,
> Vibranium, Web Slinger, Trading Card, Duel Monster, Mana, Planeswalker,
> Digivice, Anime, Manga, Pirate King, Devil Fruit, Ninja, Kaiju, Sensei

The 51 non-elemental seeds are **inputs only**. 46 of them are never produced by
any combo in the file. There is no recipe that makes Plant. None that makes
Metal, or Human, or Time.

`earth+plant → Forest` exists. Nothing → `Plant` does.

This is why flipping the `base` flags to four does not work, and is actively
dangerous: it produces precisely the 1% game above. The flags are a _symptom_.
The missing data is the cause.

### Note on `DATA-MODEL.md`

§1 states `base` is `true` for "exactly four: Water, Fire, Wind, Earth". The file
has 55. The doc describes the intended design; the data reflects what the
generator did. §2's load-time validation already anticipates this — check 5 is
"`base` count ≠ 4" and check 4 is "elements unreachable from the base four". Both
would fire loudly today.

### Why Infinite Craft doesn't have this problem

Infinite Craft calls an LLM at combine time, so _every_ pair resolves to
something and reachability is never a question. A static bundled dictionary has
to pre-contain its own connectivity. Matching Infinite Craft's feel with a
static file means the file has to be built for it — which is a solvable content
problem, not a design compromise.

---

## The fix: bridge recipes

A **bridge** is a new combo that produces an orphan seed from already-reachable
elements — for example `fire + stone → Metal`, or `mud + rain → Plant`. Each
bridge grafts an entire orphaned tree onto the main trunk.

The orphans split cleanly:

- **14 generic seeds** — Electricity, Story, Metal, Emotion, Time, Plant,
  Animal, Human, Tool, Magic, Music, Family, Dragon, Space. Natural elemental
  bridges exist for all of these.
- **32 franchise seeds** — Arcade, Pixel, High Score, Joystick, Light Cycle, The
  Grid, Punk Rock, Mohawk, Skateboard, Mixtape, Creeper, Diamond Pickaxe,
  Redstone, Tom Nook, Pokemon, Pikachu, Pokeball, Trainer, Comic Book,
  Vibranium, Web Slinger, Trading Card, Duel Monster, Mana, Planeswalker, Anime,
  Manga, Pirate King, Devil Fruit, Ninja, Kaiju, Sensei. Hard to motivate from
  four elements, and tonally odd beside an elemental crafting game.

### The unlock curve

Measured by greedy marginal gain — each bridge assumes the ones above it exist.
The curve **accelerates**: later bridges are worth more than earlier ones,
because each one enriches the pool the next can draw on.

| #   | Bridge to author | Cumulative elements |
| --- | ---------------- | ------------------- |
| 1   | Electricity      | 116                 |
| 2   | Story            | 209                 |
| 3   | Metal            | 268                 |
| 4   | Emotion          | 350                 |
| 5   | Time             | 455                 |
| 6   | Plant            | 578                 |
| 7   | Animal           | 811                 |
| 8   | Human            | 1,086               |
| 9   | Tool             | 1,395               |
| 10  | Magic            | 1,816               |
| 11  | Music            | 2,247               |
| 12  | Family           | 2,735               |
| 13  | Dragon           | 3,253               |
| 14  | Space            | **3,746**           |

### Cost/benefit

| Bridges authored     | Elements  | % of file | Usable combos |
| -------------------- | --------- | --------- | ------------- |
| 0 _(today)_          | 57        | 1.0%      | 66            |
| 4                    | 350       | 6.4%      | 407           |
| 6                    | 578       | 10.6%     | 672           |
| 8                    | 1,086     | 19.9%     | 1,260         |
| 10                   | 1,816     | 33.3%     | 2,191         |
| **14 (all generic)** | **3,746** | **68.8%** | **4,865**     |
| 46 (incl. franchise) | 4,608     | 84.6%     | —             |

**Fourteen new recipes convert a 1% game into a 69% game.** The 32 franchise
bridges add 862 more elements — a 23× worse return per recipe than the generic
14, for the tonally awkward content.

Note the ceiling: even bridging all 46 orphans reaches 4,608 of 5,447, not
5,447. The remaining ~840 elements are unreachable for other reasons — sampled
gaps where a required partner was never generated. That residue is what
`DATA-MODEL.md` §4's "Dead ends" filter and the Chains "Loose ends" card already
frame honestly.

---

## Options

### A — Bridge the 14 generic seeds _(recommended)_

Author ~14–20 recipes. Yields **3,746 elements / 4,865 combos** from Water,
Fire, Wind, Earth. Cut the 32 franchise seeds and their exclusive descendants.
Cheapest path to the stated goal, and it removes the Pokemon-next-to-Volcano
tonal problem for free.

### B — Bridge all 46

~46+ recipes for 4,608 elements. Keeps the franchise trees. Needs a story for
why four elements make Pikachu; 23× worse marginal return.

### C — Regenerate properly

Re-run the generator breadth-first from exactly four seeds, no seed injection.
Cleanest data and guaranteed connectivity by construction; most compute, and
discards the existing 7,105 combos. Correct choice if the dictionary is going to
be regenerated anyway for other reasons.

### D — Ship 55 starting elements

Zero data work; contradicts the goal and hands a new player 55 items including
Pikachu on first run. Recorded for completeness, not recommended.

---

## Recommendation

**Option A.** Author 14 generic bridges, drop the franchise trees, re-verify
closure, then build against the result.

Sequence:

1. Author the 14 bridges (one offline generation pass, or by hand — it is 14 recipes).
2. Re-run closure; confirm ≥3,700 elements reachable from the four.
3. Prune franchise seeds and any element reachable _only_ through them.
4. Set `base: true` on exactly Water, Fire, Wind, Earth. **This step is last** —
   it is safe only once the bridges exist.
5. Regenerate `discovered_from` for newly-bridged elements so depth and chains
   root correctly at the four.
6. Re-run `DATA-MODEL.md` §2 validation; expect checks 4 and 5 to come back clean.

Step 5 matters for more than data hygiene: `DATA-MODEL.md` §4 derives depth and
chains entirely from `discovered_from`. Until the orphans have parents, every
chain roots at the wrong place. (An earlier family-tint inheritance walk also
depended on this; families were later cut — see `DATA-MODEL.md` §3.)

## Open questions

1. Which option? (A recommended.)
2. If A: are the 32 franchise trees deleted, or kept in the file but flagged
   unreachable? Deleting shrinks the bundle and simplifies the counter; keeping
   them means `{collected} of {total}` shows a total the player can never reach.
3. Bridge recipes authored by hand or by one generation pass? 14 is small enough
   to hand-author with better taste than a model would apply.
