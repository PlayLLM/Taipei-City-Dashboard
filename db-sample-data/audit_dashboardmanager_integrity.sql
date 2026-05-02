-- dashboardmanager 一致性檢查。
--
-- 執行方式：
--   docker cp db-sample-data/audit_dashboardmanager_integrity.sql postgres-manager:/tmp/audit_dashboardmanager_integrity.sql
--   docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/audit_dashboardmanager_integrity.sql
--
-- 預期：
--   每個查詢區塊都應該回傳 0 rows。若有資料，代表 seed 或後續 SQL 流程仍有缺陷。

\echo '1. dashboards.components 引用不存在的 components.id'
WITH refs AS (
    SELECT d.id AS dashboard_id, d.index AS dashboard_index, u.component_id
    FROM public.dashboards d
    LEFT JOIN LATERAL unnest(COALESCE(d.components, '{}')) AS u(component_id) ON true
)
SELECT refs.dashboard_id, refs.dashboard_index, refs.component_id
FROM refs
LEFT JOIN public.components c ON c.id = refs.component_id
WHERE refs.component_id IS NOT NULL
  AND c.id IS NULL
ORDER BY refs.dashboard_id, refs.component_id;

\echo '2. 非個人 sidebar dashboard 的 component 缺少對應城市 query_charts'
WITH public_dashboards AS (
    SELECT
        d.id,
        d.index AS dashboard_index,
        d.name AS dashboard_name,
        g.name AS group_name,
        d.components
    FROM public.dashboards d
    JOIN public.dashboard_groups dg ON dg.dashboard_id = d.id
    JOIN public.groups g ON g.id = dg.group_id
    WHERE g.is_personal IS FALSE
),
refs AS (
    SELECT pd.*, u.component_id, u.ord
    FROM public_dashboards pd
    LEFT JOIN LATERAL unnest(COALESCE(pd.components, '{}')) WITH ORDINALITY AS u(component_id, ord) ON true
),
expected AS (
    SELECT
        *,
        CASE
            WHEN group_name IN ('taipei', 'metrotaipei') THEN group_name
            ELSE NULL
        END AS expected_city
    FROM refs
)
SELECT
    e.group_name,
    e.dashboard_index,
    e.dashboard_name,
    e.component_id,
    c.index AS component_index,
    c.name AS component_name,
    e.expected_city,
    array_agg(DISTINCT qc.city) FILTER (WHERE qc.city IS NOT NULL) AS available_query_cities
FROM expected e
LEFT JOIN public.components c ON c.id = e.component_id
LEFT JOIN public.query_charts qc ON qc.index = c.index
GROUP BY e.group_name, e.dashboard_index, e.dashboard_name, e.component_id, c.id, c.index, c.name, e.expected_city, e.ord
HAVING c.id IS NULL
   OR (e.expected_city IS NOT NULL AND NOT COALESCE(bool_or(qc.city = e.expected_city), false))
   OR (e.expected_city IS NULL AND e.component_id IS NOT NULL AND count(qc.city) = 0)
ORDER BY e.group_name, e.dashboard_index, e.ord;

\echo '3. query_charts 找不到 components'
SELECT qc.index, qc.city
FROM public.query_charts qc
LEFT JOIN public.components c ON c.index = qc.index
WHERE c.id IS NULL
ORDER BY qc.index, qc.city;

\echo '4. component_charts 找不到 components'
SELECT cc.index, cc.types
FROM public.component_charts cc
LEFT JOIN public.components c ON c.index = cc.index
WHERE c.id IS NULL
ORDER BY cc.index;

\echo '5. component_maps 未被任何 query_charts.map_config_ids 使用'
SELECT cm.id, cm.index, cm.title
FROM public.component_maps cm
WHERE NOT EXISTS (
    SELECT 1
    FROM public.query_charts qc
    WHERE cm.id = ANY(COALESCE(qc.map_config_ids, '{}'))
)
ORDER BY cm.id;

\echo '6. 非個人 sidebar dashboard 沒有任何 component'
SELECT g.name AS group_name, d.id, d.index, d.name
FROM public.dashboards d
JOIN public.dashboard_groups dg ON dg.dashboard_id = d.id
JOIN public.groups g ON g.id = dg.group_id
WHERE g.is_personal IS FALSE
  AND COALESCE(array_length(d.components, 1), 0) = 0
ORDER BY g.name, d.id;

\echo '7. 預設 roles 不應重複'
SELECT name, COUNT(*) AS count, array_agg(id ORDER BY id) AS role_ids
FROM public.roles
WHERE name IN ('admin', 'editor', 'viewer')
GROUP BY name
HAVING COUNT(*) > 1
ORDER BY name;
