-- 新增「自行車路網長度統計」組件到 dashboardmanager 資料庫。
--
-- 前置條件：
--   dashboard 資料庫已存在 public.bike_network_tpe。
--
-- 手動執行方式：
--   docker cp db-sample-data/add_bike_network_length_component.sql postgres-manager:/tmp/add_bike_network_length_component.sql
--   docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_bike_network_length_component.sql
--
-- 注意：
--   這份 SQL 會完整建立 transport-analysis dashboard、dashboard_groups、
--   component 與 query_charts，避免 sidebar 有「交通分析」但內容缺 query 而 500。

BEGIN;

INSERT INTO public.dashboards (id, index, name, components, icon, updated_at, created_at)
VALUES (
    400,
    'transport-analysis',
    '交通分析',
    '{}',
    'directions_bike',
    NOW(),
    NOW()
)
ON CONFLICT (index) DO UPDATE
SET name = EXCLUDED.name,
    icon = EXCLUDED.icon,
    updated_at = NOW();

INSERT INTO public.dashboard_groups (dashboard_id, group_id)
SELECT d.id, g.id
FROM public.dashboards d
JOIN public.groups g ON g.name = 'taipei' AND g.is_personal IS FALSE
WHERE d.index = 'transport-analysis'
ON CONFLICT DO NOTHING;

INSERT INTO public.components (id, index, name)
VALUES (302, 'bike_network_length', '自行車路網長度統計')
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    name = EXCLUDED.name;

INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'bike_network_length',
    ARRAY['#4CAF50', '#8BC34A', '#CDDC39', '#FFEB3B', '#FFC107', '#FF9800'],
    ARRAY['ColumnChart'],
    '公里'
)
ON CONFLICT (index) DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

DELETE FROM public.query_charts
WHERE index = 'bike_network_length'
  AND city = 'taipei';

INSERT INTO public.query_charts (
    index,
    history_config,
    map_config_ids,
    map_filter,
    time_from,
    time_to,
    update_freq,
    update_freq_unit,
    source,
    short_desc,
    long_desc,
    use_case,
    links,
    contributors,
    created_at,
    updated_at,
    query_type,
    query_chart,
    query_history,
    city
) VALUES (
    'bike_network_length',
    NULL,
    '{}',
    '{}',
    'static',
    NULL,
    0,
    NULL,
    '交通局',
    '顯示臺北市自行車路網依方向統計的總長度。',
    '此圖表呈現臺北市自行車路網依方向分類後的總長度，協助了解單向、雙向或未分類自行車路段的建置規模。',
    '適用於交通規劃、綠色運輸分析與自行車友善環境評估。',
    '{https://tdx.transportdata.tw/api/basic/v2/Cycling/Shape/City/Taipei?%24format=JSON}',
    '{doit}',
    NOW(),
    NOW(),
    'two_d',
    'SELECT COALESCE(NULLIF(direction, ''''), ''未知'') AS x_axis, ''總長度'' AS y_axis, ROUND((SUM(cycling_length) / 1000)::numeric, 2) AS data FROM public.bike_network_tpe WHERE city = ''台北市'' OR city = ''臺北市'' GROUP BY COALESCE(NULLIF(direction, ''''), ''未知'') ORDER BY data DESC',
    NULL,
    'taipei'
);

UPDATE public.dashboards
SET components = array_append(COALESCE(components, '{}'), 302),
    updated_at = NOW()
WHERE index = 'transport-analysis'
  AND NOT 302 = ANY(COALESCE(components, '{}'));

COMMIT;
