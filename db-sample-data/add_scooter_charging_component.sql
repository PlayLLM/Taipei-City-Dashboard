-- ============================================================
-- 機車充電站組件配置
-- 資料庫: dashboardmanager
-- ============================================================
--
-- 前置條件：
--   1. 已在 dashboard 資料庫執行 db-sample-data/add_scooter_charging_data.sql
--   2. 已將 GeoJSON 放置於前端目錄：
--      FE/public/mapData/scooter_charging_tpe.geojson
--      FE/public/mapData/scooter_charging_metrotaipei.geojson
--
-- 執行方式：
--   docker cp db-sample-data/add_scooter_charging_component.sql postgres-manager:/tmp/
--   docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_scooter_charging_component.sql
-- ============================================================

BEGIN;

-- 1. 更新圖表配置 (行政區圖 + 縱向長條圖)
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'metrotaipei_scooter_charging',
    ARRAY['#00A3E0'],
    ARRAY['DistrictChart', 'ColumnChart'],
    '站'
)
ON CONFLICT (index) DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

-- 1b. 確保組件存在
INSERT INTO public.components (id, index, name)
VALUES (313, 'metrotaipei_scooter_charging', '雙北各區機車充電站數量')
ON CONFLICT (index) DO UPDATE
SET id = EXCLUDED.id,
    name = EXCLUDED.name;

-- 2. 地圖圖層配置
INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES (
    320,
    'scooter_charging_metrotaipei',
    '雙北機車充電站',
    'circle',
    'geojson',
    'big',
    NULL,
    '{"circle-color":"#00A3E0","circle-opacity":0.85,"circle-stroke-color":"#FFFFFF","circle-stroke-width":1.2}'::json,
    '[
        {"key":"name","name":"站點名稱"},
        {"key":"operator","name":"廠商"},
        {"key":"address","name":"地址"},
        {"key":"city","name":"城市"},
        {"key":"district","name":"行政區"},
        {"key":"station_type","name":"站點類型"},
        {"key":"operational_status","name":"營運狀態"},
        {"key":"fee_applicable","name":"是否收費"},
        {"key":"open_to_public","name":"是否對外開放"},
        {"key":"plug_type","name":"充電型式"},
        {"key":"connector_count","name":"接口數量"}
    ]'::json
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

-- 3. 查詢邏輯 (two_d)
DELETE FROM public.query_charts
WHERE index = 'metrotaipei_scooter_charging'
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
    'metrotaipei_scooter_charging',
    NULL,
    '{320}',
    '{"mode":"byParam","byParam":{"xParam":"district"}}'::json,
    'static',
    NULL,
    0,
    NULL,
    '新北市政府、臺北市政府',
    '顯示雙北各行政區機車充電站數量。',
    '此圖表彙整臺北市與新北市機車充電站資料，以行政區統計站點數量，並搭配點位地圖呈現分布情形。',
    '可用於檢視雙北機車充電站分布情形，作為電動機車補給規劃與建置參考。',
    '{https://data.taipei/,https://data.ntpc.gov.tw/}',
    '{doit,ntpc}',
    NOW(),
    NOW(),
    'two_d',
    'WITH districts AS (
        SELECT unnest(ARRAY[''北投區'', ''士林區'', ''內湖區'', ''南港區'', ''松山區'', ''信義區'', ''中山區'', ''大同區'', ''中正區'', ''萬華區'', ''大安區'', ''文山區'', ''新莊區'', ''淡水區'', ''汐止區'', ''板橋區'', ''三重區'', ''樹林區'', ''土城區'', ''蘆洲區'', ''中和區'', ''永和區'', ''新店區'', ''鶯歌區'', ''三峽區'', ''瑞芳區'', ''五股區'', ''泰山區'', ''林口區'', ''深坑區'', ''石碇區'', ''坪林區'', ''三芝區'', ''石門區'', ''八里區'', ''平溪區'', ''雙溪區'', ''貢寮區'', ''金山區'', ''萬里區'', ''烏來區'']) AS district
    )
    SELECT
        d.district AS x_axis,
        COALESCE(SUM(s.count), 0)::int AS data
    FROM districts d
    LEFT JOIN public.scooter_charging_station_stats s ON s.district = d.district
    GROUP BY d.district
    ORDER BY data DESC, d.district',
    NULL,
    'metrotaipei'
);

COMMIT;
