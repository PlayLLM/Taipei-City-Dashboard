import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const ROOT = process.cwd();
const OUTPUT_DIR = path.join(ROOT, "Taipei-City-Dashboard-FE/public/mapData");

// 從資料庫抓取舊衣回收箱資料
function getStoresFromDb() {
	const query = `
    SELECT 
        id, 
        city, 
        district, 
        address, 
        org, 
        lng, 
        lat
    FROM public.used_clothing_box_stores
    WHERE lng IS NOT NULL AND lat IS NOT NULL
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
			`SELECT json_build_object('type', 'FeatureCollection', 'features', json_agg(json_build_object(
                'type', 'Feature',
                'geometry', json_build_object('type', 'Point', 'coordinates', json_build_array(lng, lat)),
                'properties', json_build_object('id', id, 'city', city, 'district', district, 'address', address, 'org', org)
            ))) FROM (${query}) t;`,
		],
		{ encoding: "utf8" },
	);

	return JSON.parse(output.trim());
}

function main() {
	console.log("正在從資料庫讀取舊衣回收箱資料並產生成 GeoJSON...");
	try {
		const geojson = getStoresFromDb();
		const features = geojson.features || [];

		const metroPath = path.join(OUTPUT_DIR, "used_clothing_boxes.geojson");
		fs.writeFileSync(metroPath, JSON.stringify(geojson, null, 2));
		console.log(`  used_clothing_boxes.geojson: ${features.length} 筆`);

		console.log("GeoJSON 產生完成。");
	} catch (error) {
		console.error("產生成 GeoJSON 失敗:", error.message);
		process.exit(1);
	}
}

main();
