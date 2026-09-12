import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const [inputPath = "../combos.json", outputPath = "/private/tmp/overlap-recipes-seed.sql"] = process.argv.slice(2);
const raw = JSON.parse(await readFile(resolve(process.cwd(), inputPath), "utf8"));
const entries = Object.entries(raw.combos ?? {});

const escape = (value) => String(value).replaceAll("'", "''");
const normalize = (value) => value.trim().normalize("NFC").toLowerCase();
const pairKey = (key) => key.split("+").map(normalize).sort().join("+");
const resultKey = (value) => normalize(value);

const statements = entries.map(([key, value]) => {
  if (!value || typeof value.result !== "string" || typeof value.emoji !== "string") {
    throw new Error(`Malformed recipe for ${key}`);
  }
  return `INSERT OR IGNORE INTO recipes (pair_key, result_key, result_name, emoji, source) VALUES ('${escape(pairKey(key))}', '${escape(resultKey(value.result))}', '${escape(value.result.trim())}', '${escape(value.emoji.trim())}', 'seed');`;
});

await writeFile(resolve(process.cwd(), outputPath), `${statements.join("\n")}\n`);
console.log(`Wrote ${entries.length} seed recipes to ${resolve(process.cwd(), outputPath)}`);
