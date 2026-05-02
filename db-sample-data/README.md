# 資料庫初始化與重建注意事項

本目錄的 `dashboardmanager-demo.sql` 與 `dashboard-demo.sql` 是基礎 seed，只會建立原始 demo 資料。後續以 SQL 新增的組件，例如交通分析、循環經濟、資源回收站分布，以及相關 Qdrant 向量索引，不會只靠 `docker-compose-init.yaml` 自動完成。

## 刪除 volume 後的建議重建流程

若刪除 PostgreSQL volume 後要重建到目前開發環境的完整狀態，請依序執行：

```bash

cd docker

# 1) 建立外部 network（compose 檔要求 external network）
docker network create --driver=bridge --subnet=192.168.128.0/24 --gateway=192.168.128.1 br_dashboard

# 2) 啟動 DB/Cache/Qdrant
docker compose -f docker-compose-db.yaml up -d

# 3) 初始化前後端依賴與 DB sample data
docker compose -f docker-compose-init.yaml up

# 4) 啟動 Nginx + FE + BE
docker compose -f docker-compose.yaml up -d
cd ..
node scripts/apply_dashboardmanager_consistency_repairs.mjs
```

最後一支 script 會補上 base seed 以外的資料處理流程：

- 匯入循環杯、資源回收站、環保餐廳、環保旅宿等行政區統計與門市資料。
- 產生資源回收站與循環杯 GeoJSON。
- 建立或修復交通分析、循環經濟、氣候環境相關 dashboard 與 component。
- 清理不應保留在 seed 內的 demo dashboard 與重複 roles。
- 檢查 dashboards、components、query_charts、component_maps 的關聯一致性。
- 重建 Qdrant public collection。

## 為什麼不能只跑 docker-compose-init.yaml

`docker-compose-init.yaml` 只會執行：

- `dashboardmanager-demo.sql`
- `dashboard-demo.sql`

它不會自動執行後來新增的 SQL 檔案，也不會重建 Qdrant。如果只跑 init，可能會出現 sidebar 有 dashboard 或 component，但 `query_charts`、`component_maps` 或 dashboard 資料表沒有同步建立的情況，前端就可能出現 404、500 或內容對不上。

## 重建後檢查

若只想檢查目前 `dashboardmanager` 是否一致，可以執行：

```bash
docker cp db-sample-data/audit_dashboardmanager_integrity.sql postgres-manager:/tmp/audit_dashboardmanager_integrity.sql
docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/audit_dashboardmanager_integrity.sql
```

每個區塊都應回傳 `0 rows`。若有資料，代表 seed 或後續 SQL 流程仍有缺漏。
