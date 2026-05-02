-- ============================================================
-- 循環杯門市地圖組件配置 (完整版)
-- 資料庫: dashboardmanager
-- ============================================================
--
-- 前置條件：
--   1. 已在 dashboard 資料庫執行 etl_reusable_cup_stores.py
--      → public.reusable_cup_stores (含 lng/lat 精準座標)
--   2. 已將 GeoJSON 放置至前端目錄：
--      Taipei-City-Dashboard-FE/public/mapData/reusable_cup_store_tpe.geojson
--      Taipei-City-Dashboard-FE/public/mapData/reusable_cup_store_metrotaipei.geojson
--
-- 執行方式：
--   docker cp db-sample-data/add_reusable_cup_component.sql postgres-manager:/tmp/
--   docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_reusable_cup_component.sql
--
-- ============================================================

BEGIN;

-- ① component_maps：臺北市版點位圖層
INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES (
    1,
    'reusable_cup_store_tpe',
    '臺北市循環杯門市',
    'circle',
    'geojson',
    'big',
    NULL,
    '{"circle-color":"#4CAF50","circle-radius":["interpolate",["linear"],["zoom"],10,4,16,10],"circle-opacity":0.85,"circle-stroke-color":"#ffffff","circle-stroke-width":1}'::json,
    '[{"key":"brand","name":"品牌"},{"key":"store_name","name":"門市名稱"},{"key":"address","name":"地址"},{"key":"phone","name":"電話"}]'::json
)
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    title = EXCLUDED.title,
    type  = EXCLUDED.type,
    source = EXCLUDED.source,
    size  = EXCLUDED.size,
    paint = EXCLUDED.paint,
    property = EXCLUDED.property;

-- ② component_maps：雙北版點位圖層
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
    type  = EXCLUDED.type,
    source = EXCLUDED.source,
    size  = EXCLUDED.size,
    paint = EXCLUDED.paint,
    property = EXCLUDED.property;

-- ③ 更新 query_charts：將 map_config_ids 指向正確的 component_maps.id
UPDATE public.query_charts
SET map_config_ids = '{1}'
WHERE index = 'taipei_reusable_cup_map' AND city = 'taipei';

UPDATE public.query_charts
SET map_config_ids = '{2}'
WHERE index = 'metrotaipei_reusable_cup' AND city = 'metrotaipei';

COMMIT;
