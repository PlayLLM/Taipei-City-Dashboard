-- ============================================================
-- 機車充電站資料匯入
-- 資料庫: dashboard
-- ============================================================
--
-- 手動執行前請先把 CSV 複製到 postgres-data 容器：
--   docker cp data/臺北市營利電動機車充電站-12站.csv postgres-data:/tmp/scooter_charging_tpe.csv
--   docker cp data/新北市電動機車充電站_export.csv postgres-data:/tmp/scooter_charging_new_tpe.csv
--
-- 手動執行方式：
--   docker cp db-sample-data/add_scooter_charging_data.sql postgres-data:/tmp/add_scooter_charging_data.sql
--   docker exec postgres-data psql -U postgres -d dashboard -f /tmp/add_scooter_charging_data.sql
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.scooter_charging_station_sites (
    id text,
    operator text,
    name text,
    address text,
    city text,
    district text,
    station_type text,
    operational_status text,
    fee_applicable text,
    open_to_public text,
    plug_type text,
    connector_count integer
);

CREATE TABLE IF NOT EXISTS public.scooter_charging_station_stats (
    district text,
    count integer,
    city text
);

TRUNCATE public.scooter_charging_station_sites;
TRUNCATE public.scooter_charging_station_stats;

CREATE TEMP TABLE tmp_scooter_charging_tpe (
    seqno text,
    operator text,
    name text,
    address text,
    city text,
    city_code text
);

CREATE TEMP TABLE tmp_scooter_charging_new_tpe (
    administrative_district text,
    charging_station_name text,
    location_address text,
    station_type text,
    operational_status text,
    fee_applicable text,
    open_to_public text,
    plug_type text,
    connector_count text
);

COPY tmp_scooter_charging_tpe
FROM '/tmp/scooter_charging_tpe.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY tmp_scooter_charging_new_tpe
FROM '/tmp/scooter_charging_new_tpe.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

INSERT INTO public.scooter_charging_station_sites (
    id,
    operator,
    name,
    address,
    city,
    district,
    station_type,
    operational_status,
    fee_applicable,
    open_to_public,
    plug_type,
    connector_count
)
SELECT
    CASE
        WHEN NULLIF(trim(seqno), '') IS NOT NULL THEN 'TPE-' || trim(seqno)
        ELSE NULL
    END,
    NULLIF(trim(operator), ''),
    NULLIF(trim(name), ''),
    NULLIF(trim(address), ''),
    '臺北市',
    COALESCE(
        NULLIF(trim(substring(address from '臺北市(.{1,3}區)')), ''),
        NULLIF(trim(substring(address from '台北市(.{1,3}區)')), '')
    ),
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
FROM tmp_scooter_charging_tpe
WHERE NULLIF(trim(address), '') IS NOT NULL;

INSERT INTO public.scooter_charging_station_sites (
    id,
    operator,
    name,
    address,
    city,
    district,
    station_type,
    operational_status,
    fee_applicable,
    open_to_public,
    plug_type,
    connector_count
)
SELECT
    'NTPC-' || row_number() OVER ()::text,
    NULL,
    NULLIF(trim(charging_station_name), ''),
    NULLIF(trim(location_address), ''),
    '新北市',
    NULLIF(trim(administrative_district), ''),
    NULLIF(trim(station_type), ''),
    NULLIF(trim(operational_status), ''),
    NULLIF(trim(fee_applicable), ''),
    NULLIF(trim(open_to_public), ''),
    NULLIF(trim(plug_type), ''),
    NULLIF(regexp_replace(connector_count, '\\D', '', 'g'), '')::int
FROM tmp_scooter_charging_new_tpe
WHERE NULLIF(trim(administrative_district), '') IS NOT NULL
  AND NULLIF(trim(location_address), '') IS NOT NULL;

INSERT INTO public.scooter_charging_station_stats (district, count, city)
SELECT district, COUNT(*)::int, city
FROM public.scooter_charging_station_sites
WHERE NULLIF(district, '') IS NOT NULL
GROUP BY city, district
ORDER BY city, district;

CREATE INDEX IF NOT EXISTS scooter_charging_station_sites_district_idx
    ON public.scooter_charging_station_sites (district);

COMMIT;
