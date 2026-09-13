import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import worker, { pairKey, normalizeContext } from '../src/index.ts';

function database() {
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(readFileSync(new URL('../migrations/0001_create_recipes.sql', import.meta.url), 'utf8'));
  sqlite.prepare("INSERT INTO recipes(pair_key,result_key,result_name,emoji,source) VALUES ('fire+fire','volcano','Volcano','🌋','seed')").run();
  for (const file of ['0002_context_recipes.sql', '0003_operations.sql']) {
    sqlite.exec(readFileSync(new URL('../migrations/' + file, import.meta.url), 'utf8'));
  }
  return { sqlite, prepare(sql) {
    return { bind(...args) {
      return { async first() { return sqlite.prepare(sql).get(...args) ?? null; },
        async run() { return sqlite.prepare(sql).run(...args); } };
    } };
  } };
}
function env(db) { return { RECIPES_DB: db, DAILY_GENERATION_LIMIT: '2', OPENAI_API_KEY: 'test', COMBINE_LIMITER: { async limit() { return { success: true }; } } }; }
function request(context = 'none', left = 'Fire', right = 'Fire') {
  return new Request('https://example.test/v1/combine', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ left, right, context }) });
}

test('context normalization and collision-free unordered keys', () => {
  assert.equal(normalizeContext('  Minecraft '), 'Minecraft');
  assert.equal(normalizeContext(' NONE '), 'none');
  assert.equal(normalizeContext(''), 'none');
  assert.equal(normalizeContext('a'.repeat(257)), null);
  assert.equal(normalizeContext('a\nb'), null);
  assert.equal(pairKey('Water', 'Fire'), pairKey('Fire', 'Water'));
  assert.notEqual(pairKey('A+B', 'C'), pairKey('A', 'B+C'));
});

test('migration preserves none recipe; IP context generates and caches independently', async () => {
  const db = database();
  const config = env(db);
  assert.equal((await (await worker.fetch(request(), config)).json()).name, 'Volcano');
  const originalFetch = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async (_url, init) => {
    calls++;
    assert.equal(JSON.parse(JSON.parse(init.body).input).context, 'Minecraft');
    return Response.json({ output_text: JSON.stringify({ name: 'Nether', emoji: '🔥' }), usage: { input_tokens: 100, output_tokens: 10 } });
  };
  try {
    const first = await (await worker.fetch(request('Minecraft'), config)).json();
    const repeat = await (await worker.fetch(request(' minecraft '), config)).json();
    assert.equal(first.name, 'Nether');
    assert.deepEqual(first, repeat);
    assert.equal(calls, 1);
    assert.equal(first.contextKey, 'v1:minecraft');
    assert.equal(first.promptVersion, 'context-v1');
    assert.equal(db.sqlite.prepare('SELECT input_tokens FROM generation_usage').get().input_tokens, 100);
  } finally { globalThis.fetch = originalFetch; db.sqlite.close(); }
});

test('disabled and overridden recipes preserve the original row', async () => {
  const db = database();
  const key = pairKey('Fire', 'Fire');
  db.sqlite.prepare("INSERT INTO recipe_controls(pair_key,context_key,disabled,reason) VALUES (?, 'v1:none', 1, 'Review')").run(key);
  assert.equal((await worker.fetch(request(), env(db))).status, 422);
  db.sqlite.exec("UPDATE recipe_controls SET disabled=0,result_name='Sun',emoji='☀️'");
  assert.equal((await (await worker.fetch(request(), env(db))).json()).name, 'Sun');
  assert.equal(db.sqlite.prepare('SELECT result_name FROM context_recipes').get().result_name, 'Volcano');
});

test('failures do not cache results and the daily generation budget is enforced', async () => {
  const db = database();
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => { throw new Error('Network down'); };
  try {
    assert.equal((await worker.fetch(request('Dragons'), env(db))).status, 502);
    assert.equal((await worker.fetch(request('Dragons'), env(db))).status, 502);
    assert.equal((await worker.fetch(request('Dragons'), env(db))).status, 429);
    assert.equal(db.sqlite.prepare('SELECT count(*) AS n FROM context_recipes').get().n, 1);
    assert.equal((await worker.fetch(request(), env(db))).status, 200);
  } finally { globalThis.fetch = originalFetch; }
});

test('validation and rate limits return structured errors', async () => {
  const config = env(database());
  assert.equal((await worker.fetch(request('x'.repeat(257)), config)).status, 400);
  config.COMBINE_LIMITER.limit = async () => ({ success: false });
  const response = await worker.fetch(request(), config);
  assert.equal(response.status, 429);
  assert.equal(response.headers.get('retry-after'), '60');
});
