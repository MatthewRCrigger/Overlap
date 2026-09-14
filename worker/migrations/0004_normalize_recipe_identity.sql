-- Migration 0002 copied legacy `Fire+Water` records into JSON arrays without
-- normalizing their item names. The Worker has always looked up canonical
-- lowercase keys, so those rows could be missed and regenerated. Canonicalize
-- the old rows while retaining an already-canonical row when both exist.
DELETE FROM context_recipes
WHERE EXISTS (
  SELECT 1
  FROM context_recipes AS canonical
  WHERE canonical.context_key = context_recipes.context_key
    AND canonical.pair_key = json_array(
      min(lower(json_extract(context_recipes.pair_key, '$[0]')), lower(json_extract(context_recipes.pair_key, '$[1]'))),
      max(lower(json_extract(context_recipes.pair_key, '$[0]')), lower(json_extract(context_recipes.pair_key, '$[1]')))
    )
    AND canonical.pair_key <> context_recipes.pair_key
);

UPDATE context_recipes
SET pair_key = json_array(
  min(lower(json_extract(pair_key, '$[0]')), lower(json_extract(pair_key, '$[1]'))),
  max(lower(json_extract(pair_key, '$[0]')), lower(json_extract(pair_key, '$[1]')))
)
WHERE pair_key <> json_array(
  min(lower(json_extract(pair_key, '$[0]')), lower(json_extract(pair_key, '$[1]'))),
  max(lower(json_extract(pair_key, '$[0]')), lower(json_extract(pair_key, '$[1]')))
);
