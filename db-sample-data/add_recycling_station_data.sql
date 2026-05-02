-- 匯入「臺北市／新北市資源回收站資訊」到 dashboard 資料庫。
-- 執行前請先把 CSV 複製到 postgres-data 容器：
--   docker cp data/臺北市資源回收站資訊.csv postgres-data:/tmp/recycling_station_tpe.csv
--   docker cp data/新北市資源回收站資訊.csv postgres-data:/tmp/recycling_station_new_tpe.csv
--
-- 執行方式：
--   docker cp db-sample-data/add_recycling_station_data.sql postgres-data:/tmp/add_recycling_station_data.sql
--   docker exec postgres-data psql -U postgres -d dashboard -f /tmp/add_recycling_station_data.sql
--
-- 注意：此 CSV 目前只使用「地址」與「行政區」。長條圖可直接運作。
-- 若要顯示地圖點位，仍需另外將地址 geocode 成經緯度，或產生對應 GeoJSON／GeoServer 圖層。

BEGIN;

DROP TABLE IF EXISTS public.recycling_station_tpe;
DROP TABLE IF EXISTS public.recycling_station_new_tpe;

CREATE TABLE public.recycling_station_tpe (
    id integer,
    district text NOT NULL,
    address text NOT NULL
);

CREATE TABLE public.recycling_station_new_tpe (
    id integer,
    district text NOT NULL,
    address text NOT NULL
);

CREATE TEMP TABLE tmp_recycling_station_tpe (
    id integer,
    station_name text,
    district text,
    district_code text,
    address text
);

CREATE TEMP TABLE tmp_recycling_station_new_tpe (
    seqno integer,
    district text,
    village text,
    no text,
    name text,
    address text,
    tel_localcallservice text,
    extension text,
    mobiletelephone text,
    recycle_address text,
    open_time text,
    state text
);

COPY tmp_recycling_station_tpe
FROM '/tmp/recycling_station_tpe.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'BIG5');

COPY tmp_recycling_station_new_tpe
FROM '/tmp/recycling_station_new_tpe.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

INSERT INTO public.recycling_station_tpe (id, district, address)
SELECT
    id,
    trim(district),
    trim(address)
FROM tmp_recycling_station_tpe
WHERE NULLIF(trim(district), '') IS NOT NULL
  AND NULLIF(trim(address), '') IS NOT NULL;

INSERT INTO public.recycling_station_new_tpe (id, district, address)
SELECT
    seqno,
    trim(district),
    trim(COALESCE(NULLIF(recycle_address, ''), address))
FROM tmp_recycling_station_new_tpe
WHERE NULLIF(trim(district), '') IS NOT NULL
  AND NULLIF(trim(COALESCE(NULLIF(recycle_address, ''), address)), '') IS NOT NULL;

CREATE INDEX IF NOT EXISTS recycling_station_tpe_district_idx
    ON public.recycling_station_tpe (district);

CREATE INDEX IF NOT EXISTS recycling_station_new_tpe_district_idx
    ON public.recycling_station_new_tpe (district);

COMMIT;
