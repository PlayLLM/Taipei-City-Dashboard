<script setup>
import { onMounted, onBeforeUnmount, ref, computed } from "vue";
import { useMapStore } from "../store/mapStore";
import {
	PIKMIN_COMPONENTS,
	setupPikminLayers,
	setPikminLayerVisibility,
	AvatarMarker,
	applyGameEnvironment,
	hideMinorRoadLabels,
	hideMapboxPOIs,
	teardownPikmin,
} from "../assets/utilityFunctions/pikminGame.js";

const mapStore = useMapStore();

const visible = ref(
	Object.fromEntries(PIKMIN_COMPONENTS.map((c) => [c.id, true])),
);
const components = PIKMIN_COMPONENTS;

let avatar = null;

const STEP = 0.0001;
const PROXIMITY_THRESHOLD = 0.0008; // ~88 m
const heldKeys = new Set();
let moveTimer = null;

// Only these three types are interactable challenge points
const INTERACTION_TYPES = {
	clothing:   { name: "舊衣回收箱", emoji: "👕", action: "是否投入舊衣？",     xp: 20, color: "#2B5FBF" },
	hotel:      { name: "環保旅宿",   emoji: "🏨", action: "是否要 Check in？",  xp: 50, color: "#2E8B57" },
	restaurant: { name: "環保餐廳",   emoji: "🍽",  action: "是否要用餐？",        xp: 30, color: "#E07B00" },
};

const XP_LEVELS = [
	{ level: 1, min: 0,    max: 100,  title: "新手探索者" },
	{ level: 2, min: 100,  max: 250,  title: "環保新秀"   },
	{ level: 3, min: 250,  max: 500,  title: "循環達人"   },
	{ level: 4, min: 500,  max: 1000, title: "永續勇士"   },
	{ level: 5, min: 1000, max: null, title: "地球守護者" },
];

// State
const xp            = ref(0);
const nearbyInfo    = ref(null);   // { typeId, name, emoji, action, xp, color }
const activeDialog  = ref(null);   // same shape
const flashMessage  = ref(null);   // { text, type: 'error'|'success' }
const locationData  = ref({ clothing: [], hotel: [], restaurant: [] });

let flashTimer = null;
const mapHandlers = []; // for cleanup

// ─── XP Computed ─────────────────────────────────────────────────────────────

const xpLevel = computed(() => {
	for (let i = XP_LEVELS.length - 1; i >= 0; i--) {
		if (xp.value >= XP_LEVELS[i].min) return XP_LEVELS[i];
	}
	return XP_LEVELS[0];
});

const xpProgress = computed(() => {
	const lvl = xpLevel.value;
	if (!lvl.max) return 100;
	return Math.min(100, ((xp.value - lvl.min) / (lvl.max - lvl.min)) * 100);
});

// ─── Location Data ───────────────────────────────────────────────────────────

async function loadLocationData() {
	for (const typeId of Object.keys(INTERACTION_TYPES)) {
		const comp = PIKMIN_COMPONENTS.find((c) => c.id === typeId);
		if (!comp) continue;
		try {
			const resp = await fetch(comp.geojson);
			const json = await resp.json();
			locationData.value[typeId] = json.features
				.filter((f) => f.geometry?.type === "Point")
				.map((f) => ({
					lng: f.geometry.coordinates[0],
					lat: f.geometry.coordinates[1],
				}));
		} catch { /* ignore */ }
	}
}

// ─── Proximity ───────────────────────────────────────────────────────────────

function lngLatDist(lng1, lat1, lng2, lat2) {
	const dlng = (lng1 - lng2) * 0.906; // cosine correction for Taipei latitude
	const dlat = lat1 - lat2;
	return Math.sqrt(dlng * dlng + dlat * dlat);
}

function checkProximity([lng, lat]) {
	let found = null;
	let bestDist = PROXIMITY_THRESHOLD;
	for (const typeId of Object.keys(INTERACTION_TYPES)) {
		for (const pt of locationData.value[typeId] || []) {
			const d = lngLatDist(lng, lat, pt.lng, pt.lat);
			if (d < bestDist) {
				bestDist = d;
				found = typeId;
			}
		}
	}
	nearbyInfo.value = found ? { typeId: found, ...INTERACTION_TYPES[found] } : null;
}

// ─── Interaction ─────────────────────────────────────────────────────────────

function showFlash(text, type = "error") {
	flashMessage.value = { text, type };
	if (flashTimer) clearTimeout(flashTimer);
	flashTimer = setTimeout(() => { flashMessage.value = null; }, 2000);
}

function handleMapIconClick(typeId, e) {
	if (!avatar || !e.features?.length) return;
	const [clickLng, clickLat] = e.features[0].geometry.coordinates;
	const pos = avatar.marker.getLngLat();
	if (lngLatDist(pos.lng, pos.lat, clickLng, clickLat) > PROXIMITY_THRESHOLD) {
		showFlash("距離太遠，請靠近後再互動！");
		return;
	}
	activeDialog.value = { typeId, ...INTERACTION_TYPES[typeId] };
}

function confirmInteraction() {
	if (!activeDialog.value) return;
	const gained = activeDialog.value.xp;
	xp.value += gained;
	showFlash(`+${gained} XP！`, "success");
	activeDialog.value = null;
}

function cancelInteraction() {
	activeDialog.value = null;
}

// ─── Map Controls ─────────────────────────────────────────────────────────────

function toggle(id) {
	visible.value[id] = !visible.value[id];
	if (mapStore.map) {
		setPikminLayerVisibility(mapStore.map, id, visible.value[id]);
	}
}

function recenter() {
	if (!mapStore.map || !avatar) return;
	const pos = avatar.marker.getLngLat();
	mapStore.map.easeTo({
		center: [pos.lng, pos.lat],
		zoom: 16,
		pitch: 60,
		bearing: 0,
		duration: 800,
	});
}

// ─── Avatar Movement ─────────────────────────────────────────────────────────

function moveAvatar() {
	if (!avatar) return;
	const pos = avatar.marker.getLngLat();
	let { lng, lat } = pos;
	let moved = false;

	if (heldKeys.has("ArrowUp"))    { lat += STEP; moved = true; }
	if (heldKeys.has("ArrowDown"))  { lat -= STEP; moved = true; }
	if (heldKeys.has("ArrowLeft"))  { lng -= STEP; avatar.face("left");  moved = true; }
	if (heldKeys.has("ArrowRight")) { lng += STEP; avatar.face("right"); moved = true; }

	avatar.setMoving(moved);

	if (moved) {
		avatar.setLngLat([lng, lat]);
		mapStore.map.easeTo({ center: [lng, lat], duration: 80, easing: (t) => t });
		checkProximity([lng, lat]);
	}
}

function onKeyDown(e) {
	if (!["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(e.key)) return;
	e.preventDefault();
	heldKeys.add(e.key);
}

function onKeyUp(e) {
	heldKeys.delete(e.key);
}

// ─── Lifecycle ───────────────────────────────────────────────────────────────

onMounted(() => {
	mapStore.initializeMapBox("mapbox://styles/mapbox/streets-v12");
	mapStore.setCurrentLocation();
	loadLocationData();

	const { map } = mapStore;
	const onLoad = () => {
		map.keyboard.disable();
		applyGameEnvironment(map);
		hideMinorRoadLabels(map);
		hideMapboxPOIs(map);
		map.easeTo({ center: [121.536609, 25.044808], zoom: 16, pitch: 60, duration: 0 });
		setupPikminLayers(map);

		avatar = new AvatarMarker(map, [121.536609, 25.044808]);
		avatar.start(); // no-op; animation controlled by setMoving()

		// Register click handlers for the three interactable location types
		for (const typeId of Object.keys(INTERACTION_TYPES)) {
			const layerId = `pikmin-points-${typeId}`;
			const clickFn  = (e) => handleMapIconClick(typeId, e);
			const enterFn  = () => { map.getCanvas().style.cursor = "pointer"; };
			const leaveFn  = () => { map.getCanvas().style.cursor = ""; };
			map.on("click",      layerId, clickFn);
			map.on("mouseenter", layerId, enterFn);
			map.on("mouseleave", layerId, leaveFn);
			mapHandlers.push(
				{ event: "click",      layer: layerId, fn: clickFn },
				{ event: "mouseenter", layer: layerId, fn: enterFn },
				{ event: "mouseleave", layer: layerId, fn: leaveFn },
			);
		}

		moveTimer = setInterval(moveAvatar, 33);
	};

	if (map.loaded()) onLoad();
	else map.once("load", onLoad);

	window.addEventListener("keydown", onKeyDown);
	window.addEventListener("keyup", onKeyUp);
});

onBeforeUnmount(() => {
	window.removeEventListener("keydown", onKeyDown);
	window.removeEventListener("keyup", onKeyUp);
	if (moveTimer)  { clearInterval(moveTimer);  moveTimer  = null; }
	if (flashTimer) { clearTimeout(flashTimer);  flashTimer = null; }
	if (avatar)     { avatar.destroy();          avatar     = null; }
	if (mapStore.map) {
		mapStore.map.keyboard.enable();
		for (const { event, layer, fn } of mapHandlers) {
			mapStore.map.off(event, layer, fn);
		}
		teardownPikmin(mapStore.map);
	}
});
</script>

<template>
  <div class="pikmin-view">
    <div
      id="mapboxBox"
      class="pikmin-map"
    />

    <!-- Top HUD -->
    <div class="pikmin-hud-top">
      <div class="pikmin-title">
        <span class="pikmin-title-emoji">🌱</span>
        <span>循環經濟探險</span>
      </div>
      <button
        class="pikmin-btn"
        @click="recenter"
      >
        回到角色
      </button>
    </div>

    <!-- Side layer panel -->
    <div class="pikmin-hud-side">
      <div class="pikmin-hud-label">
        圖層
      </div>
      <button
        v-for="c in components"
        :key="c.id"
        class="pikmin-layer-btn"
        :class="{ active: visible[c.id] }"
        :style="{ '--c': c.color }"
        :title="c.name"
        @click="toggle(c.id)"
      >
        <span class="dot">{{ c.label }}</span>
        <span class="name">{{ c.name }}</span>
        <span
          v-if="INTERACTION_TYPES[c.id]"
          class="challenge-badge"
        >★</span>
      </button>
    </div>

    <!-- XP bar (bottom-left) -->
    <div class="xp-bar">
      <div class="xp-level">
        Lv.{{ xpLevel.level }}
        <span class="xp-title">{{ xpLevel.title }}</span>
      </div>
      <div class="xp-track">
        <div
          class="xp-fill"
          :style="{ width: xpProgress + '%' }"
        />
      </div>
      <div class="xp-text">
        {{ xp }} XP<template v-if="xpLevel.max"> / {{ xpLevel.max }}</template>
      </div>
    </div>

    <!-- Nearby location hint (bottom-center) -->
    <transition name="fade">
      <div
        v-if="nearbyInfo && !activeDialog"
        class="nearby-hint"
      >
        <span class="nearby-emoji">{{ nearbyInfo.emoji }}</span>
        <span class="nearby-name">{{ nearbyInfo.name }}</span>
        <span class="nearby-tip">點擊地圖圖標互動</span>
      </div>
    </transition>

    <!-- Flash message -->
    <transition name="fade">
      <div
        v-if="flashMessage"
        class="flash-msg"
        :class="flashMessage.type"
      >
        {{ flashMessage.text }}
      </div>
    </transition>

    <!-- Interaction dialog -->
    <transition name="dialog-fade">
      <div
        v-if="activeDialog"
        class="dialog-overlay"
        @click.self="cancelInteraction"
      >
        <div
          class="dialog-box"
          :style="{ '--dialog-color': activeDialog.color }"
        >
          <div class="dialog-header">
            <span class="dialog-emoji">{{ activeDialog.emoji }}</span>
            <span class="dialog-name">{{ activeDialog.name }}</span>
          </div>
          <div class="dialog-action">
            {{ activeDialog.action }}
          </div>
          <div class="dialog-xp">
            完成可獲得 +{{ activeDialog.xp }} XP
          </div>
          <div class="dialog-btns">
            <button
              class="dialog-btn confirm"
              @click="confirmInteraction"
            >
              是，參與！
            </button>
            <button
              class="dialog-btn cancel"
              @click="cancelInteraction"
            >
              暫不參與
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped lang="scss">
.pikmin-view {
	position: relative;
	width: 100%;
	height: 100%;
	overflow: hidden;
	background: #f0f0f0;
}

.pikmin-map {
	width: 100%;
	height: 100%;

	// Hide Mapbox navigation controls (zoom buttons) in game view
	:deep(.mapboxgl-ctrl-group:not(:has(.mapboxgl-ctrl-geolocate))) {
		display: none;
	}
}

// ─── Top HUD ─────────────────────────────────────────────────────────────────

.pikmin-hud-top {
	position: absolute;
	top: 14px;
	left: 14px;
	display: flex;
	gap: 12px;
	align-items: center;
	z-index: 5;
	pointer-events: none;

	.pikmin-title,
	.pikmin-btn {
		pointer-events: auto;
	}
}

.pikmin-title {
	display: flex;
	align-items: center;
	gap: 8px;
	padding: 8px 14px;
	background: rgba(28, 30, 32, 0.88);
	color: #fff;
	border-radius: 999px;
	font-weight: 600;
	letter-spacing: 1px;
	backdrop-filter: blur(8px);
	border: 1px solid rgba(73, 75, 78, 0.7);

	&-emoji {
		font-size: 1.1rem;
	}
}

.pikmin-btn {
	padding: 8px 14px;
	border-radius: 999px;
	border: 1px solid rgba(73, 75, 78, 0.7);
	background: rgba(28, 30, 32, 0.88);
	color: #fff;
	cursor: pointer;
	transition: background 0.15s, border-color 0.15s;
	backdrop-filter: blur(8px);

	&:hover {
		background: rgba(90, 156, 248, 0.25);
		border-color: #5a9cf8;
	}
}

// ─── Side Layer Panel ────────────────────────────────────────────────────────

.pikmin-hud-side {
	position: absolute;
	right: 14px;
	top: 90px;
	display: flex;
	flex-direction: column;
	gap: 8px;
	z-index: 5;
	padding: 12px 10px;
	background: rgba(28, 30, 32, 0.9);
	border-radius: 14px;
	backdrop-filter: blur(10px);
	border: 1px solid rgba(73, 75, 78, 0.6);

	.pikmin-hud-label {
		color: #888787;
		font-size: 0.72rem;
		letter-spacing: 2px;
		text-align: center;
		margin-bottom: 4px;
	}
}

.pikmin-layer-btn {
	display: flex;
	align-items: center;
	gap: 8px;
	padding: 6px 10px 6px 6px;
	border-radius: 999px;
	border: 1px solid rgba(73, 75, 78, 0.5);
	background: rgba(255, 255, 255, 0.05);
	color: #888787;
	cursor: pointer;
	transition: all 0.15s;
	font-size: 0.85rem;

	.dot {
		width: 24px;
		height: 24px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		background: var(--c);
		color: #fff;
		font-weight: 700;
		font-size: 0.78rem;
		opacity: 0.45;
		transition: opacity 0.15s;
	}

	.challenge-badge {
		color: #ffd700;
		font-size: 0.68rem;
		margin-left: auto;
		padding-left: 4px;
	}

	&.active {
		color: #fff;
		background: rgba(255, 255, 255, 0.1);
		border-color: var(--c);

		.dot {
			opacity: 1;
		}
	}

	&:hover {
		color: #fff;
		background: rgba(255, 255, 255, 0.08);

		.dot {
			opacity: 1;
		}
	}
}

// ─── XP Bar ──────────────────────────────────────────────────────────────────

.xp-bar {
	position: absolute;
	bottom: 20px;
	left: 14px;
	z-index: 5;
	min-width: 200px;
	padding: 10px 14px;
	background: rgba(28, 30, 32, 0.92);
	border: 1px solid rgba(73, 75, 78, 0.6);
	border-radius: 12px;
	backdrop-filter: blur(10px);
}

.xp-level {
	display: flex;
	align-items: center;
	gap: 6px;
	color: #fff;
	font-size: 0.85rem;
	font-weight: 700;
	margin-bottom: 6px;
}

.xp-title {
	color: #ffd700;
	font-size: 0.75rem;
	font-weight: 500;
}

.xp-track {
	height: 7px;
	background: rgba(255, 255, 255, 0.12);
	border-radius: 999px;
	overflow: hidden;
	margin-bottom: 5px;
}

.xp-fill {
	height: 100%;
	background: linear-gradient(90deg, #5a9cf8, #a78bfa);
	border-radius: 999px;
	transition: width 0.5s cubic-bezier(0.25, 1, 0.5, 1);
}

.xp-text {
	color: #888787;
	font-size: 0.7rem;
	text-align: right;
}

// ─── Nearby Hint ─────────────────────────────────────────────────────────────

.nearby-hint {
	position: absolute;
	bottom: 20px;
	left: 50%;
	transform: translateX(-50%);
	z-index: 5;
	display: flex;
	align-items: center;
	gap: 8px;
	padding: 9px 18px;
	background: rgba(28, 30, 32, 0.92);
	border: 1px solid rgba(90, 156, 248, 0.55);
	border-radius: 999px;
	backdrop-filter: blur(10px);
	color: #fff;
	font-size: 0.88rem;
	pointer-events: none;
	white-space: nowrap;
}

.nearby-emoji {
	font-size: 1.15rem;
}

.nearby-tip {
	color: #5a9cf8;
	font-size: 0.76rem;
}

// ─── Flash Message ───────────────────────────────────────────────────────────

.flash-msg {
	position: absolute;
	top: 62px;
	left: 50%;
	transform: translateX(-50%);
	z-index: 10;
	padding: 8px 22px;
	border-radius: 999px;
	font-size: 0.9rem;
	font-weight: 600;
	pointer-events: none;
	white-space: nowrap;

	&.error {
		background: rgba(200, 50, 50, 0.92);
		color: #fff;
		border: 1px solid rgba(255, 100, 100, 0.4);
	}

	&.success {
		background: rgba(46, 139, 87, 0.92);
		color: #fff;
		border: 1px solid rgba(100, 210, 140, 0.4);
	}
}

// ─── Interaction Dialog ──────────────────────────────────────────────────────

.dialog-overlay {
	position: absolute;
	inset: 0;
	z-index: 20;
	display: flex;
	align-items: center;
	justify-content: center;
	background: rgba(0, 0, 0, 0.42);
	backdrop-filter: blur(3px);
}

.dialog-box {
	background: rgba(18, 20, 24, 0.97);
	border: 2px solid var(--dialog-color, #5a9cf8);
	border-radius: 20px;
	padding: 28px 34px;
	min-width: 280px;
	max-width: 360px;
	text-align: center;
	box-shadow: 0 12px 48px rgba(0, 0, 0, 0.65);
}

.dialog-header {
	display: flex;
	align-items: center;
	justify-content: center;
	gap: 10px;
	margin-bottom: 14px;
}

.dialog-emoji {
	font-size: 2rem;
}

.dialog-name {
	font-size: 1.2rem;
	font-weight: 700;
	color: var(--dialog-color, #5a9cf8);
}

.dialog-action {
	font-size: 1.05rem;
	color: #fff;
	margin-bottom: 8px;
}

.dialog-xp {
	font-size: 0.85rem;
	color: #ffd700;
	margin-bottom: 22px;
}

.dialog-btns {
	display: flex;
	gap: 12px;
	justify-content: center;
}

.dialog-btn {
	padding: 10px 24px;
	border-radius: 999px;
	border: none;
	cursor: pointer;
	font-size: 0.9rem;
	font-weight: 600;
	transition: all 0.15s;

	&.confirm {
		background: var(--dialog-color, #5a9cf8);
		color: #fff;

		&:hover {
			filter: brightness(1.2);
		}
	}

	&.cancel {
		background: rgba(255, 255, 255, 0.08);
		color: #888787;
		border: 1px solid rgba(73, 75, 78, 0.5);

		&:hover {
			background: rgba(255, 255, 255, 0.15);
			color: #fff;
		}
	}
}

// ─── Transitions ─────────────────────────────────────────────────────────────

.fade-enter-active,
.fade-leave-active {
	transition: opacity 0.25s;
}

.fade-enter-from,
.fade-leave-to {
	opacity: 0;
}

.dialog-fade-enter-active,
.dialog-fade-leave-active {
	transition: opacity 0.2s;

	.dialog-box {
		transition: transform 0.2s cubic-bezier(0.34, 1.56, 0.64, 1);
	}
}

.dialog-fade-enter-from,
.dialog-fade-leave-to {
	opacity: 0;

	.dialog-box {
		transform: scale(0.92);
	}
}
</style>

<style>
.pikmin-avatar img {
	user-select: none;
	-webkit-user-drag: none;
}
</style>
