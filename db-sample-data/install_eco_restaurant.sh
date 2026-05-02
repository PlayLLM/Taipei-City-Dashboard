#!/usr/bin/env bash
# ============================================================
# 環保餐廳組件一鍵安裝腳本
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DATA_SQL="$SCRIPT_DIR/add_eco_restaurant_data.sql"
COMPONENT_SQL="$SCRIPT_DIR/add_eco_restaurant_component.sql"

echo ""
echo "======================================================"
echo "  環保餐廳組件安裝開始"
echo "======================================================"

# ── Step 1: 匯入資料到 dashboard DB ──────────────────────────
echo ""
echo "【Step 1/2】匯入餐廳資料 → postgres-data (dashboard DB)"
echo "  檔案: add_eco_restaurant_data.sql"

docker cp "$DATA_SQL" postgres-data:/tmp/add_eco_restaurant_data.sql
docker exec postgres-data psql -U postgres -d dashboard \
  -f /tmp/add_eco_restaurant_data.sql

echo "  ✓ Step 1 完成"

# ── Step 2: 設定組件到 dashboardmanager DB ────────────────────
echo ""
echo "【Step 2/2】設定地圖組件 → postgres-manager (dashboardmanager DB)"
echo "  檔案: add_eco_restaurant_component.sql"

docker cp "$COMPONENT_SQL" postgres-manager:/tmp/add_eco_restaurant_component.sql
docker exec postgres-manager psql -U postgres -d dashboardmanager \
  -f /tmp/add_eco_restaurant_component.sql

echo "  ✓ Step 2 完成"

echo ""
echo "======================================================"
echo "  安裝完成！環保餐廳組件已成功匯入資料庫。"
echo ""
echo "  注意：前端 GeoJSON 已生成於："
echo "    Taipei-City-Dashboard-FE/public/mapData/eco_restaurant_metrotaipei.geojson"
echo "======================================================"
echo ""
