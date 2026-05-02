-- 新增「綠色商店分布」組件到 dashboardmanager 資料庫。
--
-- 建議執行方式：
--   node scripts/apply_dashboardmanager_consistency_repairs.mjs
--
-- 本組件以 SQL 新增 components、component_charts 與 query_charts。
-- 直接執行 SQL 後，必須重建 Qdrant，LLM／向量搜尋才會查到新的組件內容。
--
-- 前置條件：
--   1. 已在 dashboard 資料庫執行 db-sample-data/add_green_store_data.sql
--   2. public.green_store_tpe 與 public.green_store_new_tpe 已存在
--
-- 手動執行方式：
--   docker cp db-sample-data/add_green_store_component.sql postgres-manager:/tmp/add_green_store_component.sql
--   docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_green_store_component.sql
--
-- 圖表說明：
--   1. HeatmapChart 使用 x_axis=行政區、y_axis=通路品牌、data=店數。
--   2. DistrictChart 會彙總同一行政區所有 y_axis 的店數，並在 tooltip 顯示品牌拆分。

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
JOIN public.groups g ON g.name IN ('public', 'taipei', 'metrotaipei') AND g.is_personal IS FALSE
WHERE d.index = 'climate-environment'
ON CONFLICT DO NOTHING;

INSERT INTO public.components (id, index, name)
VALUES (305, 'green_store_distribution', '綠色商店分布')
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    name = EXCLUDED.name;

INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'green_store_distribution',
    ARRAY['#A83F3F', '#C66D2D', '#3E70A8'],
    ARRAY['HeatmapChart', 'DistrictChart'],
    '家'
)
ON CONFLICT (index) DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit = EXCLUDED.unit;

DELETE FROM public.query_charts
WHERE index = 'green_store_distribution'
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
    'green_store_distribution',
    NULL,
    '{}',
    NULL,
    'static',
    NULL,
    1,
    'month',
    '環境部',
    '顯示臺北市各行政區綠色商店數量與通路品牌分布。',
    '此圖表彙整臺北市綠色商店資料，以行政區與通路品牌統計店數。熱力圖呈現各行政區不同通路品牌的分布，行政區圖呈現各區綠色商店總量。',
    '可用於了解臺北市綠色消費據點分布，作為環境教育、綠色採購推廣與服務可近性分析參考。',
    '{https://greenliving.epa.gov.tw/}',
    '{doit}',
    NOW(),
    NOW(),
    'three_d',
    'WITH brand_order(brand, sort_order) AS (
        VALUES
            (''7-ELEVEN'', 1),
            (''全家'', 2),
            (''萊爾富'', 3),
            (''全國電子'', 4),
            (''燦坤'', 5),
            (''全聯'', 6),
            (''寶雅'', 7),
            (''其他'', 8)
     ),
     district_order(district, sort_order) AS (
        VALUES
            (''北投區'', 1),
            (''士林區'', 2),
            (''內湖區'', 3),
            (''南港區'', 4),
            (''松山區'', 5),
            (''信義區'', 6),
            (''中山區'', 7),
            (''大同區'', 8),
            (''中正區'', 9),
            (''萬華區'', 10),
            (''大安區'', 11),
            (''文山區'', 12)
     ),
     counts AS (
        SELECT district, brand, COUNT(*)::int AS store_count
        FROM public.green_store_tpe
        GROUP BY district, brand
     )
     SELECT
        d.district AS x_axis,
        b.brand AS y_axis,
        COALESCE(c.store_count, 0)::int AS data
     FROM brand_order b
     CROSS JOIN district_order d
     LEFT JOIN counts c ON c.district = d.district AND c.brand = b.brand
     ORDER BY b.sort_order, d.sort_order',
    NULL,
    'taipei'
),
(
    'green_store_distribution',
    NULL,
    '{}',
    NULL,
    'static',
    NULL,
    1,
    'month',
    '環境部',
    '顯示雙北各行政區綠色商店數量與通路品牌分布。',
    '此圖表彙整臺北市與新北市綠色商店資料，以行政區與通路品牌統計店數。熱力圖呈現各行政區不同通路品牌的分布，行政區圖呈現各區綠色商店總量。',
    '可用於比較雙北綠色消費據點分布，作為環境教育、綠色採購推廣與服務可近性分析參考。',
    '{https://greenliving.epa.gov.tw/}',
    '{doit,ntpc}',
    NOW(),
    NOW(),
    'three_d',
    'WITH brand_order(brand, sort_order) AS (
        VALUES
            (''7-ELEVEN'', 1),
            (''全家'', 2),
            (''萊爾富'', 3),
            (''全國電子'', 4),
            (''燦坤'', 5),
            (''全聯'', 6),
            (''寶雅'', 7),
            (''其他'', 8)
     ),
     district_order(district, sort_order) AS (
        VALUES
            (''北投區'', 1),
            (''士林區'', 2),
            (''內湖區'', 3),
            (''南港區'', 4),
            (''松山區'', 5),
            (''信義區'', 6),
            (''中山區'', 7),
            (''大同區'', 8),
            (''中正區'', 9),
            (''萬華區'', 10),
            (''大安區'', 11),
            (''文山區'', 12),
            (''新莊區'', 13),
            (''淡水區'', 14),
            (''汐止區'', 15),
            (''板橋區'', 16),
            (''三重區'', 17),
            (''樹林區'', 18),
            (''土城區'', 19),
            (''蘆洲區'', 20),
            (''中和區'', 21),
            (''永和區'', 22),
            (''新店區'', 23),
            (''鶯歌區'', 24),
            (''三峽區'', 25),
            (''瑞芳區'', 26),
            (''五股區'', 27),
            (''泰山區'', 28),
            (''林口區'', 29),
            (''深坑區'', 30),
            (''石碇區'', 31),
            (''坪林區'', 32),
            (''三芝區'', 33),
            (''石門區'', 34),
            (''八里區'', 35),
            (''平溪區'', 36),
            (''雙溪區'', 37),
            (''貢寮區'', 38),
            (''金山區'', 39),
            (''萬里區'', 40),
            (''烏來區'', 41)
     ),
     stores AS (
        SELECT district, brand FROM public.green_store_tpe
        UNION ALL
        SELECT district, brand FROM public.green_store_new_tpe
     ),
     counts AS (
        SELECT district, brand, COUNT(*)::int AS store_count
        FROM stores
        GROUP BY district, brand
     )
     SELECT
        d.district AS x_axis,
        b.brand AS y_axis,
        COALESCE(c.store_count, 0)::int AS data
     FROM brand_order b
     CROSS JOIN district_order d
     LEFT JOIN counts c ON c.district = d.district AND c.brand = b.brand
     ORDER BY b.sort_order, d.sort_order',
    NULL,
    'metrotaipei'
);

UPDATE public.dashboards
SET components = array_append(components, 305),
    updated_at = NOW()
WHERE index = 'climate-environment'
  AND NOT 305 = ANY(components);

COMMIT;
