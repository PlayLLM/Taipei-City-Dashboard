# <img src='Taipei-City-Dashboard-FE/src/assets/images/TUIC.svg' height='28'> Taipei City Dashboard × 雙北程式設計節

## 關於本專案

[Taipei City Dashboard](https://citydashboard.taipei) 是由[台北市資訊局都市智慧中心（TUIC）](https://citydashboard.taipei/documentation/en)開發的城市資料視覺化平台，整合統計與地理空間開放資料，協助政策決策並讓市民即時掌握城市動態。平台程式碼完全開源，任何組織皆可基於此架構建立自己的城市儀表板。

**雙北程式設計節**是專為大台北地區舉辦的程式設計競賽，鼓勵參賽者以開放資料與創新技術解決城市議題。本專案即為本組別在競賽中，於原有儀表板基礎上擴充循環經濟與永續生活主題的成果。

---

## 組別 09

*jenny 零基礎玩轉 LLM 應用全攻略：Hedy × yenslife 實作念誠開發 Vera 超簡單*

### 設計理念

以循環經濟整合雙北永續資訊，帶領居民「前淨綠生活🌱」。

將飲水、循環杯、回收與低碳交通串聯為日常路徑，透過資料可視化與在地指引降低環保行動的門檻。讓市民們在每次選擇中完成小循環，累積成城市的大循環。讓每一次生活選擇，都成為城市的循環。

---

### 特色功能

#### AI 聊天機器人（LLM-based Agent）

實作網站右下角的聊天機器人，該聊天機器人（LLM-based Agent）可使用關鍵字查詢工具，LLM 會自行判斷當前上下文是否需要利用 Qdrant 進行語義相似度查詢，並且輸出成一個可以點擊的按鈕，讓使用者快速移動到目標組件。為提升查詢效果，我們針對檢索到的結果利用 LLM 進行重新排序（rerank）。

#### 小駭探城 — 遊戲化市民參與

實作「小駭探城」分頁，以遊戲化方式使市民都能有感參與，可實際累積並視覺化淨零生活足跡。

---

### 實際畫面

**截圖**

<table>
  <tr>
    <td><img src="demo/01 全部組件1.jpg" alt="全部組件1"></td>
    <td><img src="demo/02 全部組件2.jpg" alt="全部組件2"></td>
  </tr>
  <tr>
    <td><img src="demo/03 組建互動.jpg" alt="組建互動"></td>
    <td><img src="demo/04 地圖位置顯示過濾.jpg" alt="地圖位置顯示過濾"></td>
  </tr>
</table>

**組件互動**

![組件互動](demo/compressed_05%20組件互動.gif)

**組件地圖功能互動**

![組件地圖功能互動](demo/compressed_06%20組件地圖功能互動.gif)

**AI 功能展示**

![AI功能](demo/compressed_07%20AI功能.gif)

**小駭探城遊戲化設計**

![小駭探城遊戲化設計](demo/compressed_08%20小駭探城遊戲化設計.gif)

---

### Contributors

<a href="https://github.com/Tinghedy"><img src="data/contributors/tinghedy.png" width="48" height="48" style="border-radius:50%"></a>
<a href="https://github.com/ncchen99"><img src="data/contributors/ncchen99.png" width="48" height="48" style="border-radius:50%"></a>
<a href="https://github.com/ichenjt"><img src="data/contributors/ichenjt.png" width="48" height="48" style="border-radius:50%"></a>
<a href="https://github.com/yenslife"><img src="data/contributors/yenslife.png" width="48" height="48" style="border-radius:50%"></a>

---

## 開始教學

### 前置需求

- [Docker](https://docs.docker.com/get-docker/)

### 啟動步驟

```bash
cd docker

# 1) 建立外部 network
docker network create --driver=bridge --subnet=192.168.128.0/24 --gateway=192.168.128.1 br_dashboard

# 2) 啟動 DB/Cache/Qdrant
docker compose -f docker-compose-db.yaml up -d

# 3) 初始化前後端依賴與 DB sample data
docker compose -f docker-compose-init.yaml up

# 4) 啟動 Nginx + FE + BE
docker compose -f docker-compose.yaml up -d

# 5) 匯入自訂 dashboard 與 component 資料
node ../scripts/apply_dashboardmanager_consistency_repairs.mjs
```

> 完整重建說明與疑難排解請參考 [db-sample-data/README.md](db-sample-data/README.md)。
