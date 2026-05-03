BEGIN;

-- 1) Ensure the four GitHub contributors exist in contributors table.
SELECT setval(
    pg_get_serial_sequence('public.contributors', 'id'),
    COALESCE((SELECT MAX(id) FROM public.contributors), 0),
    TRUE
);

WITH contributor_payload AS (
    SELECT *
    FROM (
        VALUES
            ('tinghedy', 'Yating Liang', 'https://github.com/Tinghedy.png?size=256', 'https://github.com/Tinghedy'),
            ('ncchen99', '念誠', 'https://github.com/ncchen99.png?size=256', 'https://github.com/ncchen99'),
            ('ichenjt', 'ichenjt', 'https://github.com/ichenjt.png?size=256', 'https://github.com/ichenjt'),
            ('yenslife', '海狸大師', 'https://github.com/yenslife.png?size=256', 'https://github.com/yenslife')
    ) AS v(user_id, user_name, image, link)
)
UPDATE public.contributors c
SET user_id = p.user_id,
    user_name = p.user_name,
    image = p.image,
    link = p.link,
    include = TRUE,
    updated_at = NOW()
FROM contributor_payload p
WHERE lower(c.user_id) = lower(p.user_id);

WITH contributor_payload AS (
    SELECT *
    FROM (
        VALUES
            ('tinghedy', 'Yating Liang', 'https://github.com/Tinghedy.png?size=256', 'https://github.com/Tinghedy'),
            ('ncchen99', '念誠', 'https://github.com/ncchen99.png?size=256', 'https://github.com/ncchen99'),
            ('ichenjt', 'ichenjt', 'https://github.com/ichenjt.png?size=256', 'https://github.com/ichenjt'),
            ('yenslife', '海狸大師', 'https://github.com/yenslife.png?size=256', 'https://github.com/yenslife')
    ) AS v(user_id, user_name, image, link)
)
INSERT INTO public.contributors (
    user_id,
    user_name,
    image,
    link,
    identity,
    description,
    include,
    created_at,
    updated_at
)
SELECT
    p.user_id,
    p.user_name,
    p.image,
    p.link,
    '淨零生活組件貢獻者',
    NULL,
    TRUE,
    NOW(),
    NOW()
FROM contributor_payload p
WHERE NOT EXISTS (
    SELECT 1
    FROM public.contributors c
    WHERE lower(c.user_id) = lower(p.user_id)
);

-- 2) Rebind the 7 "淨零生活" components to these four contributors.
UPDATE public.query_charts
SET contributors = ARRAY['tinghedy', 'ncchen99', 'ichenjt', 'yenslife']::text[],
    updated_at = NOW()
WHERE city = 'metrotaipei'
  AND index IN (
      'metrotaipei_reusable_cup',
      'metrotaipei_eco_restaurant',
      'metrotaipei_scooter_charging',
      'metrotaipei_drinking_fountain',
      'metrotaipei_used_clothing_box',
      'green_store_distribution',
      'eco_hotel'
  );

COMMIT;
