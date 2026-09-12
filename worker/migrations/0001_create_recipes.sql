CREATE TABLE IF NOT EXISTS recipes (
  pair_key TEXT PRIMARY KEY,
  result_key TEXT NOT NULL,
  result_name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  source TEXT NOT NULL CHECK (source IN ('seed', 'ai')),
  state TEXT NOT NULL DEFAULT 'active' CHECK (state IN ('active', 'disabled')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_recipes_active ON recipes(pair_key) WHERE state = 'active';
