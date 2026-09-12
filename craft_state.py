#!/usr/bin/env python3
"""State manager for building combos.json without API calls.

Usage:
  python3 craft_state.py init
  python3 craft_state.py inject "Plant" "🌱" "Animal" "🐾" ...   # name/emoji pairs
  python3 craft_state.py sample N OUTFILE      # sample N undone pairs -> JSON list
  python3 craft_state.py ingest RESULTS...     # results files: [{"a":..,"b":..,"result":..,"emoji":..}]
  python3 craft_state.py stats
"""
import json, random, sys, re
from pathlib import Path

HERE = Path(__file__).parent
COMBOS = HERE / "combos.json"

SEEDS = {"Water": "💧", "Fire": "🔥", "Wind": "🌬️", "Earth": "🌍"}
FALLBACK_EMOJI = "✨"

def norm(name: str) -> str:
    return name.strip().lower()

def key(a: str, b: str) -> str:
    return "+".join(sorted([norm(a), norm(b)]))

def load():
    if COMBOS.exists():
        return json.loads(COMBOS.read_text())
    return {"combos": {}, "elements": {}}

def save(data):
    tmp = COMBOS.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=1, ensure_ascii=False))
    tmp.replace(COMBOS)

def canonical(data, name):
    """Return canonical display name if element exists (case-insensitive)."""
    n = norm(name)
    for el in data["elements"]:
        if norm(el) == n:
            return el
    return None

def cmd_init():
    data = load()
    for name, emoji in SEEDS.items():
        data["elements"].setdefault(name, {"emoji": emoji, "base": True})
    save(data)
    print("initialized with seeds:", list(SEEDS))

def cmd_inject(args):
    data = load()
    for i in range(0, len(args), 2):
        name, emoji = args[i], args[i + 1]
        if not canonical(data, name):
            data["elements"][name] = {"emoji": emoji, "base": True}
    save(data)
    print("elements now:", len(data["elements"]))

def cmd_sample(n, outfile, focus_file=None):
    if focus_file:
        return cmd_sample_focus(n, outfile, focus_file)
    data = load()
    els = list(data["elements"].keys())
    done = set(data["combos"].keys())
    # usage counts for weighting: fewer appearances -> higher weight
    uses = {norm(e): 0 for e in els}
    for k in done:
        for part in k.split("+"):
            if part in uses:
                uses[part] += 1
    weights = [1.0 / (1 + uses[norm(e)]) for e in els]
    picked, seen = [], set()
    attempts = 0
    while len(picked) < n and attempts < n * 60:
        attempts += 1
        a, b = random.choices(els, weights=weights, k=2)
        if norm(a) == norm(b):
            continue
        k2 = key(a, b)
        if k2 in done or k2 in seen:
            continue
        seen.add(k2)
        picked.append({"a": a, "b": b})
    Path(outfile).write_text(json.dumps(picked, indent=0, ensure_ascii=False))
    print(f"sampled {len(picked)} pairs -> {outfile}")

def cmd_sample_focus(n, outfile, focus_file):
    """Sample pairs where side 'a' always comes from the focus list."""
    data = load()
    focus = [canonical(data, e) or e for e in json.loads(Path(focus_file).read_text())]
    els = list(data["elements"].keys())
    done = set(data["combos"].keys())
    picked, seen = [], set()
    attempts = 0
    while len(picked) < n and attempts < n * 60:
        attempts += 1
        a = random.choice(focus)
        b = random.choice(focus if random.random() < 0.3 else els)
        if norm(a) == norm(b):
            continue
        k2 = key(a, b)
        if k2 in done or k2 in seen:
            continue
        seen.add(k2)
        picked.append({"a": a, "b": b})
    Path(outfile).write_text(json.dumps(picked, indent=0, ensure_ascii=False))
    print(f"sampled {len(picked)} focus pairs -> {outfile}")

def cmd_selfsample(n, outfile):
    """Emit self-pairs (X+X) for the base seeds plus the most-used elements."""
    data = load()
    done = set(data["combos"].keys())
    uses = {}
    for k in done:
        for part in k.split("+"):
            uses[part] = uses.get(part, 0) + 1
    els = sorted(data["elements"], key=lambda e: (not data["elements"][e].get("base"),
                                                  -uses.get(norm(e), 0)))
    picked = [{"a": e, "b": e} for e in els if key(e, e) not in done][:n]
    Path(outfile).write_text(json.dumps(picked, indent=0, ensure_ascii=False))
    print(f"sampled {len(picked)} self-pairs -> {outfile}")

def cmd_ingest(files):
    data = load()
    added_combos = added_els = skipped = 0
    for f in files:
        try:
            rows = json.loads(Path(f).read_text())
        except Exception as e:
            print(f"SKIP {f}: {e}")
            continue
        for r in rows:
            try:
                a, b = r["a"], r["b"]
                result = re.sub(r"\s+", " ", str(r["result"]).strip())
                emoji = str(r.get("emoji") or FALLBACK_EMOJI).strip() or FALLBACK_EMOJI
            except Exception:
                skipped += 1
                continue
            if not result or len(result.split()) > 4 or norm(result) in (norm(a), norm(b)):
                skipped += 1
                continue
            k2 = key(a, b)
            if k2 in data["combos"]:
                skipped += 1
                continue
            canon = canonical(data, result)
            if canon:
                result = canon
                emoji = data["elements"][canon]["emoji"]
            else:
                data["elements"][result] = {
                    "emoji": emoji, "base": False, "discovered_from": [a, b]}
                added_els += 1
            data["combos"][k2] = {"result": result, "emoji": emoji}
            added_combos += 1
    save(data)
    print(f"ingested: +{added_combos} combos, +{added_els} elements, {skipped} skipped. "
          f"totals: {len(data['combos'])} combos, {len(data['elements'])} elements")

def cmd_stats():
    data = load()
    print(f"{len(data['combos'])} combos, {len(data['elements'])} elements")

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "init":
        cmd_init()
    elif cmd == "inject":
        cmd_inject(sys.argv[2:])
    elif cmd == "sample":
        cmd_sample(int(sys.argv[2]), sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
    elif cmd == "selfsample":
        cmd_selfsample(int(sys.argv[2]), sys.argv[3])
    elif cmd == "ingest":
        cmd_ingest(sys.argv[2:])
    elif cmd == "stats":
        cmd_stats()
