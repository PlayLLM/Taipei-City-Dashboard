-- ============================================================
-- 環保旅宿組件配置
-- 資料庫: dashboardmanager
-- ============================================================
--
-- 前置條件：
--   1. 已在 dashboard 資料庫執行 db-sample-data/add_eco_hotel_data.sql
--   2. 已將 GeoJSON 放置於前端目錄：
--      FE/public/mapData/eco_hotel_tpe.geojson
--      FE/public/mapData/eco_hotel_metrotaipei.geojson
--
-- 執行方式：
--   docker cp db-sample-data/add_eco_hotel_component.sql postgres-manager:/tmp/
--   docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_eco_hotel_component.sql
--
-- ============================================================

BEGIN;

-- ① component_charts
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'eco_hotel',
    ARRAY['#F5C518', '#ABABAB', '#CD7F32'],
    ARRAY['ColumnChart'],
    '間'
)
ON CONFLICT (index) DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit  = EXCLUDED.unit;

-- ② component_maps：臺北市圖層
INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES (
    300,
    'eco_hotel_tpe',
    '臺北市環保旅宿',
    'circle',
    'geojson',
    'big',
    NULL,
    '{
        "circle-color": ["match", ["get", "grade"],
            "金級", "#F5C518",
            "銀級", "#ABABAB",
            "銅級", "#CD7F32",
            "#4CAF50"
        ],
        "circle-opacity": 0.9,
        "circle-stroke-color": "#ffffff",
        "circle-stroke-width": 1.2
    }'::json,
    '[
        {"key": "name",     "name": "旅館名稱"},
        {"key": "grade",    "name": "環保等級"},
        {"key": "address",  "name": "地址"},
        {"key": "phone",    "name": "電話"},
        {"key": "district", "name": "行政區"}
    ]'::json
)
ON CONFLICT (id) DO UPDATE
SET index    = EXCLUDED.index,
    title    = EXCLUDED.title,
    type     = EXCLUDED.type,
    source   = EXCLUDED.source,
    size     = EXCLUDED.size,
    paint    = EXCLUDED.paint,
    property = EXCLUDED.property;

-- ③ component_maps：雙北圖層
INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES (
    301,
    'eco_hotel_metrotaipei',
    '雙北環保旅宿',
    'circle',
    'geojson',
    'big',
    NULL,
    '{
        "circle-color": ["match", ["get", "grade"],
            "金級", "#F5C518",
            "銀級", "#ABABAB",
            "銅級", "#CD7F32",
            "#4CAF50"
        ],
        "circle-opacity": 0.9,
        "circle-stroke-color": "#ffffff",
        "circle-stroke-width": 1.2
    }'::json,
    '[
        {"key": "name",     "name": "旅館名稱"},
        {"key": "grade",    "name": "環保等級"},
        {"key": "address",  "name": "地址"},
        {"key": "phone",    "name": "電話"},
        {"key": "city",     "name": "城市"},
        {"key": "district", "name": "行政區"}
    ]'::json
)
ON CONFLICT (id) DO UPDATE
SET index    = EXCLUDED.index,
    title    = EXCLUDED.title,
    type     = EXCLUDED.type,
    source   = EXCLUDED.source,
    size     = EXCLUDED.size,
    paint    = EXCLUDED.paint,
    property = EXCLUDED.property;

-- ④ components
INSERT INTO public.components (id, index, name)
VALUES (500, 'eco_hotel', '環保旅宿')
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    name  = EXCLUDED.name;

-- ⑤ query_charts
DELETE FROM public.query_charts
WHERE index = 'eco_hotel'
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
-- 臺北市版本
(
    'eco_hotel',
    NULL,
    '{300}',
    '{"mode":"byParam","byParam":{"xParam":"grade"}}'::json,
    'static',
    NULL,
    0,
    NULL,
    '環境部',
    '顯示臺北市各行政區環保標章旅宿數量及等級分布。',
    '此圖表彙整臺北市取得環境部環保標章的旅宿資料，依行政區與環保等級（金級、銀級、銅級）統計各區旅宿數量，並在地圖上以顏色標示旅宿位置與等級。',
    '可用於了解臺北市各行政區環保旅宿的分布情形與等級結構，作為綠色旅遊選擇參考。',
    '{https://ecolife.epa.gov.tw/}',
    '{doit}',
    NOW(),
    NOW(),
    'three_d',
    'WITH grades AS (
        SELECT unnest(ARRAY[''金級'', ''銀級'', ''銅級'']) AS grade
     ),
     districts AS (
        SELECT DISTINCT district FROM public.eco_hotel_metrotaipei WHERE city = ''臺北市''
     )
     SELECT d.district AS x_axis, g.grade AS y_axis, COUNT(e.name)::int AS data
     FROM districts d
     CROSS JOIN grades g
     LEFT JOIN public.eco_hotel_metrotaipei e ON e.district = d.district AND e.grade = g.grade AND e.city = ''臺北市''
     GROUP BY d.district, g.grade
     ORDER BY d.district, g.grade',
    NULL,
    'taipei'
),
-- 雙北版本
(
    'eco_hotel',
    NULL,
    '{301}',
    '{"mode":"byParam","byParam":{"xParam":"grade"}}'::json,
    'static',
    NULL,
    0,
    NULL,
    '環境部',
    '顯示雙北各行政區環保標章旅宿數量及等級分布。',
    '此圖表彙整臺北市與新北市取得環境部環保標章的旅宿資料，依行政區與環保等級（金級、銀級、銅級）統計各區旅宿數量，並在地圖上以顏色標示旅宿位置與等級。',
    '可用於比較雙北各行政區環保旅宿的分布情形與等級結構，作為跨市觀光資源規劃參考。',
    '{https://ecolife.epa.gov.tw/}',
    '{doit,ntpc}',
    NOW(),
    NOW(),
    'three_d',
    'WITH grades AS (
        SELECT unnest(ARRAY[''金級'', ''銀級'', ''銅級'']) AS grade
     ),
     districts AS (
        SELECT DISTINCT district FROM public.eco_hotel_metrotaipei
     )
     SELECT d.district AS x_axis, g.grade AS y_axis, COUNT(e.name)::int AS data
     FROM districts d
     CROSS JOIN grades g
     LEFT JOIN public.eco_hotel_metrotaipei e ON e.district = d.district AND e.grade = g.grade
     GROUP BY d.district, g.grade
     ORDER BY d.district, g.grade',
    NULL,
    'metrotaipei'
);

-- ⑥ 將組件加入「循環經濟」儀表板
UPDATE public.dashboards
SET components = array_append(COALESCE(components, '{}'), 500),
    updated_at = NOW()
WHERE index IN ('circular-economy', 'circular')
  AND NOT 500 = ANY(COALESCE(components, '{}'));

COMMIT;
