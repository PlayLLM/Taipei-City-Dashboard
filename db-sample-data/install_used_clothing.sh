#!/bin/bash

# ============================================================
# 舊衣回收箱功能安裝腳本
# ============================================================

echo "正在匯入舊衣回收箱資料..."
docker exec -i postgres-dashboard psql -U postgres -d dashboard < db-sample-data/add_used_clothing_box_data.sql

echo "正在更新組件配置..."
docker exec -i postgres-manager psql -U postgres -d dashboardmanager < db-sample-data/add_used_clothing_box_component.sql

echo "安裝完成！"
echo "GeoJSON 已放置於: Taipei-City-Dashboard-FE/public/mapData/used_clothing_boxes.geojson"
echo "SVG 圖標已放置於: Taipei-City-Dashboard-FE/public/icons/shirt.svg"
