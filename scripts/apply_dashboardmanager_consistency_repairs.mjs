#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import process from "node:process";

// 套用可重建的 dashboardmanager 修復流程，並在最後執行一致性 audit。
// 不會執行 dashboardmanager-demo.sql；請在初始化 DB 後或既有環境中執行。
// 刪除 PostgreSQL volume 後，請先依序啟動 docker-compose-db.yaml、
// docker-compose-init.yaml、docker-compose.yaml，再從 repo root 執行本腳本。
// 詳細說明請見 db-sample-data/README.md。

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const config = {
	dataContainer: process.env.DATA_CONTAINER || "postgres-data",
	managerContainer: process.env.MANAGER_CONTAINER || "postgres-manager",
	qdrantRebuildContainer:
		process.env.QDRANT_REBUILD_CONTAINER || "vector-db-upgrade",
	dashboardDb: process.env.DASHBOARD_DB || "dashboard",
	managerDb: process.env.MANAGER_DB || "dashboardmanager",
	postgresUser: process.env.POSTGRES_USER || "postgres",
};

function run(command, args) {
	execFileSync(command, args, {
		cwd: rootDir,
		stdio: "inherit",
	});
}

function dockerCp(localPath, container, remotePath) {
	run("docker", ["cp", localPath, `${container}:${remotePath}`]);
}

function psql(container, database, filePath) {
	run("docker", [
		"exec",
		container,
		"psql",
		"-U",
		config.postgresUser,
		"-d",
		database,
		"-f",
		filePath,
	]);
}

function containerExists(containerName) {
	const output = execFileSync("docker", ["ps", "-a", "--format", "{{.Names}}"], {
		cwd: rootDir,
		encoding: "utf8",
	});
	return output
		.split("\n")
		.map((name) => name.trim())
		.includes(containerName);
}

console.log("複製 dashboard 資料 SQL 與 CSV...");
dockerCp("data/taipei_cup_count.csv", config.dataContainer, "/tmp/taipei_cup_count.csv");
dockerCp(
	"data/new_taipei_cup_count.csv",
	config.dataContainer,
	"/tmp/new_taipei_cup_count.csv",
);
dockerCp(
	"data/臺北市營利電動機車充電站-12站.csv",
	config.dataContainer,
	"/tmp/scooter_charging_tpe.csv",
);
dockerCp(
	"data/新北市電動機車充電站_export.csv",
	config.dataContainer,
	"/tmp/scooter_charging_new_tpe.csv",
);
dockerCp(
	"data/臺北市資源回收站資訊.csv",
	config.dataContainer,
	"/tmp/recycling_station_tpe.csv",
);
dockerCp(
	"data/新北市資源回收站資訊.csv",
	config.dataContainer,
	"/tmp/recycling_station_new_tpe.csv",
);
dockerCp(
	"db-sample-data/add_reusable_cup_data.sql",
	config.dataContainer,
	"/tmp/add_reusable_cup_data.sql",
);
dockerCp(
	"db-sample-data/add_recycling_station_data.sql",
	config.dataContainer,
	"/tmp/add_recycling_station_data.sql",
);
dockerCp(
	"db-sample-data/add_eco_hotel_data.sql",
	config.dataContainer,
	"/tmp/add_eco_hotel_data.sql",
);
dockerCp(
	"db-sample-data/add_eco_restaurant_data.sql",
	config.dataContainer,
	"/tmp/add_eco_restaurant_data.sql",
);
dockerCp(
	"db-sample-data/add_scooter_charging_data.sql",
	config.dataContainer,
	"/tmp/add_scooter_charging_data.sql",
);
dockerCp(
	"db-sample-data/add_used_clothing_box_data.sql",
	config.dataContainer,
	"/tmp/add_used_clothing_box_data.sql",
);
dockerCp(
	"data/臺北市公共場所飲水機資訊.csv",
	config.dataContainer,
	"/tmp/drinking_fountain_tpe.csv",
);
dockerCp(
	"data/11503_直飲台基本資料.csv",
	config.dataContainer,
	"/tmp/drinking_station_metrotaipei.csv",
);
dockerCp(
	"db-sample-data/add_drinking_fountain_data.sql",
	config.dataContainer,
	"/tmp/add_drinking_fountain_data.sql",
);

console.log("匯入 dashboard 資料表...");
psql(config.dataContainer, config.dashboardDb, "/tmp/add_reusable_cup_data.sql");
psql(config.dataContainer, config.dashboardDb, "/tmp/add_recycling_station_data.sql");
psql(config.dataContainer, config.dashboardDb, "/tmp/add_eco_hotel_data.sql");
psql(config.dataContainer, config.dashboardDb, "/tmp/add_eco_restaurant_data.sql");
psql(config.dataContainer, config.dashboardDb, "/tmp/add_scooter_charging_data.sql");
psql(config.dataContainer, config.dashboardDb, "/tmp/add_drinking_fountain_data.sql");
psql(config.dataContainer, config.dashboardDb, "/tmp/add_used_clothing_box_data.sql");

console.log("產生 GeoJSON 檔案...");
run("node", ["scripts/阿肥/generate_recycling_station_geojson.mjs"]);
run("node", ["scripts/阿肥/generate_reusable_cup_geojson.mjs"]);
run("node", ["scripts/阿肥/generate_scooter_charging_geojson.mjs"]);
run("node", ["scripts/阿肥/generate_drinking_fountain_geojson.mjs"]);
run("node", ["scripts/阿肥/generate_used_clothing_box_geojson.mjs"]);

console.log("複製 dashboardmanager 組件與修復 SQL...");
const managerSqlFiles = [
	"add_bike_network_length_component.sql",
	"add_reusable_cup_component.sql",
	"add_recycling_station_component.sql",
	"add_eco_hotel_component.sql",
	"add_eco_restaurant_component.sql",
	"add_scooter_charging_component.sql",
	"add_drinking_fountain_component.sql",
	"add_used_clothing_box_component.sql",
	"add_circular_economy_dashboard.sql",
	"repair_dashboardmanager_consistency.sql",
	"audit_dashboardmanager_integrity.sql",
];

for (const fileName of managerSqlFiles) {
	dockerCp(
		`db-sample-data/${fileName}`,
		config.managerContainer,
		`/tmp/${fileName}`,
	);
}

console.log("套用 dashboardmanager 組件與關聯修復...");
for (const fileName of managerSqlFiles.slice(0, -1)) {
	psql(config.managerContainer, config.managerDb, `/tmp/${fileName}`);
}

console.log("執行 dashboardmanager 一致性 audit...");
psql(
	config.managerContainer,
	config.managerDb,
	"/tmp/audit_dashboardmanager_integrity.sql",
);

if (containerExists(config.qdrantRebuildContainer)) {
	console.log("重建 Qdrant public collection...");
	run("docker", ["restart", config.qdrantRebuildContainer]);
	run("docker", ["logs", "--tail=120", config.qdrantRebuildContainer]);
} else {
	console.log(
		`略過 Qdrant rebuild：找不到 ${config.qdrantRebuildContainer} 容器。請啟動 vector-db-upgrade 後重建 Qdrant。`,
	);
}

console.log("完成：dashboardmanager 關聯、dashboard 資料表與 Qdrant 已同步。");
