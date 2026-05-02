BEGIN;

INSERT INTO public.dashboards (id, index, name, components, icon, updated_at, created_at)
VALUES (
    403,
    'all-in-one',
    'All in One',
    '{}',
    'dashboard',
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
JOIN public.groups g ON g.name = 'metrotaipei' AND g.is_personal IS FALSE
WHERE d.index = 'all-in-one'
ON CONFLICT DO NOTHING;

DELETE FROM public.dashboard_groups dg
USING public.dashboards d, public.groups g
WHERE dg.dashboard_id = d.id
  AND dg.group_id = g.id
  AND d.index = 'all-in-one'
  AND g.name IN ('public', 'taipei')
  AND g.is_personal IS FALSE;

INSERT INTO public.components (id, index, name) VALUES
    (301, 'metrotaipei_reusable_cup', '雙北各區循環杯門市數量'),
    (302, 'metrotaipei_eco_restaurant', '雙北各區環保餐廳數量'),
    (303, 'metrotaipei_scooter_charging', '雙北各區機車充電站數量'),
    (304, 'recycling_station_distribution', '資源回收站分布'),
    (305, 'metrotaipei_drinking_fountain', '飲水機與直飲臺分布'),
    (306, 'green_store_distribution', '綠色商店分布'),
    (500, 'eco_hotel', '環保旅宿')
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    name = EXCLUDED.name;

DO $$
DECLARE
    target_components INT[] := ARRAY[301, 302, 303, 304, 305, 306, 500];
    component_id INT;
BEGIN
    FOREACH component_id IN ARRAY target_components LOOP
        UPDATE public.dashboards
        SET components = array_append(COALESCE(components, '{}'), component_id),
            updated_at = NOW()
        WHERE index = 'all-in-one'
          AND NOT component_id = ANY(COALESCE(components, '{}'));
    END LOOP;
END $$;

COMMIT;
