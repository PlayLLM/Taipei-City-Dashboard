-- ============================================================
-- 環保餐廳組件配置 (最終修正版)
-- 修正：使用 two_d 查詢類型以簡化 Hover、確保所有行政區皆有數據 (解決 0間問題)
-- 資料庫: dashboardmanager
-- ============================================================

BEGIN;

-- 1. 更新圖表配置 (使用 ColumnChart 縱向長條圖)
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'metrotaipei_eco_restaurant',
    ARRAY['#FF9800'],
    ARRAY['DistrictChart', 'ColumnChart'],
    '間'
)
ON CONFLICT (index) DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

-- 1b. 確保組件存在
INSERT INTO public.components (id, index, name)
VALUES (312, 'metrotaipei_eco_restaurant', '雙北各區環保餐廳數量')
ON CONFLICT (index) DO UPDATE
SET id = EXCLUDED.id,
    name = EXCLUDED.name;

-- 2. 地圖圖層設定
INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES (
    310,
    'eco_restaurant_metrotaipei',
    '雙北環保餐廳',
    'circle',
    'geojson',
    'big',
    NULL,
    '{"circle-color":"#FF9800","circle-opacity":0.85,"circle-stroke-color":"#FFFFFF","circle-stroke-width":1.2}'::json,
    '[
        {"key":"name","name":"餐廳名稱"},
        {"key":"address","name":"地址"},
        {"key":"phone","name":"電話"},
        {"key":"city","name":"城市"},
        {"key":"district","name":"行政區"}
    ]'::json
)
ON CONFLICT (id) DO UPDATE
SET index    = EXCLUDED.index,
    title    = EXCLUDED.title,
    type     = EXCLUDED.type,
    source   = EXCLUDED.source,
    size     = EXCLUDED.size,
    icon     = EXCLUDED.icon,
    paint    = EXCLUDED.paint,
    property = EXCLUDED.property;

-- 3. 修正查詢邏輯 (改為 two_d 模式)
DELETE FROM public.query_charts
WHERE index = 'metrotaipei_eco_restaurant'
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
    'metrotaipei_eco_restaurant',
    NULL,
    '{310}',
    '{"mode":"byParam","byParam":{"xParam":"district"}}'::json,
    'static',
    NULL,
    0,
    NULL,
    '環境部',
    '顯示雙北各行政區環保餐廳數量。',
    '此圖表彙整臺北市與新北市之環保餐廳資料，以行政區統計據點數量，並搭配點位地圖呈現分布。',
    '可用於檢視雙北環保餐廳分布情形，推廣綠色消費與循環經濟。',
    '{https://data.moenv.gov.tw/}',
    '{doit,ntpc}',
    NOW(),
    NOW(),
    'two_d', -- 改為 two_d 模式，不再有系列標籤
    'WITH districts AS (
        SELECT unnest(ARRAY[''北投區'', ''士林區'', ''內湖區'', ''南港區'', ''松山區'', ''信義區'', ''中山區'', ''大同區'', ''中正區'', ''萬華區'', ''大安區'', ''文山區'', ''新莊區'', ''淡水區'', ''汐止區'', ''板橋區'', ''三重區'', ''樹林區'', ''土城區'', ''蘆洲區'', ''中和區'', ''永和區'', ''新店區'', ''鶯歌區'', ''三峽區'', ''瑞芳區'', ''五股區'', ''泰山區'', ''林口區'', ''深坑區'', ''石碇區'', ''坪林區'', ''三芝區'', ''石門區'', ''八里區'', ''平溪區'', ''雙溪區'', ''貢寮區'', ''金山區'', ''萬里區'', ''烏來區'']) AS district
    )
    SELECT 
        d.district AS x_axis, 
        COALESCE(SUM(s.count), 0)::int AS data
    FROM districts d
    LEFT JOIN public.eco_restaurant_stats s ON s.district = d.district
    GROUP BY d.district
    ORDER BY data DESC, d.district',
    NULL,
    'metrotaipei'
);

COMMIT;
