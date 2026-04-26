-- ============================================
-- 氣泡圖組件資料庫操作腳本
-- ============================================
-- 用途：新增氣泡圖組件到資料庫
-- 執行方式：
--   docker cp add-bubble-chart.sql postgres-manager:/tmp/
--   docker exec -it postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add-bubble-chart.sql
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
    'SELECT 10 as x_axis, 20 as y_axis, 15 as data UNION ALL SELECT 20, 30, 25 UNION ALL SELECT 30, 15, 35 UNION ALL SELECT 40, 40, 20 UNION ALL SELECT 50, 25, 45',
    NULL,
    'taipei'
);

-- 步驟 4：將組件加入交通分析儀表板
UPDATE public.dashboards
SET components = array_append(components, 303)
WHERE index = 'transport-analysis';

-- ============================================
-- 刪除氣泡圖組件（如需移除時使用）
-- ============================================
-- DELETE FROM public.query_charts WHERE index = 'bubble_demo';
-- DELETE FROM public.component_charts WHERE index = 'bubble_demo';
-- DELETE FROM public.components WHERE index = 'bubble_demo';
-- UPDATE public.dashboards SET components = array_remove(components, 303) WHERE index = 'transport-analysis';
