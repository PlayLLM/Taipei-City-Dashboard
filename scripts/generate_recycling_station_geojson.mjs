import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const TPE_CSV = path.join(ROOT, "data/臺北市資源回收站資訊.csv");
const NEW_TPE_CSV = path.join(ROOT, "data/新北市資源回收站資訊.csv");
const TPE_TOWN_GEOJSON = path.join(
	ROOT,
	"Taipei-City-Dashboard-FE/public/mapData/taipei_town.geojson",
);
const METRO_TOWN_GEOJSON = path.join(
	ROOT,
	"Taipei-City-Dashboard-FE/public/mapData/metrotaipei_town.geojson",
);
const OUTPUT_DIR = path.join(ROOT, "Taipei-City-Dashboard-FE/public/mapData");

function parseCsv(text) {
	const rows = [];
	let row = [];
	let value = "";
	let inQuotes = false;

	for (let i = 0; i < text.length; i += 1) {
		const char = text[i];
		const next = text[i + 1];

		if (char === '"' && inQuotes && next === '"') {
			value += '"';
			i += 1;
		} else if (char === '"') {
			inQuotes = !inQuotes;
		} else if (char === "," && !inQuotes) {
			row.push(value);
			value = "";
		} else if ((char === "\n" || char === "\r") && !inQuotes) {
			if (char === "\r" && next === "\n") i += 1;
			row.push(value);
			if (row.some((cell) => cell !== "")) rows.push(row);
			row = [];
			value = "";
		} else {
			value += char;
		}
	}

	if (value !== "" || row.length > 0) {
		row.push(value);
		rows.push(row);
	}

	const headers = rows.shift().map((header) => header.replace(/^\uFEFF/, ""));
	return rows.map((cells) =>
		Object.fromEntries(headers.map((header, index) => [header, cells[index] ?? ""])),
	);
}

function readCsv(filePath, encoding) {
	const bytes = fs.readFileSync(filePath);
	return parseCsv(new TextDecoder(encoding).decode(bytes));
}

function collectCoordinates(geometry, coordinates = []) {
	if (!geometry) return coordinates;
	if (geometry.type === "Point") {
		coordinates.push(geometry.coordinates);
		return coordinates;
	}
	if (geometry.type === "Polygon") {
		geometry.coordinates.flat().forEach((point) => coordinates.push(point));
		return coordinates;
	}
	if (geometry.type === "MultiPolygon") {
		geometry.coordinates.flat(2).forEach((point) => coordinates.push(point));
		return coordinates;
	}
	return coordinates;
}

function buildDistrictCenters(geojsonPath) {
	const geojson = JSON.parse(fs.readFileSync(geojsonPath, "utf8"));
	const centers = new Map();

	for (const feature of geojson.features) {
		const district = feature.properties?.TNAME;
		if (!district) continue;

		const points = collectCoordinates(feature.geometry);
		const lons = points.map((point) => point[0]);
		const lats = points.map((point) => point[1]);
		const minLon = Math.min(...lons);
		const maxLon = Math.max(...lons);
		const minLat = Math.min(...lats);
		const maxLat = Math.max(...lats);

		centers.set(district, {
			lon: (minLon + maxLon) / 2,
			lat: (minLat + maxLat) / 2,
			radius: Math.max(0.002, Math.min(maxLon - minLon, maxLat - minLat) * 0.35),
		});
	}

	return centers;
}

function hashText(text) {
	let hash = 2166136261;
	for (let i = 0; i < text.length; i += 1) {
		hash ^= text.charCodeAt(i);
		hash = Math.imul(hash, 16777619);
	}
	return hash >>> 0;
}

function createApproxPoint(station, center, sequence, total) {
	const hash = hashText(`${station.city}|${station.id}|${station.address}`);
	const angle = ((hash % 3600) / 3600) * Math.PI * 2;
	const ringRatio = Math.sqrt((sequence + 1) / Math.max(total, 1));
	const jitter = 0.65 + ((hash >>> 8) % 35) / 100;
	const radius = center.radius * ringRatio * jitter;

	return [
		Number((center.lon + Math.cos(angle) * radius).toFixed(6)),
		Number((center.lat + Math.sin(angle) * radius).toFixed(6)),
	];
}

function toStations() {
	const tpeRows = readCsv(TPE_CSV, "big5");
	const newTpeRows = readCsv(NEW_TPE_CSV, "utf8");

	const taipei = tpeRows.map((row) => ({
		id: row["編號"],
		city: "臺北市",
		district: row["行政區"]?.trim(),
		address: row["地址"]?.trim(),
	}));

	const newTaipei = newTpeRows.map((row) => ({
		id: row.seqno,
		city: "新北市",
		district: row.district?.trim(),
		address: (row.recycle_address || row.address)?.trim(),
	}));

	return {
		taipei: taipei.filter((row) => row.district && row.address),
		metrotaipei: [...taipei, ...newTaipei].filter(
			(row) => row.district && row.address,
		),
	};
}

function toGeojson(stations, centers) {
	const districtTotals = new Map();
	const districtSequences = new Map();
	stations.forEach((station) => {
		districtTotals.set(station.district, (districtTotals.get(station.district) ?? 0) + 1);
	});

	return {
		type: "FeatureCollection",
		name: "recycling_station_approximate_points",
		metadata: {
			coordinate_note:
				"行政區級近似座標：由行政區中心點加固定偏移產生，非實際門牌座標。",
		},
		features: stations.flatMap((station) => {
			const center = centers.get(station.district);
			if (!center) return [];

			const sequence = districtSequences.get(station.district) ?? 0;
			districtSequences.set(station.district, sequence + 1);

			return {
				type: "Feature",
				geometry: {
					type: "Point",
					coordinates: createApproxPoint(
						station,
						center,
						sequence,
						districtTotals.get(station.district),
					),
				},
				properties: {
					city: station.city,
					district: station.district,
					address: station.address,
					coordinate_accuracy: "行政區級近似座標",
				},
			};
		}),
	};
}

const stations = toStations();
const taipeiCenters = buildDistrictCenters(TPE_TOWN_GEOJSON);
const metroCenters = buildDistrictCenters(METRO_TOWN_GEOJSON);

const outputs = [
	{
		file: "recycling_station_tpe.geojson",
		geojson: toGeojson(stations.taipei, taipeiCenters),
	},
	{
		file: "recycling_station_metrotaipei.geojson",
		geojson: toGeojson(stations.metrotaipei, metroCenters),
	},
];

for (const output of outputs) {
	const outputPath = path.join(OUTPUT_DIR, output.file);
	fs.writeFileSync(outputPath, `${JSON.stringify(output.geojson)}\n`);
	console.log(`${output.file}: ${output.geojson.features.length} features`);
}
