-- ============================================================
-- 飲水機與直飲臺組件配置
-- 資料庫: dashboardmanager
-- ============================================================
-- 前置條件：
--   1. 已在 dashboard 資料庫執行 db-sample-data/add_drinking_fountain_data.sql
--   2. 已將 GeoJSON 放置於前端目錄：
--      FE/public/mapData/drinking_fountain_metrotaipei.geojson
--
-- 執行方式：
--   docker cp db-sample-data/add_drinking_fountain_component.sql postgres-manager:/tmp/
--   docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_drinking_fountain_component.sql
-- ============================================================

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
VALUES (305, 'metrotaipei_drinking_fountain', '飲水機與直飲臺分布')
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    name = EXCLUDED.name;

INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'metrotaipei_drinking_fountain',
    ARRAY['#2F8AB1', '#4CB495'],
    ARRAY['RadarChart', 'ColumnChart'],
    '處'
)
ON CONFLICT (index) DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES (
    330,
    'drinking_fountain_metrotaipei',
    '雙北飲水機與直飲臺',
    'circle',
    'geojson',
    'big',
    NULL,
    '{"circle-color":"#2F8AB1","circle-opacity":0.85,"circle-stroke-color":"#FFFFFF","circle-stroke-width":1.2}'::json,
    '[
        {"key":"source_type","name":"類型"},
        {"key":"name","name":"場所名稱"},
        {"key":"address","name":"地址"},
        {"key":"city","name":"城市"},
        {"key":"district","name":"行政區"},
        {"key":"managing_unit","name":"所屬單位"},
        {"key":"maintenance_unit","name":"維護單位"},
        {"key":"open_time","name":"開放時間"},
        {"key":"location","name":"設置地點"},
        {"key":"status","name":"狀態"},
        {"key":"info_url","name":"水質資訊網址"},
        {"key":"photo_url","name":"照片網址"}
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

DELETE FROM public.query_charts
WHERE index = 'metrotaipei_drinking_fountain'
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
    'metrotaipei_drinking_fountain',
    NULL,
    '{330}',
    '{"mode":"byParam","byParam":{"xParam":"district","yParam":"source_type"}}'::json,
    'static',
    NULL,
    0,
    NULL,
    '臺北自來水事業處',
    '顯示雙北各行政區飲水機與直飲臺數量。',
    '此圖表彙整臺北市公共場所飲水機與直飲臺資料，以行政區統計各類型點位數量，並搭配點位地圖呈現分布。',
    '可用於檢視雙北公共飲水設施的布建情形，作為民眾查詢與公共服務配置參考。',
    '{https://gismobile.water.gov.taipei/}',
    '{doit,ntpc}',
    NOW(),
    NOW(),
    'three_d',
    'WITH districts AS (
        SELECT unnest(ARRAY[''北投區'', ''士林區'', ''內湖區'', ''南港區'', ''松山區'', ''信義區'', ''中山區'', ''大同區'', ''中正區'', ''萬華區'', ''大安區'', ''文山區'', ''新莊區'', ''淡水區'', ''汐止區'', ''板橋區'', ''三重區'', ''樹林區'', ''土城區'', ''蘆洲區'', ''中和區'', ''永和區'', ''新店區'', ''鶯歌區'', ''三峽區'', ''瑞芳區'', ''五股區'', ''泰山區'', ''林口區'', ''深坑區'', ''石碇區'', ''坪林區'', ''三芝區'', ''石門區'', ''八里區'', ''平溪區'', ''雙溪區'', ''貢寮區'', ''金山區'', ''萬里區'', ''烏來區'']) AS district
    ), types AS (
        SELECT unnest(ARRAY[''飲水機'', ''直飲臺'']) AS source_type
    ), stats AS (
        SELECT district, source_type, COUNT(*)::int AS count
        FROM public.drinking_fountain_sites
        WHERE city IN (''臺北市'', ''新北市'')
        GROUP BY district, source_type
    )
    SELECT
        d.district AS x_axis,
        t.source_type AS y_axis,
        COALESCE(s.count, 0)::int AS data
    FROM districts d
    CROSS JOIN types t
    LEFT JOIN stats s
        ON s.district = d.district
       AND s.source_type = t.source_type
    ORDER BY
        array_position(ARRAY[''北投區'', ''士林區'', ''內湖區'', ''南港區'', ''松山區'', ''信義區'', ''中山區'', ''大同區'', ''中正區'', ''萬華區'', ''大安區'', ''文山區'', ''新莊區'', ''淡水區'', ''汐止區'', ''板橋區'', ''三重區'', ''樹林區'', ''土城區'', ''蘆洲區'', ''中和區'', ''永和區'', ''新店區'', ''鶯歌區'', ''三峽區'', ''瑞芳區'', ''五股區'', ''泰山區'', ''林口區'', ''深坑區'', ''石碇區'', ''坪林區'', ''三芝區'', ''石門區'', ''八里區'', ''平溪區'', ''雙溪區'', ''貢寮區'', ''金山區'', ''萬里區'', ''烏來區''], d.district),
        array_position(ARRAY[''飲水機'', ''直飲臺''], t.source_type)',
    NULL,
    'metrotaipei'
);

UPDATE public.dashboards
SET components = array_append(components, 305),
    updated_at = NOW()
WHERE index = 'climate-environment'
  AND NOT 305 = ANY(components);

COMMIT;
