-- Preserve the legacy table for rollback and existing seed tooling.
CREATE TABLE context_recipes (
  pair_key TEXT NOT NULL,
  context_key TEXT NOT NULL,
  context_text TEXT NOT NULL,
  result_key TEXT NOT NULL,
  result_name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  source TEXT NOT NULL,
  prompt_version TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'active' CHECK(state IN ('active', 'disabled')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY(pair_key, context_key)
);

-- Historical names used '+' as a separator. New keys use JSON tuples.
INSERT INTO context_recipes
SELECT json_array(substr(pair_key, 1, instr(pair_key, '+') - 1), substr(pair_key, instr(pair_key, '+') + 1)),
       'v1:none', 'none', result_key, result_name, emoji, source, 'legacy', state, created_at
FROM recipes WHERE instr(pair_key, '+') > 0;
