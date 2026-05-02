#!/usr/bin/env bash
# ============================================================
# 循環杯組件一鍵安裝腳本
# ============================================================
#
# 說明：
#   依序執行以下兩個 SQL 腳本，完成循環杯組件的完整安裝。
#   資料與組件設定分屬不同資料庫，本腳本會自動分開執行。
#
#   Step 1 → add_reusable_cup_data.sql      (目標: dashboard DB)
#            匯入 1770 筆門市點位 + 38 筆各區統計
#
#   Step 2 → add_reusable_cup_component.sql (目標: dashboardmanager DB)
#            設定地圖組件 (component_maps) 與查詢設定 (query_charts)
#
# 前置條件：
#   - Docker 已啟動，且 postgres-data / postgres-manager 容器正在運行
#   - 執行目錄為專案根目錄（Taipei-City-Dashboard/）
#
# 使用方式：
#   cd /path/to/Taipei-City-Dashboard
#   chmod +x db-sample-data/install_reusable_cup.sh
#   bash db-sample-data/install_reusable_cup.sh
#
# ⚠️  不需要執行 data/etl_reusable_cup_stores.py 或 Mapbox API
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DATA_SQL="$SCRIPT_DIR/add_reusable_cup_data.sql"
COMPONENT_SQL="$SCRIPT_DIR/add_reusable_cup_component.sql"

echo ""
echo "======================================================"
echo "  循環杯組件安裝開始"
echo "======================================================"

# ── Step 1: 匯入資料到 dashboard DB ──────────────────────────
echo ""
echo "【Step 1/2】匯入門市資料 → postgres-data (dashboard DB)"
echo "  檔案: add_reusable_cup_data.sql"

docker cp "$DATA_SQL" postgres-data:/tmp/add_reusable_cup_data.sql
docker exec postgres-data psql -U postgres -d dashboard \
  -f /tmp/add_reusable_cup_data.sql

echo "  ✓ Step 1 完成"

# ── Step 2: 設定組件到 dashboardmanager DB ────────────────────
echo ""
echo "【Step 2/2】設定地圖組件 → postgres-manager (dashboardmanager DB)"
echo "  檔案: add_reusable_cup_component.sql"

docker cp "$COMPONENT_SQL" postgres-manager:/tmp/add_reusable_cup_component.sql
docker exec postgres-manager psql -U postgres -d dashboardmanager \
  -f /tmp/add_reusable_cup_component.sql

echo "  ✓ Step 2 完成"

echo ""
echo "======================================================"
echo "  安裝完成！循環杯組件已成功匯入資料庫。"
echo ""
echo "  注意：前端 GeoJSON 請確認已放置於："
echo "    FE/public/mapData/reusable_cup_store_tpe.geojson"
echo "    FE/public/mapData/reusable_cup_store_metrotaipei.geojson"
echo "======================================================"
echo ""
