-- ============================================================
-- 環保旅宿組件配置
-- 資料庫: dashboardmanager (組件設定)  /  dashboard (資料表)
-- ============================================================
--
-- 前置條件：
--   1. 已將 GeoJSON 放置於前端目錄：
--      Taipei-City-Dashboard-FE/public/mapData/eco_hotel_tpe.geojson         (臺北市 34 間)
--      Taipei-City-Dashboard-FE/public/mapData/eco_hotel_metrotaipei.geojson (雙北 53 間)
--
-- 執行方式（dashboardmanager DB）：
--   docker cp db-sample-data/add_eco_hotel_component.sql postgres-manager:/tmp/
--   docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_eco_hotel_component.sql
--
-- 執行方式（dashboard DB，建立資料表並匯入資料）：
--   docker cp db-sample-data/add_eco_hotel_component.sql postgres-db:/tmp/
--   docker exec postgres-db psql -U postgres -d dashboard -f /tmp/add_eco_hotel_component.sql
--
-- 顏色說明：
--   金級 #F5C518  銀級 #ABABAB  銅級 #CD7F32
-- ============================================================


-- ===========================================================
-- PART A：dashboard DB — 建立資料表並匯入雙北環保旅宿資料
-- ===========================================================
-- （若只更新 dashboardmanager 組件設定，可跳過此段）

CREATE TABLE IF NOT EXISTS public.eco_hotel_metrotaipei (
    name     text NOT NULL,
    address  text,
    phone    text,
    grade    text NOT NULL,   -- 金級 / 銀級 / 銅級
    city     text NOT NULL,   -- 臺北市 / 新北市
    district text NOT NULL,
    _ctime   timestamptz DEFAULT CURRENT_TIMESTAMP,
    _mtime   timestamptz DEFAULT CURRENT_TIMESTAMP
);

TRUNCATE TABLE public.eco_hotel_metrotaipei;

INSERT INTO public.eco_hotel_metrotaipei (name, address, phone, grade, city, district) VALUES
('台北六福萬怡酒店','臺北市南港區忠孝東路七段359號7至30樓','(02)66156565#5000','銀級','臺北市','南港區'),
('台北艾麗酒店','臺北市信義區松高路18號','(02)66318031','金級','臺北市','信義區'),
('捷絲旅臺大尊賢館','臺北市大安區羅斯福路四段83號1-10樓','(02)77355088','銀級','臺北市','大安區'),
('板橋凱撒大飯店','新北市板橋區縣民大道二段8號','(02)29583000#7701','金級','新北市','板橋區'),
('陽明山天籟渡假酒店','新北市金山區名流路1之6號','(02)24080400#1700','銀級','新北市','金山區'),
('神隱國度民宿','新北市瑞芳區崙頂路90號','(09)05788650','銅級','新北市','瑞芳區'),
('海霞您的家','新北市貢寮區仁里里14鄰仁愛路38號','(09)35204895','銅級','新北市','貢寮區'),
('旅行邦尼','新北市淡水區中山路87巷7號','(09)28824850','銅級','新北市','淡水區'),
('海灣假日酒店','新北市深坑區北深路3段265號','(02)77035880','銀級','新北市','深坑區'),
('八里福朋喜來登酒店','新北市八里區觀海大道8號','(02)26192777#2602','銀級','新北市','八里區'),
('薆悅酒店野柳渡假館一館','新北市萬里區野柳里港東路162號之2','(02)77035770#623','銅級','新北市','萬里區'),
('台北旅人國際青年旅館','新北市淡水區三民街22號','(02)26258222','銅級','新北市','淡水區'),
('台北萬豪酒店','臺北市中山區樂群二路199號','(02)21757999#1701','銀級','臺北市','中山區'),
('南港老爺行旅','臺北市南港區經貿二路196號','(02)77500588','銀級','臺北市','南港區'),
('美侖商旅','臺北市中山區吉林路49號1至8樓','(02)25313535#878','銀級','臺北市','中山區'),
('福容大飯店 淡水漁人碼頭','新北市淡水區觀海路83號','(02)28059958#8178','金級','新北市','淡水區'),
('台北中山雅樂軒酒店','臺北市中山區雙城街1號','(02)77439900','銀級','臺北市','中山區'),
('福華大飯店','臺北市大安區仁愛路三段160號','(02)27002323#2411','銀級','臺北市','大安區'),
('台北西門町意舍酒店','臺北市萬華區武昌街2段77號5樓至10樓','(02)23755111#2100','銀級','臺北市','萬華區'),
('長榮桂冠酒店(台北)','臺北市中山區松江路63號','(02)25019988#2701','金級','臺北市','中山區'),
('捷絲旅台北三重館','新北市三重區三和路四段107-1號','(02)22806111#8304','銀級','新北市','三重區'),
('台北君品大酒店','臺北市大同區承德路1段3號','(02)21819999#3142','金級','臺北市','大同區'),
('亞昕福朋喜來登酒店','新北市林口區文化三路一段1號','(02)77276961','銀級','新北市','林口區'),
('台北中山意舍酒店','臺北市中山區中山北路二段57之1號1至8樓','(02)25652828','銀級','臺北市','中山區'),
('台北時代寓所','臺北市中正區林森南路7號1至14樓','(02)77521801','金級','臺北市','中正區'),
('圓山大飯店','臺北市中山區中山北路4段1巷1號','(02)28861818#1007','銀級','臺北市','中山區'),
('台北W飯店','臺北市信義區忠孝東路五段10號','(02)77038765','銀級','臺北市','信義區'),
('寒居酒店','臺北市中山區松江路116號1樓至9樓','(02)66008000#8886','金級','臺北市','中山區'),
('台北士林萬麗酒店','臺北市士林區中山北路五段470巷8號','(02)88612389','銀級','臺北市','士林區'),
('台北中山九昱希爾頓逸林酒店','臺北市中山區中山北路一段121巷1之1號','(02)66253281','銅級','臺北市','中山區'),
('北投麗禧溫泉酒店','臺北市北投區幽雅路30號','(02)28967799#738','金級','臺北市','北投區'),
('趣淘漫旅-台北','新北市板橋區中山路1段139號','(02)29583000#7701','金級','新北市','板橋區'),
('台北新板希爾頓酒店','新北市板橋區民權路88號','(02)29583000#7702','金級','新北市','板橋區'),
('富信大飯店','新北市汐止區大同路一段152號','(02)26416422#5112','金級','新北市','汐止區'),
('北投老爺酒店','臺北市北投區中和街2號','(02)28966966#8878','金級','臺北市','北投區'),
('福容大飯店 台北二館','新北市深坑區北深路三段236號','(02)26620088#186','金級','新北市','深坑區'),
('台北遠東香格里拉','臺北市大安區敦化南路二段201號','(02)23788888#6608','銅級','臺北市','大安區'),
('九昱晴美','臺北市中山區林森北路568號2樓至13樓','(02)66080807#105','銅級','臺北市','中山區'),
('福華國際文教會館','臺北市大安區新生南路3段30號','(02)77122323#2340','銀級','臺北市','大安區'),
('台北松山意舍酒店','臺北市南港區市民大道7段8號17樓至21樓','(02)26532828#2100','銀級','臺北市','南港區'),
('老爺大酒店','臺北市中山區中山北路2段37-1號','(02)25423299#359','銅級','臺北市','中山區'),
('凱達大飯店','臺北市萬華區艋舺大道167號1-26樓','(02)23836789#6321','金級','臺北市','萬華區'),
('捷絲旅西門町店','臺北市中正區中華路一段41號5樓至9樓','(02)25215000','銅級','臺北市','中正區'),
('將捷金鬱金香酒店','新北市淡水區中正路1段2之1號','(02)26218555#2913','金級','新北市','淡水區'),
('天成大飯店','臺北市中正區忠孝西路一段43號','(02)23118905#3705','銀級','臺北市','中正區'),
('台糖台北會館','臺北市中正區中華路一段39號3至5樓','(02)23885522#5001','銅級','臺北市','中正區'),
('福容大飯店　福隆','新北市貢寮區福隆里福隆街41號','(02)24992381','金級','新北市','貢寮區'),
('凱旋酒店','臺北市內湖區江南街55號3樓至9樓','(02)87527888#6203','銀級','臺北市','內湖區'),
('台北北投麗禧溫泉酒店','臺北市北投區幽雅路30號','(02)28967799','銀級','臺北市','北投區'),
('義大皇家酒店','新北市三重區重新路五段609巷12號','(02)29883131','銅級','新北市','三重區'),
('西華大飯店','臺北市中正區中山北路一段111號','(02)21007111','銅級','臺北市','中正區'),
('台北老爺行旅','臺北市大安區仁愛路一段1號','(02)23218000','銀級','臺北市','大安區'),
('礁溪長榮鳳凰酒店','新北市汐止區大同路一段152號','(02)26416422','銅級','新北市','汐止區'),
('諾富特台北桃園機場酒店','新北市林口區文化三路一段139號','(02)27515101','銅級','新北市','林口區');


-- ===========================================================
-- PART B：dashboardmanager DB — 組件設定
-- ===========================================================

BEGIN;

-- ① component_charts
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'eco_hotel',
    ARRAY['#F5C518', '#ABABAB', '#CD7F32'],
    ARRAY['ColumnChart', 'MapLegend'],
    '間'
)
ON CONFLICT (index) DO UPDATE
SET color = EXCLUDED.color,
    types = EXCLUDED.types,
    unit  = EXCLUDED.unit;

-- ② component_maps：臺北市圖層
INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES (
    300,
    'eco_hotel_tpe',
    '臺北市環保旅宿',
    'circle',
    'geojson',
    'big',
    NULL,
    '{
        "circle-color": ["match", ["get", "grade"],
            "金級", "#F5C518",
            "銀級", "#ABABAB",
            "銅級", "#CD7F32",
            "#4CAF50"
        ],
        "circle-opacity": 0.9,
        "circle-stroke-color": "#ffffff",
        "circle-stroke-width": 1.2
    }'::json,
    '[
        {"key": "name",     "name": "旅館名稱"},
        {"key": "grade",    "name": "環保等級"},
        {"key": "address",  "name": "地址"},
        {"key": "phone",    "name": "電話"},
        {"key": "district", "name": "行政區"}
    ]'::json
)
ON CONFLICT (id) DO UPDATE
SET index    = EXCLUDED.index,
    title    = EXCLUDED.title,
    type     = EXCLUDED.type,
    source   = EXCLUDED.source,
    size     = EXCLUDED.size,
    paint    = EXCLUDED.paint,
    property = EXCLUDED.property;

-- ③ component_maps：雙北圖層
INSERT INTO public.component_maps (id, index, title, type, source, size, icon, paint, property)
VALUES (
    301,
    'eco_hotel_metrotaipei',
    '雙北環保旅宿',
    'circle',
    'geojson',
    'big',
    NULL,
    '{
        "circle-color": ["match", ["get", "grade"],
            "金級", "#F5C518",
            "銀級", "#ABABAB",
            "銅級", "#CD7F32",
            "#4CAF50"
        ],
        "circle-opacity": 0.9,
        "circle-stroke-color": "#ffffff",
        "circle-stroke-width": 1.2
    }'::json,
    '[
        {"key": "name",     "name": "旅館名稱"},
        {"key": "grade",    "name": "環保等級"},
        {"key": "address",  "name": "地址"},
        {"key": "phone",    "name": "電話"},
        {"key": "city",     "name": "城市"},
        {"key": "district", "name": "行政區"}
    ]'::json
)
ON CONFLICT (id) DO UPDATE
SET index    = EXCLUDED.index,
    title    = EXCLUDED.title,
    type     = EXCLUDED.type,
    source   = EXCLUDED.source,
    size     = EXCLUDED.size,
    paint    = EXCLUDED.paint,
    property = EXCLUDED.property;

-- ④ components
INSERT INTO public.components (id, index, name)
VALUES (500, 'eco_hotel', '環保旅宿')
ON CONFLICT (id) DO UPDATE
SET index = EXCLUDED.index,
    name  = EXCLUDED.name;

-- ⑤ query_charts（刪除舊設定再重新插入）
DELETE FROM public.query_charts
WHERE index = 'eco_hotel'
  AND city IN ('taipei', 'metrotaipei');

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
)
VALUES
-- 臺北市版本（34 間）
(
    'eco_hotel',
    NULL,
    '{300}',
    '{"mode":"byParam","byParam":{"xParam":"grade"}}'::json,
    'static',
    NULL,
    0,
    NULL,
    '環境部',
    '顯示臺北市各行政區環保標章旅宿數量及等級分布。',
    '此圖表彙整臺北市取得環境部環保標章的旅宿資料，依行政區與環保等級（金級、銀級、銅級）統計各區旅宿數量，並在地圖上以顏色標示旅宿位置與等級。金級代表最高環保標準，銀級次之，銅級為基礎環保認證。',
    '可用於了解臺北市各行政區環保旅宿的分布情形與等級結構，作為綠色旅遊選擇、環保政策推動及觀光資源規劃的參考依據。點選地圖上的旅宿圖示可查看詳細資訊，點選圖例可篩選特定等級。',
    '{https://ecolife.epa.gov.tw/}',
    '{doit}',
    NOW(),
    NOW(),
    'three_d',
    'SELECT district AS x_axis, grade AS y_axis, COUNT(*)::int AS data
     FROM public.eco_hotel_metrotaipei
     WHERE city = ''臺北市''
     GROUP BY district, grade
     ORDER BY district, grade',
    NULL,
    'taipei'
),
-- 雙北版本（53 間）
(
    'eco_hotel',
    NULL,
    '{301}',
    '{"mode":"byParam","byParam":{"xParam":"grade"}}'::json,
    'static',
    NULL,
    0,
    NULL,
    '環境部',
    '顯示雙北各行政區環保標章旅宿數量及等級分布。',
    '此圖表彙整臺北市與新北市取得環境部環保標章的旅宿資料，依行政區與環保等級（金級、銀級、銅級）統計各區旅宿數量，並在地圖上以顏色標示旅宿位置與等級。金級代表最高環保標準，銀級次之，銅級為基礎環保認證。',
    '可用於比較雙北各行政區環保旅宿的分布情形與等級結構，作為綠色旅遊選擇、環保政策推動及跨市觀光資源規劃的參考依據。點選地圖上的旅宿圖示可查看詳細資訊，點選圖例可篩選特定等級。',
    '{https://ecolife.epa.gov.tw/}',
    '{doit,ntpc}',
    NOW(),
    NOW(),
    'three_d',
    'SELECT district AS x_axis, grade AS y_axis, COUNT(*)::int AS data
     FROM public.eco_hotel_metrotaipei
     GROUP BY district, grade
     ORDER BY district, grade',
    NULL,
    'metrotaipei'
);

-- ⑥ 將組件加入「循環經濟」儀表板
-- TODO: 請將下方 WHERE index = '...' 改為實際的循環經濟儀表板 index。
-- 若尚未建立循環經濟儀表板，可先用以下指令建立：
--   INSERT INTO public.dashboards (index, name, components, icon, updated_at, created_at)
--   VALUES ('circular-economy', '循環經濟', '{500}', 'recycling', NOW(), NOW());
--
-- 若儀表板已存在，請更新如下：
UPDATE public.dashboards
SET components = array_append(components, 500),
    updated_at = NOW()
WHERE index IN ('circular-economy', 'circular', 'business-revitalize', '商圈活化')
  AND NOT 500 = ANY(COALESCE(components, '{}'));

COMMIT;
