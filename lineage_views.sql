-- ============================================================
-- Lineage semantic layer for Genie
-- Schema: nextgenbi_sandbox.lineage  (adjust as needed)
-- Requires: system.access enabled, SELECT granted
-- Recursive CTE requires DBR 17+ / current DBSQL channel
-- ============================================================

USE CATALOG nextgenbi_sandbox;
CREATE SCHEMA IF NOT EXISTS lineage;
USE SCHEMA lineage;

-- ------------------------------------------------------------
-- 1. Unified edge view: UC-captured lineage + Fabric shortcut edges
--    (fabric_edges is the table your sync notebook writes)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_table_edges AS
SELECT
  source_table_full_name,
  target_table_full_name,
  entity_type,                          -- NOTEBOOK / JOB / PIPELINE / DBSQL ...
  entity_id,
  MAX(event_time) AS last_seen
FROM system.access.table_lineage
WHERE source_table_full_name IS NOT NULL
  AND target_table_full_name IS NOT NULL
  AND source_table_full_name <> target_table_full_name   -- drop MERGE self-loops
GROUP BY 1, 2, 3, 4

UNION ALL

SELECT
  source_table_full_name,
  target_table_full_name,               -- 'fabric://{workspace}/{lakehouse}/{shortcut}'
  'FABRIC_SHORTCUT' AS entity_type,
  shortcut_id       AS entity_id,
  last_seen
FROM lineage.fabric_edges;

-- ------------------------------------------------------------
-- 2. Deduped edge list for traversal (entity noise collapsed)
--    One row per distinct source->target pair.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_edges_distinct AS
SELECT
  source_table_full_name AS src,
  target_table_full_name AS tgt,
  MAX(last_seen)          AS last_seen,
  array_agg(DISTINCT entity_type) AS via_entity_types
FROM v_table_edges
GROUP BY 1, 2;

-- ------------------------------------------------------------
-- 3. Recursive DOWNSTREAM flattening
--    (table, related_table, depth, path) for every reachable node.
--    Cycle guard: array_contains on accumulated path.
--    Depth cap: 10 (raise if your DAG is deeper; it isn't).
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_downstream AS
WITH RECURSIVE walk (root, node, depth, path) AS (
  -- anchor: every direct edge
  SELECT
    src                    AS root,
    tgt                    AS node,
    1                      AS depth,
    array(src, tgt)        AS path
  FROM v_edges_distinct

  UNION ALL

  -- step: extend the walk
  SELECT
    w.root,
    e.tgt                  AS node,
    w.depth + 1            AS depth,
    array_append(w.path, e.tgt) AS path
  FROM walk w
  JOIN v_edges_distinct e
    ON e.src = w.node
  WHERE w.depth < 10
    AND NOT array_contains(w.path, e.tgt)   -- cycle guard
)
SELECT
  root            AS table_name,
  node            AS downstream_table,
  MIN(depth)      AS min_depth,             -- shortest dependency distance
  any_value(path) AS sample_path
FROM walk
GROUP BY root, node;

-- ------------------------------------------------------------
-- 4. Recursive UPSTREAM flattening (same walk, reversed edges)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_upstream AS
WITH RECURSIVE walk (root, node, depth, path) AS (
  SELECT
    tgt                    AS root,
    src                    AS node,
    1                      AS depth,
    array(tgt, src)        AS path
  FROM v_edges_distinct

  UNION ALL

  SELECT
    w.root,
    e.src                  AS node,
    w.depth + 1            AS depth,
    array_append(w.path, e.src) AS path
  FROM walk w
  JOIN v_edges_distinct e
    ON e.tgt = w.node
  WHERE w.depth < 10
    AND NOT array_contains(w.path, e.src)
)
SELECT
  root            AS table_name,
  node            AS upstream_table,
  MIN(depth)      AS min_depth,
  any_value(path) AS sample_path
FROM walk
GROUP BY root, node;

-- ------------------------------------------------------------
-- 5. Convenience: single direction-tagged view for Genie
--    "impact analysis" -> direction='downstream'
--    "root cause"      -> direction='upstream'
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_lineage_flat AS
SELECT table_name, downstream_table AS related_table,
       'downstream' AS direction, min_depth, sample_path
FROM v_downstream
UNION ALL
SELECT table_name, upstream_table AS related_table,
       'upstream'   AS direction, min_depth, sample_path
FROM v_upstream;

-- ------------------------------------------------------------
-- Smoke tests
-- ------------------------------------------------------------
-- Full blast radius incl. Fabric endpoints:
-- SELECT related_table, min_depth
-- FROM v_lineage_flat
-- WHERE direction = 'downstream'
--   AND table_name = 'nextgenbi_bronze_prod.servicenow.incident'
-- ORDER BY min_depth;

-- Which Silver/Gold tables are exposed to Fabric:
-- SELECT DISTINCT source_table_full_name, target_table_full_name
-- FROM v_table_edges WHERE entity_type = 'FABRIC_SHORTCUT';
