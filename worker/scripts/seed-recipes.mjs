import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const [inputPath = "../combos.json", outputPath = "/private/tmp/overlap-recipes-seed.sql"] = process.argv.slice(2);
const raw = JSON.parse(await readFile(resolve(process.cwd(), inputPath), "utf8"));
const entries = Object.entries(raw.combos ?? {});

const escape = (value) => String(value).replaceAll("'", "''");
const normalize = (value) => value.trim().normalize("NFC").toLowerCase();
const pairKey = (key) => JSON.stringify(key.split("+").map(normalize).sort());
const resultKey = (value) => normalize(value);

const statements = entries.map(([key, value]) => {
  if (!value || typeof value.result !== "string" || typeof value.emoji !== "string") {
    throw new Error(`Malformed recipe for ${key}`);
  }
  const result = value.result.trim();
  const emoji = value.emoji.trim();
  const canonicalElement = `INSERT INTO elements (result_key, name, emoji, source) VALUES ('${escape(resultKey(result))}', '${escape(result)}', '${escape(emoji)}', 'seed') ON CONFLICT(result_key) DO UPDATE SET name = excluded.name, emoji = excluded.emoji, source = excluded.source WHERE elements.source IN ('ai', 'legacy');`;
  const recipe = `INSERT OR IGNORE INTO context_recipes (pair_key, context_key, context_text, result_key, result_name, emoji, source, prompt_version) VALUES ('${escape(pairKey(key))}', 'v1:none', 'none', '${escape(resultKey(result))}', '${escape(result)}', '${escape(emoji)}', 'seed', 'seed-v1');`;
  return `${canonicalElement}\n${recipe}`;
});

await writeFile(resolve(process.cwd(), outputPath), `${statements.join("\n")}\n`);
console.log(`Wrote ${entries.length} seed recipes to ${resolve(process.cwd(), outputPath)}`);
