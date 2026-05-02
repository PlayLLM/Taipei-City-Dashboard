-- 新增「資源回收站分布」組件到 dashboardmanager 資料庫。
--
-- 建議執行方式：
--   node scripts/apply_recycling_station_component_and_rebuild_qdrant.mjs
--
-- 本組件以 SQL 新增 components、component_charts、component_maps 與 query_charts。
-- 直接執行 SQL 後，必須重建 Qdrant，LLM／向量搜尋才會查到新的組件內容。
-- Qdrant point id 需以 component id、index、city 組成唯一鍵，避免同一組件的
-- taipei／metrotaipei 兩筆 query_charts 互相覆蓋；後端與 qdrant-upgrade 腳本已使用
-- 相同的 deterministic hash 規則處理。
--
-- 前置條件：
--   1. 已在 dashboard 資料庫執行 db-sample-data/add_recycling_station_data.sql
--   2. public.recycling_station_tpe 與 public.recycling_station_new_tpe 已存在
--
-- 手動執行方式：
--   docker cp db-sample-data/add_recycling_station_component.sql postgres-manager:/tmp/add_recycling_station_component.sql
--   docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_recycling_station_component.sql
--
-- 地圖資料：
--   本組件使用 scripts/generate_recycling_station_geojson.mjs 產生行政區級近似點位。
--   座標由行政區中心點加固定偏移產生，僅供分布視覺化，不代表實際門牌位置。
--   若未來完成地址 geocoding，可覆蓋同名 GeoJSON 以改用真實點位。

BEGIN;

INSERT INTO public.dashboards (id, index, name, components, icon, updated_at, created_at)
VALUES (
    401,
    'climate-environment',
    '氣候環境',
    '{}',
    'eco',
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
JOIN public.groups g ON g.name IN ('public', 'taipei') AND g.is_personal IS FALSE
WHERE d.index = 'climate-environment'
ON CONFLICT DO NOTHING;

INSERT INTO public.components (id, index, name)
VALUES (304, 'recycling_station_distribution', '資源回收站分布')
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    name = EXCLUDED.name;

INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'recycling_station_distribution',
    ARRAY['#9147D9'],
    ARRAY['ColumnChart'],
    '處'
)
ON CONFLICT (index) DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES
(
    102,
    'recycling_station_tpe',
    '臺北市資源回收站',
    'circle',
    'geojson',
    'big',
    NULL,
    '{"circle-color":"#9147D9","circle-opacity":0.85,"circle-stroke-color":"#F5E6FF","circle-stroke-width":1.2}'::json,
    '[{"key":"district","name":"行政區"},{"key":"address","name":"地址"},{"key":"coordinate_accuracy","name":"座標精度"}]'::json
),
(
    103,
    'recycling_station_metrotaipei',
    '雙北資源回收站',
    'circle',
    'geojson',
    'big',
    NULL,
    '{"circle-color":"#9147D9","circle-opacity":0.85,"circle-stroke-color":"#F5E6FF","circle-stroke-width":1.2}'::json,
    '[{"key":"city","name":"城市"},{"key":"district","name":"行政區"},{"key":"address","name":"地址"},{"key":"coordinate_accuracy","name":"座標精度"}]'::json
)
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    title = EXCLUDED.title,
    type = EXCLUDED.type,
    source = EXCLUDED.source,
    size = EXCLUDED.size,
    icon = EXCLUDED.icon,
    paint = EXCLUDED.paint,
    property = EXCLUDED.property;

DELETE FROM public.query_charts
WHERE index = 'recycling_station_distribution'
  AND city IN ('taipei', 'metrotaipei');

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
)
VALUES
(
    'recycling_station_distribution',
    NULL,
    '{102}',
    '{"mode":"byParam","byParam":{"xParam":"district"}}'::json,
    'static',
    NULL,
    0,
    NULL,
    '環境部環境管理署',
    '顯示臺北市各行政區資源回收站數量。',
    '此圖表彙整臺北市資源回收站資訊，以行政區統計各區站點數量，並以行政區級近似點位呈現分布情形。',
    '可用於檢視臺北市各行政區資源回收站布建情形，作為環境管理、公共服務配置與民眾查詢參考。地圖點位為行政區級近似座標，不代表實際門牌位置。',
    '{https://data.taipei/}',
    '{doit}',
    NOW(),
    NOW(),
    'three_d',
    'SELECT district AS x_axis, ''資源回收站'' AS y_axis, COUNT(*)::int AS data FROM public.recycling_station_tpe GROUP BY district ORDER BY data DESC, district',
    NULL,
    'taipei'
),
(
    'recycling_station_distribution',
    NULL,
    '{103}',
    '{"mode":"byParam","byParam":{"xParam":"district"}}'::json,
    'static',
    NULL,
    0,
    NULL,
    '環境部環境管理署',
    '顯示雙北各行政區資源回收站數量。',
    '此圖表彙整臺北市與新北市資源回收站資訊，以行政區統計各區站點數量，並以行政區級近似點位呈現雙北回收服務分布情形。',
    '可用於比較雙北各行政區資源回收站布建情形，作為環境管理、公共服務配置與民眾查詢參考。地圖點位為行政區級近似座標，不代表實際門牌位置。',
    '{https://data.taipei/,https://data.ntpc.gov.tw/}',
    '{doit,ntpc}',
    NOW(),
    NOW(),
    'three_d',
    'SELECT district AS x_axis, ''資源回收站'' AS y_axis, COUNT(*)::int AS data FROM (SELECT district FROM public.recycling_station_tpe UNION ALL SELECT district FROM public.recycling_station_new_tpe) d GROUP BY district ORDER BY data DESC, district',
    NULL,
    'metrotaipei'
);

UPDATE public.dashboards
SET components = array_append(components, 304),
    updated_at = NOW()
WHERE index = 'climate-environment'
  AND NOT 304 = ANY(components);

COMMIT;
