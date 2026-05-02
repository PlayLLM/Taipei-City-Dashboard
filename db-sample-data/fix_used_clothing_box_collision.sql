-- ============================================================
-- 修正 ID 衝突：還原飲水機配置並為舊衣回收箱分配新 ID
-- ============================================================

BEGIN;

-- 1. 移除可能造成衝突的舊舊衣回收箱組件 (原本誤用 ID 330)
DELETE FROM public.components WHERE id = 330;
UPDATE public.dashboards SET components = array_remove(components, 330);

-- 2. 還原飲水機與直飲臺的地圖配置 (ID 330)
-- 參考自 add_drinking_fountain_component.sql
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

-- 3. 為舊衣回收箱建立新的地圖配置 (ID 331)
INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES (
    331,
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
SET index = EXCLUDED.index,
    title = EXCLUDED.title,
    type = EXCLUDED.type,
    source = EXCLUDED.source,
    size = EXCLUDED.size,
    icon = EXCLUDED.icon,
    paint = EXCLUDED.paint,
    property = EXCLUDED.property;

-- 4. 更新舊衣回收箱的圖表查詢，使其指向新的地圖 ID 331
UPDATE public.query_charts 
SET map_config_ids = '{331}'
WHERE index = 'metrotaipei_used_clothing_box';

-- 5. 確保舊衣回收箱組件使用新 ID 306
INSERT INTO public.components (id, index, name)
VALUES (306, 'metrotaipei_used_clothing_box', '雙北各區舊衣回收箱數量')
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    name = EXCLUDED.name;

-- 6. 將新組件 ID 306 掛到循環經濟儀表板
UPDATE public.dashboards
SET components = array_append(COALESCE(components, '{}'), 306),
    updated_at = NOW()
WHERE index = 'circular-economy'
  AND NOT 306 = ANY(COALESCE(components, '{}'));

COMMIT;
