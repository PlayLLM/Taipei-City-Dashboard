BEGIN;

UPDATE public.component_charts
SET color = ARRAY['#F5C518', '#ABABAB', '#CD7F32', '#4CAF50']
WHERE index = 'eco_hotel';

UPDATE public.query_charts
SET query_chart = '
    WITH grades AS (
        SELECT unnest(ARRAY[''金級'', ''銀級'', ''銅級'', ''其他'']) AS grade
    ),
    districts AS (
        SELECT DISTINCT district FROM public.eco_hotel_metrotaipei WHERE city = ''臺北市''
    )
    SELECT d.district AS x_axis, g.grade AS y_axis, COUNT(e.name)::int AS data
    FROM districts d
    CROSS JOIN grades g
    LEFT JOIN public.eco_hotel_metrotaipei e ON e.district = d.district AND e.grade = g.grade AND e.city = ''臺北市''
    GROUP BY d.district, g.grade
    ORDER BY d.district, g.grade
'
WHERE index = 'eco_hotel' AND city = 'taipei';

UPDATE public.query_charts
SET query_chart = '
    WITH grades AS (
        SELECT unnest(ARRAY[''金級'', ''銀級'', ''銅級'', ''其他'']) AS grade
    ),
    districts AS (
        SELECT DISTINCT district FROM public.eco_hotel_metrotaipei
    )
    SELECT d.district AS x_axis, g.grade AS y_axis, COUNT(e.name)::int AS data
    FROM districts d
    CROSS JOIN grades g
    LEFT JOIN public.eco_hotel_metrotaipei e ON e.district = d.district AND e.grade = g.grade
    GROUP BY d.district, g.grade
    ORDER BY d.district, g.grade
'
WHERE index = 'eco_hotel' AND city = 'metrotaipei';

COMMIT;
