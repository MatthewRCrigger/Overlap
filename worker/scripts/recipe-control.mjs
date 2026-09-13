// Generates reviewable SQL; applying it requires authenticated Wrangler access.
import { pairKey, normalizeContext } from '../src/index.ts';
const [action, left, right, rawContext, result, emoji, reason = 'Manual review'] = process.argv.slice(2);
const context = normalizeContext(rawContext);
if (!['disable', 'override', 'clear'].includes(action) || !left || !right || context === null ||
    (action === 'override' && (!result || !emoji))) {
  throw new Error('Usage: node scripts/recipe-control.mjs disable|override|clear LEFT RIGHT CONTEXT [RESULT EMOJI REASON]');
}
const sql = value => "'" + value.replaceAll("'", "''") + "'";
const key = sql(pairKey(left.trim(), right.trim()));
const ctx = sql('v1:' + context.toLowerCase());
if (action === 'clear') {
  console.log(`DELETE FROM recipe_controls WHERE pair_key = ${key} AND context_key = ${ctx};`);
} else {
  console.log(`INSERT INTO recipe_controls(pair_key, context_key, disabled, result_name, emoji, reason)
VALUES (${key}, ${ctx}, ${action === 'disable' ? 1 : 0}, ${result ? sql(result) : 'NULL'}, ${emoji ? sql(emoji) : 'NULL'}, ${sql(reason)})
ON CONFLICT(pair_key, context_key) DO UPDATE SET disabled = excluded.disabled, result_name = excluded.result_name,
emoji = excluded.emoji, reason = excluded.reason, updated_at = CURRENT_TIMESTAMP;`);
}
