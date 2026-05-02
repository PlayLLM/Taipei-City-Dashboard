#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import process from "node:process";

// 匯入「資源回收站分布」資料與組件，並重建 Qdrant 向量索引。
// 可透過環境變數覆寫容器名稱與資料庫名稱：
//   DATA_CONTAINER=postgres-data
//   MANAGER_CONTAINER=postgres-manager
//   QDRANT_REBUILD_CONTAINER=vector-db-upgrade
//   DASHBOARD_DB=dashboard
//   MANAGER_DB=dashboardmanager
//   POSTGRES_USER=postgres

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

function run(command, args, options = {}) {
	execFileSync(command, args, {
		cwd: rootDir,
		stdio: "inherit",
		...options,
	});
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

console.log(`複製資源回收站 CSV 與 dashboard SQL 到 ${config.dataContainer}...`);
run("docker", [
	"cp",
	"data/臺北市資源回收站資訊.csv",
	`${config.dataContainer}:/tmp/recycling_station_tpe.csv`,
]);
run("docker", [
	"cp",
	"data/新北市資源回收站資訊.csv",
	`${config.dataContainer}:/tmp/recycling_station_new_tpe.csv`,
]);
run("docker", [
	"cp",
	"db-sample-data/add_recycling_station_data.sql",
	`${config.dataContainer}:/tmp/add_recycling_station_data.sql`,
]);

console.log(`匯入資源回收站資料到 ${config.dashboardDb}...`);
run("docker", [
	"exec",
	config.dataContainer,
	"psql",
	"-U",
	config.postgresUser,
	"-d",
	config.dashboardDb,
	"-f",
	"/tmp/add_recycling_station_data.sql",
]);

console.log("產生行政區級近似點位 GeoJSON...");
run("node", ["scripts/generate_recycling_station_geojson.mjs"]);

console.log(`複製組件 SQL 到 ${config.managerContainer}...`);
run("docker", [
	"cp",
	"db-sample-data/add_recycling_station_component.sql",
	`${config.managerContainer}:/tmp/add_recycling_station_component.sql`,
]);

console.log(`註冊資源回收站分布組件到 ${config.managerDb}...`);
run("docker", [
	"exec",
	config.managerContainer,
	"psql",
	"-U",
	config.postgresUser,
	"-d",
	config.managerDb,
	"-f",
	"/tmp/add_recycling_station_component.sql",
]);

if (containerExists(config.qdrantRebuildContainer)) {
	console.log("重建 Qdrant public collection...");
	run("docker", ["restart", config.qdrantRebuildContainer]);
	run("docker", ["logs", "--tail=120", config.qdrantRebuildContainer]);
} else {
	console.log(
		`略過 Qdrant rebuild：找不到 ${config.qdrantRebuildContainer} 容器。請啟動 vector-db-upgrade 後重建 Qdrant。`,
	);
}

console.log("完成：PostgreSQL、GeoJSON 與 Qdrant 已同步更新。");
