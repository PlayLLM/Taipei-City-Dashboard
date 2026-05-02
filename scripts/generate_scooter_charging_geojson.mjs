import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const NEW_TPE_CSV = path.join(ROOT, "data/新北市電動機車充電站_export.csv");
const TPE_CSV = path.join(ROOT, "data/臺北市營利電動機車充電站-12站.csv");
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
	const hash = hashText(`${station.city}|${station.name}|${station.address}`);
	const angle = ((hash % 3600) / 3600) * Math.PI * 2;
	const ringRatio = Math.sqrt((sequence + 1) / Math.max(total, 1));
	const jitter = 0.65 + ((hash >>> 8) % 35) / 100;
	const radius = center.radius * ringRatio * jitter;

	return [
		Number((center.lon + Math.cos(angle) * radius).toFixed(6)),
		Number((center.lat + Math.sin(angle) * radius).toFixed(6)),
	];
}

function extractDistrict(address) {
	if (!address) return "";
	const match = address.match(/(?:臺北市|台北市)(.{1,3}區)/);
	return match ? match[1].trim() : "";
}

function normalizeCity(address) {
	if (!address) return "臺北市";
	return address.includes("台北市") ? "臺北市" : "臺北市";
}

function toStations() {
	const tpeRows = readCsv(TPE_CSV, "utf8");
	const newTpeRows = readCsv(NEW_TPE_CSV, "utf8");

	const taipei = tpeRows.map((row) => {
		const address = row["地址"]?.trim();
		return {
			id: row["序號"]?.trim(),
			operator: row["廠商"]?.trim(),
			name: row["名稱"]?.trim(),
			address,
			city: normalizeCity(address),
			district: extractDistrict(address),
			station_type: null,
			operational_status: null,
			fee_applicable: null,
			open_to_public: null,
			plug_type: null,
			connector_count: null,
		};
	});

	const newTaipei = newTpeRows.map((row, index) => ({
		id: `NTPC-${index + 1}`,
		operator: null,
		name: row["charging station name"]?.trim(),
		address: row["location address"]?.trim(),
		city: "新北市",
		district: row["administrative district"]?.trim(),
		station_type: row["station type"]?.trim(),
		operational_status: row["operational status"]?.trim(),
		fee_applicable: row["fee applicable （yes/no）"]?.trim(),
		open_to_public: row["open to public（yes/no）"]?.trim(),
		plug_type: row["plug type"]?.trim(),
		connector_count: row["connector count"]?.trim(),
	}));

	return {
		taipei: taipei.filter((row) => row.district && row.address),
		metrotaipei: [...taipei, ...newTaipei].filter((row) => row.district && row.address),
	};
}

function toGeojson(stations, centers) {
	const districtTotals = new Map();
	const districtSequences = new Map();

	stations.forEach((station) => {
		districtTotals.set(
			station.district,
			(districtTotals.get(station.district) ?? 0) + 1,
		);
	});

	return {
		type: "FeatureCollection",
		name: "scooter_charging_station_approximate_points",
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
					id: station.id,
					name: station.name,
					operator: station.operator,
					address: station.address,
					city: station.city,
					district: station.district,
					station_type: station.station_type,
					operational_status: station.operational_status,
					fee_applicable: station.fee_applicable,
					open_to_public: station.open_to_public,
					plug_type: station.plug_type,
					connector_count: station.connector_count,
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
		name: "scooter_charging_tpe.geojson",
		centers: taipeiCenters,
		stations: stations.taipei,
	},
	{
		name: "scooter_charging_metrotaipei.geojson",
		centers: metroCenters,
		stations: stations.metrotaipei,
	},
];

outputs.forEach((output) => {
	const geojson = toGeojson(output.stations, output.centers);
	const filePath = path.join(OUTPUT_DIR, output.name);
	fs.writeFileSync(filePath, JSON.stringify(geojson, null, 2));
	console.log(`${output.name}: ${geojson.features.length} 筆`);
});
