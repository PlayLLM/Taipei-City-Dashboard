-- ============================================================
-- 循環杯門市組件配置
-- 資料庫: dashboardmanager
-- ============================================================
--
-- 前置條件：
--   1. 已執行 db-sample-data/install_reusable_cup.sh 匯入點位及統計資料
--      ※ 無需執行 data/etl_reusable_cup_stores.py 或 Mapbox API
--   1. 已在 dashboard 資料庫執行 db-sample-data/add_reusable_cup_data.sql
--      產生 public.reusable_cup_stats。
--   2. 已將 GeoJSON 放置至前端目錄：
--      Taipei-City-Dashboard-FE/public/mapData/reusable_cup_store_metrotaipei.geojson
--
-- 執行方式：
--   強烈建議使用統一安裝腳本：
--   bash db-sample-data/install_reusable_cup.sh
-- 手動執行方式：
--   docker cp db-sample-data/add_reusable_cup_component.sql postgres-manager:/tmp/add_reusable_cup_component.sql
--   docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_reusable_cup_component.sql
--
-- 注意：
--   這份 SQL 必須完整建立 components、component_charts、component_maps、
--   query_charts、dashboards 與 dashboard_groups，避免重建 volume 後只有 sidebar
--   或只有 map_config 的半套資料。
--
-- ============================================================

BEGIN;

INSERT INTO public.dashboards (id, index, name, components, icon, updated_at, created_at)
VALUES (
    402,
    'circular-economy',
    '循環經濟',
    '{}',
    'recycling',
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
JOIN public.groups g ON g.name = 'metrotaipei' AND g.is_personal IS FALSE
WHERE d.index = 'circular-economy'
ON CONFLICT DO NOTHING;

INSERT INTO public.components (id, index, name)
VALUES (301, 'metrotaipei_reusable_cup', '雙北各區循環杯門市數量')
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    name = EXCLUDED.name;

INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'metrotaipei_reusable_cup',
    ARRAY['#4CAF50', '#2196F3'],
    ARRAY['DistrictChart', 'BarChart'],
    '間'
)
ON CONFLICT (index) DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES (
    2,
    'reusable_cup_store_metrotaipei',
    '雙北循環杯門市',
    'circle',
    'geojson',
    'big',
    NULL,
    '{"circle-color":"#4CAF50","circle-radius":["interpolate",["linear"],["zoom"],10,4,16,10],"circle-opacity":0.85,"circle-stroke-color":"#ffffff","circle-stroke-width":1}'::json,
    '[{"key":"brand","name":"品牌"},{"key":"store_name","name":"門市名稱"},{"key":"address","name":"地址"},{"key":"phone","name":"電話"},{"key":"city","name":"城市"}]'::json
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

DELETE FROM public.component_maps
WHERE id = 1
  AND index = 'reusable_cup_store_tpe'
  AND NOT EXISTS (
      SELECT 1
      FROM public.query_charts
      WHERE 1 = ANY(COALESCE(map_config_ids, '{}'))
  );

DELETE FROM public.query_charts
WHERE index = 'metrotaipei_reusable_cup'
  AND city = 'metrotaipei';

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
    'metrotaipei_reusable_cup',
    NULL,
    '{2}',
    '{"mode":"byParam","byParam":{"xParam":"district"}}'::json,
    'static',
    NULL,
    0,
    NULL,
    '環境部',
    '顯示雙北各行政區循環杯服務門市數量。',
    '此圖表彙整臺北市與新北市提供循環杯服務的業者門市，以行政區統計服務點數量，並搭配點位地圖呈現分布。',
    '可用於檢視雙北循環杯服務布建情形，作為循環經濟、減塑政策與服務據點配置參考。',
    '{https://data.moenv.gov.tw/}',
    '{doit,ntpc}',
    NOW(),
    NOW(),
    'three_d',
    'SELECT district AS x_axis, city AS y_axis, count::int AS data FROM public.reusable_cup_stats WHERE city IN (''臺北市'', ''新北市'') ORDER BY data DESC, district',
    NULL,
    'metrotaipei'
);

UPDATE public.dashboards
SET components = array_append(COALESCE(components, '{}'), 301),
    updated_at = NOW()
WHERE index = 'circular-economy'
  AND NOT 301 = ANY(COALESCE(components, '{}'));

COMMIT;
