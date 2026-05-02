-- ============================================================
-- 循環經濟 dashboard 與組件掛載
-- 資料庫: dashboardmanager
-- ============================================================
--
-- 用途：
--   建立 sidebar「雙北儀錶板 → 循環經濟」分頁，並掛上以下 5 個組件：
--     1. 301 metrotaipei_reusable_cup     雙北各區循環杯門市數量
--     2. 302 metrotaipei_eco_restaurant   雙北各區環保餐廳數量
--     3. 303 metrotaipei_scooter_charging 雙北各區機車充電站數量
--     4. 305 metrotaipei_drinking_fountain 雙北飲水機與直飲臺
--     5. 500 eco_hotel                    雙北環保旅宿
--
-- 前置條件：
--   先執行對應的 component SQL，確保 component_charts / component_maps /
--   query_charts 已建立：
--     - add_reusable_cup_component.sql
--     - add_eco_restaurant_component.sql
--     - add_scooter_charging_component.sql
--     - add_drinking_fountain_component.sql
--     - add_eco_hotel_component.sql
--
-- 執行方式：
--   docker cp db-sample-data/add_circular_economy_dashboard.sql postgres-manager:/tmp/
--   docker exec postgres-manager psql -U postgres -d dashboardmanager \
--     -f /tmp/add_circular_economy_dashboard.sql

BEGIN;

-- 1. 建立或更新 circular-economy dashboard
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

-- 2. 將 dashboard 掛到「雙北 (metrotaipei)」 group
INSERT INTO public.dashboard_groups (dashboard_id, group_id)
SELECT d.id, g.id
FROM public.dashboards d
JOIN public.groups g ON g.name = 'metrotaipei' AND g.is_personal IS FALSE
WHERE d.index = 'circular-economy'
ON CONFLICT DO NOTHING;

-- 3. 補齊 public.components 缺少的 rows
--    (循環杯、環保餐廳與機車充電站的 component SQL 沒有寫入 public.components)
INSERT INTO public.components (id, index, name) VALUES
    (301, 'metrotaipei_reusable_cup',     '雙北各區循環杯門市數量'),
    (302, 'metrotaipei_eco_restaurant',   '雙北各區環保餐廳數量'),
    (303, 'metrotaipei_scooter_charging', '雙北各區機車充電站數量')
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    name  = EXCLUDED.name;

-- 4. 將 5 個組件依序掛到 circular-economy dashboard（idempotent）
DO $$
DECLARE
    target_components INT[] := ARRAY[301, 302, 303, 305, 500];
    component_id INT;
BEGIN
    FOREACH component_id IN ARRAY target_components LOOP
        UPDATE public.dashboards
        SET components = array_append(COALESCE(components, '{}'), component_id),
            updated_at = NOW()
        WHERE index = 'circular-economy'
          AND NOT component_id = ANY(COALESCE(components, '{}'));
    END LOOP;
END $$;

COMMIT;
