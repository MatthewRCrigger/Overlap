-- Recipes describe how an item is made; elements own the stable display
-- identity for that item. This prevents e.g. Steam from changing emoji based
-- on the recipe used to discover it.
CREATE TABLE elements (
  result_key TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  source TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Seeded data is reviewed and therefore wins over legacy or AI-generated
-- records. Within the same source, retain the oldest observed identity.
INSERT OR IGNORE INTO elements (result_key, name, emoji, source, created_at)
SELECT result_key, result_name, emoji, source, created_at
FROM context_recipes
ORDER BY CASE source WHEN 'seed' THEN 0 WHEN 'ai' THEN 1 ELSE 2 END, created_at ASC;
