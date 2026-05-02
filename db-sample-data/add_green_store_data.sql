BEGIN;

DROP TABLE IF EXISTS public.green_store_tpe;
DROP TABLE IF EXISTS public.green_store_new_tpe;

CREATE TABLE public.green_store_tpe (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    district TEXT NOT NULL
);

CREATE TABLE public.green_store_new_tpe (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    district TEXT NOT NULL
);

CREATE TEMP TABLE tmp_green_store_tpe (
    seqno text,
    unused_1 text,
    address text,
    store_no text,
    name text,
    phone text,
    ext text,
    mobile text,
    store_type text,
    unused_2 text,
    unused_3 text,
    unused_4 text,
    category text,
    brand text,
    count_text text
);

CREATE TEMP TABLE tmp_green_store_new_tpe (
    seqno text,
    store_type text,
    city text,
    county_code text,
    name text,
    address text,
    store_no text,
    phone text,
    unused_1 text,
    unused_2 text,
    unused_3 text,
    unused_4 text,
    category text,
    brand text,
    count_text text
);

COPY tmp_green_store_tpe
FROM '/tmp/green_store_tpe.csv'
WITH (FORMAT csv, HEADER true);

COPY tmp_green_store_new_tpe
FROM '/tmp/green_store_new_tpe.csv'
WITH (FORMAT csv, HEADER true);

INSERT INTO public.green_store_tpe (name, district)
SELECT
    trim(name),
    COALESCE(
        NULLIF(trim(substring(address from '臺北市(.{1,3}區)')), ''),
        NULLIF(trim(substring(address from '台北市(.{1,3}區)')), '')
    )
FROM tmp_green_store_tpe
WHERE NULLIF(trim(name), '') IS NOT NULL
  AND COALESCE(
      NULLIF(trim(substring(address from '臺北市(.{1,3}區)')), ''),
      NULLIF(trim(substring(address from '台北市(.{1,3}區)')), '')
  ) IS NOT NULL;

INSERT INTO public.green_store_new_tpe (name, district)
SELECT
    trim(name),
    NULLIF(trim(substring(address from '新北市(.{1,3}區)')), '')
FROM tmp_green_store_new_tpe
WHERE NULLIF(trim(name), '') IS NOT NULL
  AND NULLIF(trim(substring(address from '新北市(.{1,3}區)')), '') IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_green_store_tpe_district
ON public.green_store_tpe (district);

CREATE INDEX IF NOT EXISTS idx_green_store_new_tpe_district
ON public.green_store_new_tpe (district);

COMMIT;
