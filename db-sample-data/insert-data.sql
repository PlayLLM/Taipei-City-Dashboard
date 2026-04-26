-- ============================================
-- 範例：新增一個「公車站點統計」組件和儀表板
-- ============================================

-- 步驟 1：新增組件基本資訊到 components 表
-- 注意：id 需要是唯一值，先查詢最大 id 再加 1
INSERT INTO public.components (id, index, name)
VALUES (
    300,                      -- 組件 ID（確認未被使用，現有最大約 218）
    'bus_stop_stats',         -- 組件識別碼（英文，用於 URL）
    '公車站點統計'             -- 顯示名稱
);

-- 步驟 2：新增組件詳細設定到 query_charts 表
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
    'bus_stop_stats',           -- 與 components.index 對應
    NULL,                       -- history_config
    '{}',                       -- map_config_ids（非地圖組件設為空）
    '{}',                       -- map_filter
    'static',                   -- time_from: static/current
    NULL,                       -- time_to
    0,                          -- update_freq: 0=不自動更新
    NULL,                       -- update_freq_unit
    '交通局',                   -- source: 資料來源
    '顯示臺北市各行政區公車站點數量統計。',  -- short_desc
    '此圖表呈現臺北市各行政區的公車站點數量分布，可協助了解市區公車服務覆蓋範圍，作為交通規劃與資源分配的參考依據。',  -- long_desc
    '適用於交通規劃與公共運輸分析，政府單位可根據各行政區站點數量評估公車服務均衡性，優化路線規劃。',  -- use_case
    '{https://data.taipei/dataset/公車站點}',  -- links
    '{doit}',                   -- contributors
    NOW(),
    NOW(),
    'two_d',                    -- query_type: two_d/two_d/percent/three_d/time/map_legend
    'SELECT district as x_axis, ''站點數'' as y_axis, COUNT(*) as data FROM bus_stops GROUP BY district ORDER BY data DESC',  -- query_chart: SQL 查詢
    NULL,                       -- query_history
    'taipei'                    -- city: taipei/newtaipei/metrotaipei
);

-- 步驟 3：新增儀表板到 dashboards 表
INSERT INTO public.dashboards (id, index, name, components, icon, updated_at, created_at)
VALUES (
    400,                        -- 儀表板 ID（確認唯一）
    'transport-analysis',       -- 儀表板識別碼
    '交通分析',                  -- 顯示名稱
    '{300}',                    -- 組件 ID 陣列（引用步驟 1 的 ID）
    'directions_car',           -- 圖示名稱（Material Icon）
    NOW(),
    NOW()
);

-- 步驟 4：將儀表板關聯到城市群組
INSERT INTO public.dashboard_groups (dashboard_id, group_id)
VALUES (400, 2);  -- group_id: 1=public, 2=taipei, 3=metrotaipei;

-- 為 metrotaipei 也插入一筆（複製剛才的資料，改 city）
INSERT INTO public.query_charts (
    index, history_config, map_config_ids, map_filter,
    time_from, time_to, update_freq, update_freq_unit,
    source, short_desc, long_desc, use_case, links, contributors,
    created_at, updated_at, query_type, query_chart, query_history, city
) VALUES (
    'bus_stop_stats', NULL, '{}', '{}', 'static', NULL, 0, NULL,
    '交通局', '顯示臺北市各行政區公車站點數量統計。',
    '此圖表呈現臺北市各行政區的公車站點數量分布...',
    '適用於交通規劃與公共運輸分析...',
    '{https://data.taipei/dataset/公車站點}', '{doit}',
    NOW(), NOW(), 'two_d',
    'SELECT district as x_axis, ''站點數'' as y_axis, COUNT(*) as data FROM bus_stops GROUP BY district ORDER BY data DESC',
    NULL, 'metrotaipei'  -- 改這裡
);

-- ============================================
-- 新增組件：自行車路網長度統計
-- ============================================

-- 步驟 1：新增組件基本資訊
INSERT INTO public.components (id, index, name)
VALUES (302, 'bike_network_length', '自行車路網長度統計');

-- 步驟 2：新增圖表設定（使用 ColumnChart）
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'bike_network_length',
    ARRAY['#4CAF50', '#8BC34A', '#CDDC39', '#FFEB3B', '#FFC107', '#FF9800'],
    ARRAY['ColumnChart'],
    '公里'
);

-- 步驟 3：新增查詢設定
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
    '顯示臺北市各行政區自行車路網總長度。',
    '此圖表呈現臺北市各行政區的自行車路網總長度，可協助了解各區自行車道建設情況，作為綠色交通規劃的參考依據。',
    '適用於交通規劃與綠色運輸分析，政府單位可根據各區路網長度評估自行車道建設均衡性，優化路網規劃。',
    '{https://data.taipei/dataset/自行車道}',
    '{doit}',
    NOW(),
    NOW(),
    'two_d',
    'SELECT COALESCE(direction, ''未知'') as x_axis, ''總長度'' as y_axis, ROUND((SUM(cycling_length)/1000)::numeric, 2) as data FROM public.bike_network_tpe WHERE city = ''台北市'' GROUP BY direction ORDER BY data DESC',
    NULL,
    'taipei'
);

-- 步驟 4：將組件加入交通分析儀表板
UPDATE public.dashboards
SET components = array_append(components, 302)
WHERE index = 'transport-analysis';

-- ============================================
-- 新增組件：氣泡圖範例（三維數據）
-- ============================================

-- 步驟 1：新增組件基本資訊
INSERT INTO public.components (id, index, name)
VALUES (303, 'bubble_demo', '氣泡圖範例');

-- 步驟 2：新增圖表設定（使用 BubbleChart）
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'bubble_demo',
    ARRAY['#4CAF50', '#2196F3', '#FF9800', '#F44336', '#9C27B0'],
    ARRAY['BubbleChart'],
    '數值'
);

-- 步驟 3：新增查詢設定
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
    'bubble_demo',
    NULL,
    '{}',
    '{}',
    'static',
    NULL,
    0,
    NULL,
    '示範',
    '顯示三維數據的氣泡圖範例。',
    '此圖表呈現三維數據（X軸、Y軸、氣泡大小），適用於多變量分析，如收入與支出與人數的關係。',
    '適用於多變量數據分析，可同時觀察三個變數之間的關係。',
    '{}',
    '{doit}',
    NOW(),
    NOW(),
    'two_d',
    'SELECT 10 as x_axis, 20 as y_axis, 15 as z_axis UNION ALL SELECT 20, 30, 25 UNION ALL SELECT 30, 15, 35 UNION ALL SELECT 40, 40, 20 UNION ALL SELECT 50, 25, 45',
    NULL,
    'taipei'
);

-- 步驟 4：將組件加入交通分析儀表板
UPDATE public.dashboards
SET components = array_append(components, 303)
WHERE index = 'transport-analysis';