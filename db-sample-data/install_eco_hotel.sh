#!/usr/bin/env bash
# ============================================================
# 環保旅宿組件一鍵安裝腳本
# ============================================================
#
# 說明：
#   依序執行以下兩個 SQL 腳本，完成環保旅宿組件的完整安裝。
#   Step 1 → add_eco_hotel_data.sql      (目標: dashboard DB)
#   Step 2 → add_eco_hotel_component.sql (目標: dashboardmanager DB)
#
# 使用方式：
#   bash db-sample-data/install_eco_hotel.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DATA_SQL="$SCRIPT_DIR/add_eco_hotel_data.sql"
COMPONENT_SQL="$SCRIPT_DIR/add_eco_hotel_component.sql"

echo ""
echo "======================================================"
echo "  環保旅宿組件安裝開始"
echo "======================================================"

# ── Step 1: 匯入資料到 dashboard DB ──────────────────────────
echo ""
echo "【Step 1/2】匯入旅宿資料 → postgres-data (dashboard DB)"
docker cp "$DATA_SQL" postgres-data:/tmp/add_eco_hotel_data.sql
docker exec postgres-data psql -U postgres -d dashboard -f /tmp/add_eco_hotel_data.sql

# ── Step 2: 設定組件到 dashboardmanager DB ────────────────────
echo ""
echo "【Step 2/2】設定組件 → postgres-manager (dashboardmanager DB)"
docker cp "$COMPONENT_SQL" postgres-manager:/tmp/add_eco_hotel_component.sql
docker exec postgres-manager psql -U postgres -d dashboardmanager -f /tmp/add_eco_hotel_component.sql

echo ""
echo "======================================================"
echo "  安裝完成！環保旅宿組件已成功匯入。"
echo "======================================================"
echo ""
