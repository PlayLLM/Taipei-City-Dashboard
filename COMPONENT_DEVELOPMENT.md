# 組件開發指南

本文檔說明如何在 Taipei City Dashboard 專案中新增組件，包括使用現有組件建立新組件，以及發明全新的組件類型。

---

## 一、使用現有組件建立新組件

### 步驟 1：準備資料

確保你的資料庫中有可用的數據，並編寫 SQL 查詢來獲取這些數據。

**SQL 查詢格式要求：**
- `x_axis`：X 軸數據（類別名稱或數值）
- `y_axis`：Y 軸數據（類別名稱）
- `data`：實際數值

**範例 SQL：**
```sql
SELECT COALESCE(direction, '未知') as x_axis, '總長度' as y_axis, ROUND((SUM(cycling_length)/1000)::numeric, 2) as data 
FROM public.bike_network_tpe 
WHERE city = '台北市' 
GROUP BY direction 
ORDER BY data DESC;
```

### 步驟 2：在資料庫新增組件資料

在 `dashboardmanager` 資料庫中新增組件資料：

```sql
-- 步驟 1：新增組件基本資訊
INSERT INTO public.components (id, index, name)
VALUES (302, 'bike_network_length', '自行車路網長度統計');

-- 步驟 2：新增圖表設定（使用現有圖表類型，如 ColumnChart）
INSERT INTO public.component_charts (index, color, types, unit)
VALUES (
    'bike_network_length',
    ARRAY['#4CAF50', '#8BC34A', '#CDDC39', '#FFEB3B', '#FFC107', '#FF9800'],
    ARRAY['ColumnChart'],
    '公里'
);

-- 步驟 3：新增查詢設定
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
) VALUES (
    'bike_network_length',
    NULL,
    '{}',
    '{}',
    'static',
    NULL,
    0,
    NULL,
    '交通局',
    '顯示臺北市各行政區自行車路網總長度。',
    '此圖表呈現臺北市各行政區的自行車路網總長度。',
    '適用於交通規劃與綠色運輸分析。',
    '{https://data.taipei/dataset/自行車道}',
    '{doit}',
    NOW(),
    NOW(),
    'two_d',
    'SELECT COALESCE(direction, ''未知'') as x_axis, ''總長度'' as y_axis, ROUND((SUM(cycling_length)/1000)::numeric, 2) as data FROM public.bike_network_tpe WHERE city = ''台北市'' GROUP BY direction ORDER BY data DESC',
    NULL,
    'taipei'
);

-- 步驟 4：將組件加入儀表板
UPDATE public.dashboards
SET components = array_append(components, 302)
WHERE index = 'transport-analysis';
```

### 步驟 3：重新整理前端

重新整理前端頁面（`Cmd+Shift+R`），新組件應該會自動出現在指定的儀表板中。

---

## 二、發明一個全新的組件類型

以「氣泡圖（BubbleChart）」為例，說明如何發明一個全新的組件類型。

### 步驟 1：創建 Vue 組件

在 `/Taipei-City-Dashboard-FE/src/dashboardComponent/components/` 目錄下創建新的 Vue 組件檔案。

**檔案名稱：** `BubbleChart.vue`

**關鍵要點：**
- 使用 `vue3-apexcharts` 套件（與專案保持一致）
- 定義正確的 props：`chart_config`, `activeChart`, `series`, `map_config`, `map_filter`, `map_filter_on`
- 定義 emits：`filterByParam`, `filterByLayer`, `clearByParamFilter`, `clearByLayerFilter`, `fly`
- 確保數據格式正確轉換為 ApexCharts 所需格式

**氣泡圖數據格式要求：**
- `x_axis`：X 軸數值
- `y_axis`：Y 軸數值
- `z_axis` 或 `data`：氣泡大小（數值）

**範例代碼：**
```vue
<!-- Developed by Taipei Urban Intelligence Center 2023-2024-->
<script setup>
import { ref } from "vue";
import VueApexCharts from "vue3-apexcharts";

const props = defineProps([
	"chart_config",
	"activeChart",
	"series",
	"map_config",
	"map_filter",
	"map_filter_on",
]);

const emits = defineEmits([
	"filterByParam",
	"filterByLayer",
	"clearByParamFilter",
	"clearByLayerFilter",
	"fly"
]);

// 標準格式：x_axis, y_axis, z_axis（氣泡大小）
const data = props.series[0]?.data || [];

const chartOptions = ref({
	chart: {
		type: "bubble",
		toolbar: { show: false },
		zoom: { enabled: false },
	},
	colors: props.chart_config.color || ["#4CAF50", "#2196F3", "#FF9800"],
	dataLabels: { enabled: false },
	legend: { show: false },
	fill: { opacity: 0.8 },
	xaxis: { title: { text: "X 軸" } },
	yaxis: { title: { text: "Y 軸" } },
	tooltip: {
		enabled: true,
		theme: "dark",
		z: { title: "大小" },
		followCursor: true,
		intersect: true,
	},
	plotOptions: {
		bubble: {
			minBubbleRadius: 5,
			maxBubbleRadius: 50,
		},
	},
});

// 轉換為 ApexCharts bubble chart 格式
const chartSeries = ref([
	{
		data: data.map((item) => ({
			x: parseFloat(item.x_axis || item.x || 0),
			y: parseFloat(item.y_axis || item.y || 0),
			z: parseFloat(item.z_axis || item.data || item.z || 10),
		})),
	},
]);
</script>

<template>
	<div v-if="activeChart === 'BubbleChart'" style="min-height: 250px;">
		<VueApexCharts
			width="100%"
			height="250px"
			type="bubble"
			:options="chartOptions"
			:series="chartSeries"
		/>
	</div>
</template>

<style scoped></style>
```

### 步驟 2：修改 DashboardComponent.vue

在 `/Taipei-City-Dashboard-FE/src/dashboardComponent/DashboardComponent.vue` 中：

1. **導入新組件：**
```javascript
import BubbleChart from "./components/BubbleChart.vue";
```

2. **導入 SVG 預覽圖：**
```javascript
import BubbleChartSvg from "./assets/chart/BubbleChart.svg";
```

3. **在 returnChartComponent 函數中加入 case：**
```javascript
case "BubbleChart":
	return svg ? BubbleChartSvg : BubbleChart;
```

### 步驟 3：修改 chartTypes.js

在 `/Taipei-City-Dashboard-FE/src/assets/configs/apexcharts/chartTypes.js` 中加入新的圖表類型名稱：

```javascript
export const chartTypes = {
	// ... 其他圖表類型
	BubbleChart: "氣泡圖",
};
```

### 步驟 4：創建 SVG 預覽圖

在 `/Taipei-City-Dashboard-FE/src/dashboardComponent/assets/chart/` 目錄下創建 SVG 預覽圖。

**檔案名稱：** `BubbleChart.svg`

**範例 SVG：**
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">
  <rect x="0" y="0" width="40" height="40" fill="#282a2c" rx="5"/>
  <circle cx="12" cy="28" r="4" fill="#4CAF50" opacity="0.8"/>
  <circle cx="20" cy="20" r="6" fill="#2196F3" opacity="0.8"/>
  <circle cx="28" cy="12" r="8" fill="#FF9800" opacity="0.8"/>
</svg>
```

### 步驟 5：在資料庫新增組件資料

參考 `add-bubble-chart.sql` 檔案執行資料庫操作。

### 步驟 6：重新整理前端

重新整理前端頁面（`Cmd+Shift+R`），新組件類型應該會自動出現。

---

## 三、資料庫結構說明

### 組件相關表格

**1. components 表**
- `id`：組件 ID（唯一）
- `index`：組件索引（唯一，用於關聯）
- `name`：組件顯示名稱

**2. component_charts 表**
- `index`：組件索引（與 components.index 關聯）
- `color`：圖表顏色陣列
- `types`：圖表類型陣列（如 `['ColumnChart']`、`['BubbleChart']`）
- `unit`：數值單位

**3. query_charts 表**
- `index`：組件索引（與 components.index 關聯）
- `query_chart`：SQL 查詢語句
- `city`：城市（如 'taipei'）
- `short_desc`：簡短描述
- `long_desc`：詳細描述
- `source`：數據來源
- `query_type`：查詢類型（如 'two_d'）

**4. dashboards 表**
- `index`：儀表板索引
- `components`：組件 ID 陣列

---

## 四、數據格式要求

### 標準格式（通用）
```sql
SELECT x_axis, y_axis, data FROM table_name;
```

### 氣泡圖格式
```sql
SELECT x_axis, y_axis, z_axis FROM table_name;
```

### 注意事項
- 使用 `COALESCE` 處理 NULL 值
- 使用 `ROUND` 處理數值精度
- 確保 SQL 返回的欄位名稱與前端組件期望的一致

---

## 五、調試技巧

### 查看 Console 輸出
在 Vue 組件中添加 `console.log` 來調試數據格式：
```javascript
console.log('series:', props.series);
console.log('data:', data);
```

### 檢查資料庫查詢
在資料庫中直接執行 SQL 查詢，確保返回的數據格式正確：
```bash
docker exec -it postgres-manager psql -U postgres -d dashboardmanager
```

---

## 六、常見問題

### Q1: 組件出現但顯示「無法顯示」
**A:** 檢查 SQL 查詢返回的數據格式是否正確，特別是欄位名稱是否與組件期望的一致。

### Q2: Tooltip 被切到
**A:** 調整 chart 的 padding 或使用 `followCursor: true` 讓 tooltip 跟隨游標。

### Q3: 圖表高度不夠
**A:** 在 template 中設置固定高度，如 `style="min-height: 250px;"`。

---

## 七、參考資源

- ApexCharts 文檔：https://apexcharts.com/docs/
- Vue3 文檔：https://vuejs.org/
- 專案現有組件位於：`/Taipei-City-Dashboard-FE/src/dashboardComponent/components/`
