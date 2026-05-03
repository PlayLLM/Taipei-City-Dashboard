-- 修復 dashboardmanager seed 與後續 SQL 造成的 dashboard/component/query 不一致。
--
-- 使用情境：
--   刪除 PostgreSQL volume 後重新初始化，再依序套用新增組件 SQL 時，
--   若曾經只插入 components 或 dashboards，卻沒有補 query_charts，就會造成 sidebar
--   與實際內容不一致。這份 SQL 只處理 dashboardmanager 的關聯一致性。
--
-- 建議順序：
--   1. docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/dashboardmanager-demo.sql
--   2. docker exec postgres-data psql -U postgres -d dashboard -f /tmp/add_reusable_cup_data.sql
--   3. docker exec postgres-data psql -U postgres -d dashboard -f /tmp/add_recycling_station_data.sql
--   4. docker exec postgres-data psql -U postgres -d dashboard -f /tmp/add_eco_hotel_data.sql
--   5. docker exec postgres-data psql -U postgres -d dashboard -f /tmp/add_eco_restaurant_data.sql
--   6. docker exec postgres-data psql -U postgres -d dashboard -f /tmp/add_scooter_charging_data.sql
--   7. docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_bike_network_length_component.sql
--   8. docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_reusable_cup_component.sql
--   9. docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_recycling_station_component.sql
--  10. docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_eco_hotel_component.sql
--  11. docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_eco_restaurant_component.sql
--  12. docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_scooter_charging_component.sql
--  13. docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/repair_dashboardmanager_consistency.sql
--  14. docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/audit_dashboardmanager_integrity.sql
--
-- 注意：
--   greenhouse_gas_total_per_capita 目前 repo 沒有對應 dashboard 資料表與完整組件 SQL。
--   因此若它只有 components/dashboard reference，卻沒有 query_charts，這份修復會先移除，
--   避免重建後出現氣候環境 sidebar 對得到卡片但卡片沒有資料設定。

BEGIN;

-- 移除 demo seed 中不應出現在乾淨初始化資料內的測試個人 dashboard。
DELETE FROM public.dashboards
WHERE index = '3245d9eace5f'
  AND name = '我的新儀表板';

-- 清理重複執行 init-manager 造成的預設 roles 重複資料。
WITH canonical_roles AS (
    SELECT name, MIN(id) AS keep_id
    FROM public.roles
    WHERE name IN ('admin', 'editor', 'viewer')
    GROUP BY name
),
duplicate_roles AS (
    SELECT r.id AS duplicate_id, cr.keep_id
    FROM public.roles r
    JOIN canonical_roles cr ON cr.name = r.name
    WHERE r.id <> cr.keep_id
)
INSERT INTO public.auth_user_group_roles (auth_user_id, group_id, role_id)
SELECT DISTINCT agr.auth_user_id, agr.group_id, dr.keep_id
FROM public.auth_user_group_roles agr
JOIN duplicate_roles dr ON dr.duplicate_id = agr.role_id
ON CONFLICT DO NOTHING;

WITH canonical_roles AS (
    SELECT name, MIN(id) AS keep_id
    FROM public.roles
    WHERE name IN ('admin', 'editor', 'viewer')
    GROUP BY name
),
duplicate_roles AS (
    SELECT r.id AS duplicate_id
    FROM public.roles r
    JOIN canonical_roles cr ON cr.name = r.name
    WHERE r.id <> cr.keep_id
)
DELETE FROM public.auth_user_group_roles agr
USING duplicate_roles dr
WHERE agr.role_id = dr.duplicate_id;

WITH canonical_roles AS (
    SELECT name, MIN(id) AS keep_id
    FROM public.roles
    WHERE name IN ('admin', 'editor', 'viewer')
    GROUP BY name
),
duplicate_roles AS (
    SELECT r.id AS duplicate_id
    FROM public.roles r
    JOIN canonical_roles cr ON cr.name = r.name
    WHERE r.id <> cr.keep_id
)
DELETE FROM public.roles r
USING duplicate_roles dr
WHERE r.id = dr.duplicate_id;

-- 移除所有 dashboard 中不存在的 component id。
UPDATE public.dashboards d
SET components = cleaned.components,
    updated_at = NOW()
FROM (
    SELECT
        d.id,
        COALESCE(array_agg(component_id ORDER BY ord) FILTER (WHERE c.id IS NOT NULL), '{}')::integer[] AS components
    FROM public.dashboards d
    LEFT JOIN LATERAL unnest(COALESCE(d.components, '{}')) WITH ORDINALITY AS u(component_id, ord) ON true
    LEFT JOIN public.components c ON c.id = u.component_id
    GROUP BY d.id
) cleaned
WHERE d.id = cleaned.id
  AND COALESCE(d.components, '{}') IS DISTINCT FROM cleaned.components;

-- 若溫室氣體組件只有半套資料，先從 dashboard 與 components 移除。
UPDATE public.dashboards
SET components = array_remove(COALESCE(components, '{}'), 1),
    updated_at = NOW()
WHERE 1 = ANY(COALESCE(components, '{}'))
  AND NOT EXISTS (
      SELECT 1
      FROM public.query_charts
      WHERE index = 'greenhouse_gas_total_per_capita'
  );

DELETE FROM public.component_charts
WHERE index = 'greenhouse_gas_total_per_capita'
  AND NOT EXISTS (
      SELECT 1
      FROM public.query_charts
      WHERE index = 'greenhouse_gas_total_per_capita'
  );

DELETE FROM public.components
WHERE id = 1
  AND index = 'greenhouse_gas_total_per_capita'
  AND NOT EXISTS (
      SELECT 1
      FROM public.query_charts
      WHERE index = 'greenhouse_gas_total_per_capita'
  );

-- 移除沒有任何 component 的非個人 dashboard group 關聯，避免 sidebar 出現空 dashboard。
DELETE FROM public.dashboard_groups dg
USING public.dashboards d, public.groups g
WHERE dg.dashboard_id = d.id
  AND dg.group_id = g.id
  AND g.is_personal IS FALSE
  AND COALESCE(array_length(d.components, 1), 0) = 0
  AND d.index NOT IN ('09a25cd9cb7d');

-- 根據需求，移除「氣候環境」與「循環經濟」的區塊，只保留「淨零生活」
DELETE FROM public.dashboard_groups dg
USING public.dashboards d
WHERE dg.dashboard_id = d.id
  AND d.index IN ('climate-environment', 'circular-economy');

DELETE FROM public.dashboards
WHERE index IN ('climate-environment', 'circular-economy');

COMMIT;
