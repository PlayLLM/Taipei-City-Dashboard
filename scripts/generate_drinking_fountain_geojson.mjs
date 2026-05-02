import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const DATA_DIR = path.join(ROOT, "data");
const OUTPUT_DIR = path.join(
	ROOT,
	"Taipei-City-Dashboard-FE/public/mapData",
);

function parseCsv(content) {
	const rows = [];
	let row = [];
	let field = "";
	let inQuotes = false;

	for (let i = 0; i < content.length; i += 1) {
		const char = content[i];
		const nextChar = content[i + 1];

		if (char === "\"" && nextChar === "\"") {
			field += "\"";
			i += 1;
			continue;
		}

		if (char === "\"") {
			inQuotes = !inQuotes;
			continue;
		}

		if (char === "," && !inQuotes) {
			row.push(field);
			field = "";
			continue;
		}

		if ((char === "\n" || char === "\r") && !inQuotes) {
			if (field.length > 0 || row.length > 0) {
				row.push(field);
				rows.push(row);
			}
			row = [];
			field = "";
			if (char === "\r" && nextChar === "\n") {
				i += 1;
			}
			continue;
		}

		field += char;
	}

	if (field.length > 0 || row.length > 0) {
		row.push(field);
		rows.push(row);
	}

	return rows;
}

function toNumber(value) {
	const parsed = Number.parseFloat(value);
	return Number.isFinite(parsed) ? parsed : null;
}

function normalizeHeaderKey(value) {
	if (!value) return value;
	return value.replace(/^\ufeff/, "").trim();
}

function normalizeCity(value) {
	if (!value) return null;
	const trimmed = value.trim();
	if (trimmed === "台北市" || trimmed === "臺北市") return "臺北市";
	if (trimmed === "新北市") return "新北市";
	return trimmed || null;
}

function normalizeDistrict(value) {
	if (!value) return null;
	const trimmed = value.trim();
	if (!trimmed) return null;
	return trimmed.endsWith("區") ? trimmed : `${trimmed}區`;
}

function buildFountainFeatures(rows) {
	const [header, ...dataRows] = rows;
	const index = header.reduce((acc, key, idx) => {
		acc[normalizeHeaderKey(key)] = idx;
		return acc;
	}, {});

	return dataRows
		.map((row) => {
			const lat = toNumber(row[index["緯度"]]);
			const lng = toNumber(row[index["經度"]]);

			if (lat === null || lng === null) {
				return null;
			}

			return {
				type: "Feature",
				geometry: {
					type: "Point",
					coordinates: [lng, lat],
				},
				properties: {
					source_type: "飲水機",
					name: row[index["場所名稱"]] || null,
					address: row[index["場所地址"]] || null,
					city: "臺北市",
					district: normalizeDistrict(row[index["行政區"]]),
					managing_unit: row[index["管理單位"]] || null,
					maintenance_unit: null,
					phone: row[index["連絡電話"]] || null,
					open_time: row[index["場所開放時間"]] || null,
					location: row[index["設置地點"]] || null,
					status: null,
					info_url: null,
					photo_url: null,
				},
			};
		})
		.filter(Boolean);
}

function buildStationFeatures(rows) {
	const [header, ...dataRows] = rows;
	const index = header.reduce((acc, key, idx) => {
		acc[normalizeHeaderKey(key)] = idx;
		return acc;
	}, {});

	return dataRows
		.map((row) => {
			const lat = toNumber(row[index["緯度"]]);
			const lng = toNumber(row[index["經度"]]);
			const city = normalizeCity(row[index["市別"]]);

			if (lat === null || lng === null || !city) {
				return null;
			}

			return {
				type: "Feature",
				geometry: {
					type: "Point",
					coordinates: [lng, lat],
				},
				properties: {
					source_type: "直飲臺",
					name: row[index["場所名稱"]] || null,
					address: row[index["地址"]] || null,
					city,
					district: normalizeDistrict(row[index["行政區"]]),
					managing_unit: row[index["所屬單位"]] || null,
					maintenance_unit: row[index["維護單位"]] || null,
					phone: row[index["連絡電話"]] || null,
					open_time: row[index["場所開放時間"]] || null,
					location: row[index["設置地點"]] || null,
					status: row[index["狀態"]] || null,
					info_url: row[index["水質及維護資訊網址"]] || null,
					photo_url: row[index["直飲台照片網址"]] || null,
				},
			};
		})
		.filter(Boolean);
}

function main() {
	const fountainPath = path.join(DATA_DIR, "臺北市公共場所飲水機資訊.csv");
	const stationPath = path.join(DATA_DIR, "11503_直飲台基本資料.csv");

	const fountainContent = fs.readFileSync(fountainPath, "utf8");
	const stationContent = fs.readFileSync(stationPath, "utf8");

	const fountainRows = parseCsv(fountainContent);
	const stationRows = parseCsv(stationContent);

	const fountainFeatures = buildFountainFeatures(fountainRows);
	const stationFeatures = buildStationFeatures(stationRows);
	const allFeatures = [...fountainFeatures, ...stationFeatures];

	const geojson = {
		type: "FeatureCollection",
		features: allFeatures,
	};

	if (!fs.existsSync(OUTPUT_DIR)) {
		fs.mkdirSync(OUTPUT_DIR, { recursive: true });
	}

	const metroPath = path.join(
		OUTPUT_DIR,
		"drinking_fountain_metrotaipei.geojson",
	);
	fs.writeFileSync(metroPath, JSON.stringify(geojson, null, 2));

	const tpeGeojson = {
		type: "FeatureCollection",
		features: allFeatures.filter(
			(feature) => feature.properties.city === "臺北市",
		),
	};
	const tpePath = path.join(OUTPUT_DIR, "drinking_fountain_tpe.geojson");
	fs.writeFileSync(tpePath, JSON.stringify(tpeGeojson, null, 2));

	console.log(
		`drinking_fountain_metrotaipei.geojson: ${allFeatures.length} 筆`,
	);
	console.log(
		`drinking_fountain_tpe.geojson: ${tpeGeojson.features.length} 筆`,
	);
}

main();
