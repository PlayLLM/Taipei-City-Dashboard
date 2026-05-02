import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const ROOT = process.cwd();
const OUTPUT_DIR = path.join(ROOT, "Taipei-City-Dashboard-FE/public/mapData");

// 從資料庫抓取資料並解析行政區
function getStoresFromDb() {
	const query = `
    SELECT 
        brand, 
        city, 
        store_name, 
        address, 
        phone, 
        lng, 
        lat,
        wkb_geometry,
        CASE 
            WHEN address LIKE '%中正區%' THEN '中正區'
            WHEN address LIKE '%萬華區%' THEN '萬華區'
            WHEN address LIKE '%大同區%' THEN '大同區'
            WHEN address LIKE '%中山區%' THEN '中山區'
            WHEN address LIKE '%松山區%' THEN '松山區'
            WHEN address LIKE '%大安區%' THEN '大安區'
            WHEN address LIKE '%信義區%' THEN '信義區'
            WHEN address LIKE '%內湖區%' THEN '內湖區'
            WHEN address LIKE '%南港區%' THEN '南港區'
            WHEN address LIKE '%士林區%' THEN '士林區'
            WHEN address LIKE '%北投區%' THEN '北投區'
            WHEN address LIKE '%文山區%' THEN '文山區'
            WHEN address LIKE '%板橋區%' THEN '板橋區'
            WHEN address LIKE '%三重區%' THEN '三重區'
            WHEN address LIKE '%中和區%' THEN '中和區'
            WHEN address LIKE '%永和區%' THEN '永和區'
            WHEN address LIKE '%新莊區%' THEN '新莊區'
            WHEN address LIKE '%新店區%' THEN '新店區'
            WHEN address LIKE '%樹林區%' THEN '樹林區'
            WHEN address LIKE '%鶯歌區%' THEN '鶯歌區'
            WHEN address LIKE '%三峽區%' THEN '三峽區'
            WHEN address LIKE '%淡水區%' THEN '淡水區'
            WHEN address LIKE '%汐止區%' THEN '汐止區'
            WHEN address LIKE '%瑞芳區%' THEN '瑞芳區'
            WHEN address LIKE '%土城區%' THEN '土城區'
            WHEN address LIKE '%蘆洲區%' THEN '蘆洲區'
            WHEN address LIKE '%五股區%' THEN '五股區'
            WHEN address LIKE '%泰山區%' THEN '泰山區'
            WHEN address LIKE '%林口區%' THEN '林口區'
            WHEN address LIKE '%深坑區%' THEN '深坑區'
            WHEN address LIKE '%石碇區%' THEN '石碇區'
            WHEN address LIKE '%坪林區%' THEN '坪林區'
            WHEN address LIKE '%三芝區%' THEN '三芝區'
            WHEN address LIKE '%石門區%' THEN '石門區'
            WHEN address LIKE '%八里區%' THEN '八里區'
            WHEN address LIKE '%平溪區%' THEN '平溪區'
            WHEN address LIKE '%雙溪區%' THEN '雙溪區'
            WHEN address LIKE '%貢寮區%' THEN '貢寮區'
            WHEN address LIKE '%金山區%' THEN '金山區'
            WHEN address LIKE '%萬里區%' THEN '萬里區'
            WHEN address LIKE '%烏來區%' THEN '烏來區'
            WHEN address LIKE '%信義路五段%' THEN '信義區'
            WHEN address LIKE '%復興南路一段%' THEN '大安區'
            ELSE 'Unknown'
        END as district
        FROM public.reusable_cup_stores
  `;

	const output = execFileSync(
		"docker",
		[
			"exec",
			"postgres-data",
			"psql",
			"-U",
			"postgres",
			"-d",
			"dashboard",
			"-t",
			"-c",
			`SELECT json_build_object('type', 'FeatureCollection', 'features', json_agg(ST_AsGeoJSON(t.*)::json)) FROM (${query}) t;`,
		],
		{ encoding: "utf8" },
	);

	return JSON.parse(output.trim());
}

function main() {
	console.log("正在從資料庫讀取循環杯門市資料並產生成 GeoJSON...");
	try {
		const geojson = getStoresFromDb();
		const features = geojson.features || [];

		// 雙北版本
		const metroPath = path.join(OUTPUT_DIR, "reusable_cup_store_metrotaipei.geojson");
		fs.writeFileSync(metroPath, JSON.stringify(geojson, null, 2));
		console.log(`  reusable_cup_store_metrotaipei.geojson: ${features.length} 筆`);

		// 台北版本
		const tpeGeojson = {
			type: "FeatureCollection",
			features: features.filter((f) => f.properties.city === "臺北市"),
		};
		const tpePath = path.join(OUTPUT_DIR, "reusable_cup_store_tpe.geojson");
		fs.writeFileSync(tpePath, JSON.stringify(tpeGeojson, null, 2));
		console.log(`  reusable_cup_store_tpe.geojson: ${tpeGeojson.features.length} 筆`);

		console.log("GeoJSON 產生成完成。");
	} catch (error) {
		console.error("產生成 GeoJSON 失敗:", error.message);
		process.exit(1);
	}
}

main();
