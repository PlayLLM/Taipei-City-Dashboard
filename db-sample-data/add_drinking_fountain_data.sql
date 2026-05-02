-- ============================================================
-- 飲水機與直飲臺資料匯入
-- 資料庫: dashboard
-- ============================================================
-- 手動執行前請先把 CSV 複製到 postgres-data 容器：
--   docker cp data/臺北市公共場所飲水機資訊.csv postgres-data:/tmp/drinking_fountain_tpe.csv
--   docker cp data/11503_直飲台基本資料.csv postgres-data:/tmp/drinking_station_metrotaipei.csv
--
-- 手動執行方式：
--   docker cp db-sample-data/add_drinking_fountain_data.sql postgres-data:/tmp/add_drinking_fountain_data.sql
--   docker exec postgres-data psql -U postgres -d dashboard -f /tmp/add_drinking_fountain_data.sql
-- ============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS public.drinking_fountain_sites (
    id text,
    source_type text,
    city text,
    district text,
    name text,
    address text,
    managing_unit text,
    maintenance_unit text,
    phone text,
    open_time text,
    location text,
    status text,
    info_url text,
    photo_url text,
    lng double precision,
    lat double precision,
    wkb_geometry public.geometry(Point,4326)
);

TRUNCATE public.drinking_fountain_sites;

CREATE TEMP TABLE tmp_drinking_fountain_tpe (
    district text,
    place_name text,
    place_address text,
    managing_unit text,
    phone text,
    open_time text,
    unit_count text,
    location text,
    lat text,
    lng text
);

CREATE TEMP TABLE tmp_drinking_station_metrotaipei (
    monthly_check text,
    station_id text,
    branch text,
    city text,
    place_type text,
    place_subtype text,
    owner_unit text,
    place_name text,
    address text,
    district text,
    maintenance_unit text,
    phone text,
    open_time text,
    location text,
    lng text,
    lat text,
    status text,
    status_updated_at text,
    last_sample_at text,
    ecoli_count text,
    info_url text,
    photo_url text
);

COPY tmp_drinking_fountain_tpe
FROM '/tmp/drinking_fountain_tpe.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY tmp_drinking_station_metrotaipei
FROM '/tmp/drinking_station_metrotaipei.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

INSERT INTO public.drinking_fountain_sites (
    id,
    source_type,
    city,
    district,
    name,
    address,
    managing_unit,
    maintenance_unit,
    phone,
    open_time,
    location,
    status,
    info_url,
    photo_url,
    lng,
    lat,
    wkb_geometry
)
SELECT
    'TPE-F-' || row_number() OVER ()::text,
    '飲水機',
    '臺北市',
    CASE
        WHEN right(trim(district), 1) = '區' THEN trim(district)
        ELSE trim(district) || '區'
    END,
    NULLIF(trim(place_name), ''),
    NULLIF(trim(place_address), ''),
    NULLIF(trim(managing_unit), ''),
    NULL,
    NULLIF(trim(phone), ''),
    NULLIF(trim(open_time), ''),
    NULLIF(trim(location), ''),
    NULL,
    NULL,
    NULL,
    NULLIF(trim(lng), '')::double precision,
    NULLIF(trim(lat), '')::double precision,
    CASE
        WHEN NULLIF(trim(lng), '') IS NOT NULL
         AND NULLIF(trim(lat), '') IS NOT NULL
        THEN ST_SetSRID(
            ST_MakePoint(
                NULLIF(trim(lng), '')::double precision,
                NULLIF(trim(lat), '')::double precision
            ),
            4326
        )
    END
FROM tmp_drinking_fountain_tpe
WHERE NULLIF(trim(place_name), '') IS NOT NULL
  AND NULLIF(trim(place_address), '') IS NOT NULL;

INSERT INTO public.drinking_fountain_sites (
    id,
    source_type,
    city,
    district,
    name,
    address,
    managing_unit,
    maintenance_unit,
    phone,
    open_time,
    location,
    status,
    info_url,
    photo_url,
    lng,
    lat,
    wkb_geometry
)
SELECT
    NULLIF(trim(station_id), ''),
    '直飲臺',
    CASE
        WHEN trim(city) IN ('台北市', '臺北市') THEN '臺北市'
        WHEN trim(city) = '新北市' THEN '新北市'
        ELSE NULLIF(trim(city), '')
    END,
    CASE
        WHEN right(trim(district), 1) = '區' THEN trim(district)
        ELSE trim(district) || '區'
    END,
    NULLIF(trim(place_name), ''),
    NULLIF(trim(address), ''),
    NULLIF(trim(owner_unit), ''),
    NULLIF(trim(maintenance_unit), ''),
    NULLIF(trim(phone), ''),
    NULLIF(trim(open_time), ''),
    NULLIF(trim(location), ''),
    NULLIF(trim(status), ''),
    NULLIF(trim(info_url), ''),
    NULLIF(trim(photo_url), ''),
    NULLIF(trim(lng), '')::double precision,
    NULLIF(trim(lat), '')::double precision,
    CASE
        WHEN NULLIF(trim(lng), '') IS NOT NULL
         AND NULLIF(trim(lat), '') IS NOT NULL
        THEN ST_SetSRID(
            ST_MakePoint(
                NULLIF(trim(lng), '')::double precision,
                NULLIF(trim(lat), '')::double precision
            ),
            4326
        )
    END
FROM tmp_drinking_station_metrotaipei
WHERE NULLIF(trim(place_name), '') IS NOT NULL
  AND NULLIF(trim(address), '') IS NOT NULL
  AND trim(city) IN ('台北市', '臺北市', '新北市');

CREATE INDEX IF NOT EXISTS drinking_fountain_sites_district_idx
    ON public.drinking_fountain_sites (district);

CREATE INDEX IF NOT EXISTS drinking_fountain_sites_source_type_idx
    ON public.drinking_fountain_sites (source_type);

COMMIT;
