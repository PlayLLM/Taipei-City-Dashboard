-- ============================================================
-- 舊衣回收箱組件配置
-- 使用 symbol 類型 + shirt SVG 圖示（透過 Canvas 預載機制支援）
-- 資料庫: dashboardmanager
-- ============================================================

BEGIN;

-- 1. 更新圖表配置 (使用 ColumnChart 縱向長條圖)
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'metrotaipei_used_clothing_box',
    ARRAY['#B3C7F0', '#7EA5E8', '#4A80E0', '#2B5FBF', '#1A3D8F'], -- 5段漸層色，對應低→高數量
    ARRAY['DistrictChart', 'ColumnChart'],
    '個'
)
ON CONFLICT (index) DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

-- 2. 地圖圖層設定 (symbol 類型 + shirt SVG 圖示)
INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES (
    330,
    'used_clothing_box_metrotaipei',
    '雙北舊衣回收箱',
    'symbol',
    'geojson',
    'big',
    'shirt',
    '{}'::json,
    '[
        {"key":"org","name":"設置單位"},
        {"key":"address","name":"地址"},
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

-- 3. 修正查詢邏輯 (two_d 模式)
DELETE FROM public.query_charts
WHERE index = 'metrotaipei_used_clothing_box'
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
    'metrotaipei_used_clothing_box',
    NULL,
    '{330}',
    '{"mode":"byParam","byParam":{"xParam":"district"}}'::json,
    'static',
    NULL,
    0,
    NULL,
    '臺北市環保局、新北市環保局',
    '顯示雙北各行政區舊衣回收箱數量。',
    '此圖表彙整臺北市與新北市核准設置的舊衣回收箱資料，以行政區統計回收箱數量，並搭配點位地圖呈現分布。',
    '可用於檢視回收箱布建情形，方便市民尋找鄰近回收據點，並作為資源回收政策評估參考。',
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
    LEFT JOIN public.used_clothing_box_stats s ON s.district = d.district
    GROUP BY d.district
    ORDER BY data DESC, d.district',
    NULL,
    'metrotaipei'
);

-- 4. 補齊 public.components 缺少的 rows
INSERT INTO public.components (id, index, name)
VALUES (330, 'metrotaipei_used_clothing_box', '雙北各區舊衣回收箱數量')
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    name  = EXCLUDED.name;

-- 5. 將組件掛到「循環經濟」儀表板 (id: 402, index: circular-economy)
UPDATE public.dashboards
SET components = array_append(COALESCE(components, '{}'), 330),
    updated_at = NOW()
WHERE index = 'circular-economy'
  AND NOT 330 = ANY(COALESCE(components, '{}'));

COMMIT;
