// Pikmin-style game logic for the Mapbox map.
// Avatar walks via cycling 8 WebP frames (1→8→1).
// Six circular-economy datasets are loaded as clustered symbol layers
// and culled by zoom + viewport for performance.

import mapboxGl from "mapbox-gl";

export const PIKMIN_COMPONENTS = [
	{
		id: "clothing",
		geojson: "/mapData/used_clothing_box_metrotaipei.geojson",
		label: "衣",
		color: "#2B5FBF",
		name: "舊衣回收箱",
	},
	{
		id: "hotel",
		geojson: "/mapData/eco_hotel_metrotaipei.geojson",
		label: "宿",
		color: "#2E8B57",
		name: "環保旅宿",
	},
	{
		id: "restaurant",
		geojson: "/mapData/eco_restaurant_metrotaipei.geojson",
		label: "餐",
		color: "#E07B00",
		name: "環保餐廳",
	},
	{
		id: "cup",
		geojson: "/mapData/reusable_cup_store_metrotaipei.geojson",
		label: "杯",
		color: "#0EA5A0",
		name: "循環杯門市",
	},
	{
		id: "charging",
		geojson: "/mapData/scooter_charging_metrotaipei.geojson",
		label: "電",
		color: "#D4A017",
		name: "機車充電站",
	},
	{
		id: "fountain",
		geojson: "/mapData/drinking_fountain_metrotaipei.geojson",
		label: "水",
		color: "#3FA9F5",
		name: "飲水機",
	},
];

// Render a labeled circular icon onto a Mapbox image (data ImageData).
function makeCircleIcon(map, name, label, color, size = 64) {
	if (map.hasImage(name)) return;
	const canvas = document.createElement("canvas");
	canvas.width = size;
	canvas.height = size;
	const ctx = canvas.getContext("2d");
	const r = size / 2;
	ctx.beginPath();
	ctx.arc(r, r, r - 2, 0, Math.PI * 2);
	ctx.fillStyle = color;
	ctx.fill();
	ctx.lineWidth = 3;
	ctx.strokeStyle = "rgba(255,255,255,0.95)";
	ctx.stroke();
	ctx.fillStyle = "#fff";
	ctx.font = `bold ${size * 0.5}px "Noto Sans TC", sans-serif`;
	ctx.textAlign = "center";
	ctx.textBaseline = "middle";
	ctx.fillText(label, r, r + 1);
	const img = ctx.getImageData(0, 0, size, size);
	map.addImage(name, img, { pixelRatio: 2 });
}

// Render a cluster bubble with the same component color.
function makeClusterIcon(map, name, color, size = 80) {
	if (map.hasImage(name)) return;
	const canvas = document.createElement("canvas");
	canvas.width = size;
	canvas.height = size;
	const ctx = canvas.getContext("2d");
	const r = size / 2;
	ctx.beginPath();
	ctx.arc(r, r, r - 4, 0, Math.PI * 2);
	ctx.fillStyle = color;
	ctx.globalAlpha = 0.85;
	ctx.fill();
	ctx.globalAlpha = 1;
	ctx.lineWidth = 4;
	ctx.strokeStyle = "rgba(255,255,255,0.9)";
	ctx.stroke();
	const img = ctx.getImageData(0, 0, size, size);
	map.addImage(name, img, { pixelRatio: 2 });
}

export function setupPikminLayers(map) {
	for (const c of PIKMIN_COMPONENTS) {
		const iconName = `pikmin-icon-${c.id}`;
		const clusterName = `pikmin-cluster-${c.id}`;
		const sourceId = `pikmin-src-${c.id}`;

		makeCircleIcon(map, iconName, c.label, c.color);
		makeClusterIcon(map, clusterName, c.color);

		if (!map.getSource(sourceId)) {
			map.addSource(sourceId, {
				type: "geojson",
				data: c.geojson,
				cluster: true,
				clusterMaxZoom: 14,
				clusterRadius: 60,
			});
		}

		// Unclustered points — only show above zoom 13 to limit density.
		const pointLayerId = `pikmin-points-${c.id}`;
		if (!map.getLayer(pointLayerId)) {
			map.addLayer({
				id: pointLayerId,
				type: "symbol",
				source: sourceId,
				filter: ["!", ["has", "point_count"]],
				minzoom: 13,
				layout: {
					"icon-image": iconName,
					"icon-size": [
						"interpolate",
						["linear"],
						["zoom"],
						13,
						0.35,
						16,
						0.55,
						20,
						0.85,
					],
					"icon-allow-overlap": true,
					"icon-ignore-placement": false,
				},
			});
		}

		// Cluster bubbles with count text — show at lower zoom.
		const clusterLayerId = `pikmin-clusters-${c.id}`;
		if (!map.getLayer(clusterLayerId)) {
			map.addLayer({
				id: clusterLayerId,
				type: "symbol",
				source: sourceId,
				filter: ["has", "point_count"],
				minzoom: 11,
				layout: {
					"icon-image": clusterName,
					"icon-size": [
						"interpolate",
						["linear"],
						["get", "point_count"],
						2,
						0.45,
						50,
						0.8,
						200,
						1.0,
					],
					"icon-allow-overlap": true,
					"text-field": ["to-string", ["get", "point_count_abbreviated"]],
					"text-size": 13,
					"text-font": ["Noto Sans Regular"],
				},
				paint: {
					"text-color": "#fff",
				},
			});
		}
	}
}

export function setPikminLayerVisibility(map, componentId, visible) {
	const v = visible ? "visible" : "none";
	const ids = [`pikmin-points-${componentId}`, `pikmin-clusters-${componentId}`];
	for (const id of ids) {
		if (map.getLayer(id)) map.setLayoutProperty(id, "visibility", v);
	}
}

// Walking-animation marker. Idle = frame 3; walking = cycles 1→8→7→…→1.
export class AvatarMarker {
	constructor(map, lngLat, { frameCount = 8, frameMs = 110, size = 96 } = {}) {
		this.map = map;
		this.frameCount = frameCount;
		this.frameMs = frameMs;
		this.size = size;
		this.timer = null;
		this.idx = 2; // start at frame 3 (standing)
		this.dir = 1;
		this._moving = false;

		const el = document.createElement("div");
		el.className = "pikmin-avatar";
		el.style.cssText = `
			width: ${size}px;
			height: ${size}px;
			pointer-events: none;
			transform-origin: center bottom;
			filter: drop-shadow(0 6px 6px rgba(0,0,0,0.45));
		`;
		const img = document.createElement("img");
		img.style.cssText = "width:100%;height:100%;display:block;image-rendering:auto;";
		img.draggable = false;
		img.src = "/images/pikmin/avatar/3.webp"; // standing pose
		el.appendChild(img);

		this.el = el;
		this.img = img;
		this.marker = new mapboxGl.Marker({
			element: el,
			anchor: "bottom",
			pitchAlignment: "viewport",
			rotationAlignment: "viewport",
		})
			.setLngLat(lngLat)
			.addTo(map);
	}

	// No-op — kept for backwards compatibility; animation is driven by setMoving().
	start() {}

	setMoving(moving) {
		if (moving === this._moving) return;
		this._moving = moving;
		if (moving) {
			if (this.timer) return;
			this.timer = setInterval(() => {
				this.idx += this.dir;
				if (this.idx >= this.frameCount - 1) {
					this.idx = this.frameCount - 1;
					this.dir = -1;
				} else if (this.idx <= 0) {
					this.idx = 0;
					this.dir = 1;
				}
				this.img.src = `/images/pikmin/avatar/${this.idx + 1}.webp`;
			}, this.frameMs);
		} else {
			clearInterval(this.timer);
			this.timer = null;
			this.idx = 2;
			this.dir = 1;
			this.img.src = "/images/pikmin/avatar/3.webp";
		}
	}

	stop() {
		this.setMoving(false);
	}

	setLngLat(lngLat) {
		this.marker.setLngLat(lngLat);
	}

	face(direction) {
		// direction: "left" | "right"
		this.el.style.transform =
			direction === "left" ? "scaleX(-1)" : "scaleX(1)";
	}

	destroy() {
		this.stop();
		this.marker.remove();
	}
}

// Optional: pretty environment (lights + fog + terrain).
export function applyGameEnvironment(map) {
	try {
		map.setPitch(60);
		map.setMinPitch(30);
		map.setMaxPitch(75);
	} catch { /* ignore */ }

	// No fog override — let the streets-v12 style handle the sky naturally.

	try {
		if (typeof map.setLights === "function") {
			map.setLights([
				{
					id: "ambient",
					type: "ambient",
					properties: { intensity: 0.6, color: "#ffffff" },
				},
				{
					id: "directional",
					type: "directional",
					properties: {
						intensity: 0.7,
						direction: [210, 40],
						color: "#fff4d6",
						"cast-shadows": true,
					},
				},
			]);
		}
	} catch { /* ignore */ }
}

// Hide built-in Mapbox POI layers (restaurants, shops, etc.) so only game locations stand out.
export function hideMapboxPOIs(map) {
	const poiSourceLayers = ["poi", "poi_label"];
	for (const layer of map.getStyle().layers) {
		if (poiSourceLayers.includes(layer["source-layer"])) {
			try {
				map.setLayoutProperty(layer.id, "visibility", "none");
			} catch { /* ignore */ }
		}
	}
}

// Hide minor road labels — only motorway / trunk / primary / secondary names remain.
export function hideMinorRoadLabels(map) {
	const majorClasses = ["motorway", "trunk", "primary", "secondary"];
	const classFilter = ["in", ["get", "class"], ["literal", majorClasses]];

	for (const layer of map.getStyle().layers) {
		if (layer.type !== "symbol") continue;
		if (!["road", "transportation"].includes(layer["source-layer"])) continue;
		const existing = map.getFilter(layer.id);
		try {
			map.setFilter(
				layer.id,
				existing ? ["all", existing, classFilter] : classFilter,
			);
		} catch { /* ignore */ }
	}
}

export function teardownPikmin(map) {
	if (!map) return;
	for (const c of PIKMIN_COMPONENTS) {
		const point = `pikmin-points-${c.id}`;
		const cluster = `pikmin-clusters-${c.id}`;
		const src = `pikmin-src-${c.id}`;
		if (map.getLayer(point)) map.removeLayer(point);
		if (map.getLayer(cluster)) map.removeLayer(cluster);
		if (map.getSource(src)) map.removeSource(src);
	}
}
