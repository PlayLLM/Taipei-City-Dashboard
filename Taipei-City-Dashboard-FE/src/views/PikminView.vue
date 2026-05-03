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

const MOVE_SPEED_MULTIPLIER = 2;
const MOVE_SPEED_PX_PER_SEC = 260 * MOVE_SPEED_MULTIPLIER;
const PROXIMITY_THRESHOLD = 0.0005; // ~55 m（較小的互動範圍）
const GAME_STATE_STORAGE_KEY = "pikmin-game-state-v1";
const GAME_STATE_SAVE_INTERVAL_MS = 900;
const heldKeys = new Set();
let moveRaf = null;
let lastMoveTs = 0;
const DEFAULT_START_CENTER = [121.536609, 25.044808];

// All six layer types are interactable challenge points
const INTERACTION_TYPES = {
	clothing:   { name: "舊衣回收箱", emoji: "👕", action: "是否投入舊衣？",        xp: 20, color: "#2B5FBF" },
	hotel:      { name: "環保旅宿",   emoji: "🏨", action: "是否要 Check in？",     xp: 50, color: "#2E8B57" },
	restaurant: { name: "環保餐廳",   emoji: "🍽",  action: "是否要用餐？",          xp: 30, color: "#E07B00" },
	cup:        { name: "循環杯門市", emoji: "🥤", action: "是否要租用循環杯？",    xp: 30, color: "#0EA5A0" },
	charging:   { name: "機車充電站", emoji: "🔋", action: "是否要為機車充電？",    xp: 25, color: "#D4A017" },
	fountain:   { name: "飲水機",     emoji: "💧", action: "是否要裝水補給？",       xp: 15, color: "#3FA9F5" },
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
const completionCounts = ref(
	Object.fromEntries(Object.keys(INTERACTION_TYPES).map((id) => [id, 0])),
);
const locationData  = ref(
	Object.fromEntries(Object.keys(INTERACTION_TYPES).map((id) => [id, []])),
);
const locationPermissionModal = ref(false);
const isRequestingLocation = ref(false);

let flashTimer = null;
const mapHandlers = []; // for cleanup
let currentProximityKey = null;
let lastPersistedAt = 0;
const autoTriggeredProximityKeys = ref(new Set());
const completedProximityKeys = ref(new Set());
const lastKnownCenter = ref(null);

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
					props: f.properties || {},
				}));
		} catch { /* ignore */ }
	}
}

function extractPointDetails(typeId, props) {
	if (!props) return null;
	const d = {};
	switch (typeId) {
		case "restaurant":
			d.pointName = props.name || null;
			d.address   = props.address || null;
			d.phone     = props.phone || null;
			break;
		case "hotel":
			d.pointName = props.name || null;
			d.grade     = props.grade || null;
			d.address   = props.address || null;
			d.phone     = props.phone || null;
			break;
		case "cup":
			d.pointName = [props.brand, props.store_name].filter(Boolean).join(" ") || null;
			d.address   = props.address || null;
			d.phone     = props.phone || null;
			break;
		case "charging":
			d.pointName = props.name || null;
			d.operator  = props.operator || null;
			d.address   = props.address || null;
			break;
		case "fountain":
			d.pointName     = props.name || null;
			d.address       = props.address || null;
			d.phone         = props.phone || null;
			d.openTime      = props.open_time || null;
			d.floorLocation = props.location || null;
			break;
		case "clothing":
			d.pointName = props.org || null;
			d.address   = props.address || null;
			break;
		default:
			d.address = props.address || null;
	}
	return d;
}

function isValidCenter(center) {
	return Array.isArray(center)
		&& center.length === 2
		&& Number.isFinite(Number(center[0]))
		&& Number.isFinite(Number(center[1]));
}

function persistGameState({ force = false } = {}) {
	if (typeof window === "undefined") return;
	const now = Date.now();
	if (!force && now - lastPersistedAt < GAME_STATE_SAVE_INTERVAL_MS) return;

	const center = isValidCenter(lastKnownCenter.value)
		? [Number(lastKnownCenter.value[0]), Number(lastKnownCenter.value[1])]
		: null;
	const completionPayload = Object.fromEntries(
		Object.keys(INTERACTION_TYPES).map((id) => [id, Number(completionCounts.value[id]) || 0]),
	);
	const payload = {
		xp: Number(xp.value) || 0,
		completionCounts: completionPayload,
		center,
		autoTriggeredProximityKeys: [...autoTriggeredProximityKeys.value],
		completedProximityKeys: [...completedProximityKeys.value],
	};
	try {
		window.localStorage.setItem(GAME_STATE_STORAGE_KEY, JSON.stringify(payload));
		lastPersistedAt = now;
	} catch { /* ignore */ }
}

function restoreGameState() {
	if (typeof window === "undefined") return null;

	let parsed = null;
	try {
		parsed = JSON.parse(window.localStorage.getItem(GAME_STATE_STORAGE_KEY) || "null");
	} catch {
		parsed = null;
	}
	if (!parsed || typeof parsed !== "object") return null;

	const safeXp = Number(parsed.xp);
	if (Number.isFinite(safeXp) && safeXp >= 0) {
		xp.value = safeXp;
	}

	for (const id of Object.keys(INTERACTION_TYPES)) {
		const count = Number(parsed.completionCounts?.[id]);
		completionCounts.value[id] = Number.isFinite(count) && count > 0 ? Math.floor(count) : 0;
	}

	const restoredAutoKeys = Array.isArray(parsed.autoTriggeredProximityKeys)
		? parsed.autoTriggeredProximityKeys.filter((key) => typeof key === "string")
		: [];
	autoTriggeredProximityKeys.value = new Set(restoredAutoKeys);

	const restoredCompletedKeys = Array.isArray(parsed.completedProximityKeys)
		? parsed.completedProximityKeys.filter((key) => typeof key === "string")
		: [];
	completedProximityKeys.value = new Set(restoredCompletedKeys);

	if (isValidCenter(parsed.center)) {
		const center = [Number(parsed.center[0]), Number(parsed.center[1])];
		storeUserLocation(center, { shouldPersist: false });
		return center;
	}
	return null;
}

// ─── Proximity ───────────────────────────────────────────────────────────────

function lngLatDist(lng1, lat1, lng2, lat2) {
	const dlng = (lng1 - lng2) * 0.906; // cosine correction for Taipei latitude
	const dlat = lat1 - lat2;
	return Math.sqrt(dlng * dlng + dlat * dlat);
}

function checkProximity([lng, lat]) {
	let foundTypeId = null;
	let foundIndex = -1;
	let bestDist = PROXIMITY_THRESHOLD;
	for (const typeId of Object.keys(INTERACTION_TYPES)) {
		for (const [index, pt] of (locationData.value[typeId] || []).entries()) {
			const d = lngLatDist(lng, lat, pt.lng, pt.lat);
			if (d < bestDist) {
				bestDist = d;
				foundTypeId = typeId;
				foundIndex = index;
			}
		}
	}
	if (!foundTypeId) {
		currentProximityKey = null;
		nearbyInfo.value = null;
		return;
	}

	const nextProximityKey = `${foundTypeId}:${foundIndex}`;
	const foundPt = locationData.value[foundTypeId][foundIndex];
	const details = extractPointDetails(foundTypeId, foundPt?.props);
	nearbyInfo.value = {
		typeId: foundTypeId,
		proximityKey: nextProximityKey,
		isCompleted: completedProximityKeys.value.has(nextProximityKey),
		details,
		...INTERACTION_TYPES[foundTypeId],
	};

	// First arrival at each point auto-opens once; afterwards user must click to open.
	if (
		currentProximityKey !== nextProximityKey
		&& !activeDialog.value
		&& !autoTriggeredProximityKeys.value.has(nextProximityKey)
		&& !completedProximityKeys.value.has(nextProximityKey)
	) {
		activeDialog.value = {
			typeId: foundTypeId,
			proximityKey: nextProximityKey,
			isCompleted: false,
			details,
			...INTERACTION_TYPES[foundTypeId],
		};
		autoTriggeredProximityKeys.value.add(nextProximityKey);
		persistGameState({ force: true });
	}

	currentProximityKey = nextProximityKey;
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
	const pos = avatar.getLngLat();
	if (lngLatDist(pos.lng, pos.lat, clickLng, clickLat) > PROXIMITY_THRESHOLD) {
		showFlash("距離太遠，請靠近後再互動！");
		return;
	}

	// Find the index of this feature to build the proximity key
	// Mapbox features usually have an index or we can use coordinates as a fallback,
	// but for consistency with checkProximity, we'll find it in locationData.
	let foundIndex = -1;
	for (const [idx, pt] of (locationData.value[typeId] || []).entries()) {
		if (Math.abs(pt.lng - clickLng) < 0.000001 && Math.abs(pt.lat - clickLat) < 0.000001) {
			foundIndex = idx;
			break;
		}
	}

	const proximityKey = foundIndex !== -1 ? `${typeId}:${foundIndex}` : null;
	const isCompleted = proximityKey ? completedProximityKeys.value.has(proximityKey) : false;
	const clickedProps = e.features[0].properties || (foundIndex !== -1 ? locationData.value[typeId][foundIndex]?.props : null);
	const details = extractPointDetails(typeId, clickedProps);

	activeDialog.value = {
		typeId,
		proximityKey,
		isCompleted,
		details,
		...INTERACTION_TYPES[typeId],
	};
}

function confirmInteraction() {
	if (!activeDialog.value) return;

	if (activeDialog.value.isCompleted) {
		showFlash("此地點已完成過，無法重複領取 XP！");
		activeDialog.value = null;
		return;
	}

	const gained = activeDialog.value.xp;
	xp.value += gained;
	completionCounts.value[activeDialog.value.typeId] = (completionCounts.value[activeDialog.value.typeId] || 0) + 1;

	if (activeDialog.value.proximityKey) {
		completedProximityKeys.value.add(activeDialog.value.proximityKey);
	}

	showFlash(`+${gained} XP！`, "success");
	persistGameState({ force: true });
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

function getCurrentPosition() {
	if (!navigator.geolocation) {
		const error = new Error("Geolocation is not supported by this browser.");
		error.code = "unsupported";
		return Promise.reject(error);
	}

	return new Promise((resolve, reject) => {
		navigator.geolocation.getCurrentPosition(resolve, reject, {
			enableHighAccuracy: true,
			maximumAge: 0,
			timeout: 10000,
		});
	});
}

function normalizeCenter(position) {
	return [position.coords.longitude, position.coords.latitude];
}

function storeUserLocation([lng, lat], { shouldPersist = true } = {}) {
	lastKnownCenter.value = [lng, lat];
	mapStore.userLocation = {
		latitude: lat,
		longitude: lng,
	};
	if (shouldPersist) {
		persistGameState();
	}
}

function handleLocationError(error, { showPermissionPrompt = true, withFallback = true } = {}) {
	if (error?.code === 1) {
		if (showPermissionPrompt) {
			locationPermissionModal.value = true;
		}
		showFlash("需要定位權限才能以目前位置開始遊戲。");
		return;
	}

	if (error?.code === "unsupported") {
		showFlash("裝置不支援定位功能，已改用預設位置。");
		return;
	}

	if (showPermissionPrompt) {
		locationPermissionModal.value = true;
	}

	if (withFallback) {
		showFlash("目前無法取得定位，已改用預設位置。");
	} else {
		showFlash("目前無法取得定位，請稍後再試。");
	}
}

async function tryGetUserCenter(showPermissionPrompt = true) {
	isRequestingLocation.value = true;
	try {
		const position = await getCurrentPosition();
		const center = normalizeCenter(position);
		storeUserLocation(center);
		locationPermissionModal.value = false;
		return center;
	} catch (error) {
		handleLocationError(error, {
			showPermissionPrompt,
			withFallback: false,
		});
		return null;
	} finally {
		isRequestingLocation.value = false;
	}
}

async function getInitialCenter() {
	const persistedCenter = restoreGameState();
	if (persistedCenter) {
		return persistedCenter;
	}

	isRequestingLocation.value = true;
	try {
		const position = await getCurrentPosition();
		const center = normalizeCenter(position);
		storeUserLocation(center);
		locationPermissionModal.value = false;
		return center;
	} catch (error) {
		handleLocationError(error, {
			showPermissionPrompt: true,
			withFallback: true,
		});
		return [...DEFAULT_START_CENTER];
	} finally {
		isRequestingLocation.value = false;
	}
}

async function requestUserLocation() {
	const center = await tryGetUserCenter(true);
	if (!center || !mapStore.map || !avatar) return;
	avatar.setLngLat(center);
	centerMapOnAvatar(center, { resetBearing: true });
	checkProximity(center);
}

// ─── Avatar Movement ─────────────────────────────────────────────────────────

function centerMapOnAvatar(center, { resetBearing = false } = {}) {
	if (!mapStore.map) return;
	mapStore.map.jumpTo({
		center,
		zoom: 18.4,
		pitch: 60,
		...(resetBearing ? { bearing: 0 } : {}),
	});
}

function moveAvatarFrame(ts) {
	if (!avatar || !mapStore.map) return;
	if (!lastMoveTs) lastMoveTs = ts;
	const deltaSec = Math.min((ts - lastMoveTs) / 1000, 0.05);
	lastMoveTs = ts;

	const { map } = mapStore;
	const horizontal = (heldKeys.has("ArrowRight") ? 1 : 0) - (heldKeys.has("ArrowLeft") ? 1 : 0);
	const vertical = (heldKeys.has("ArrowUp") ? 1 : 0) - (heldKeys.has("ArrowDown") ? 1 : 0);
	const hasInput = horizontal !== 0 || vertical !== 0;

	if (hasInput) {
		if (horizontal < 0) avatar.face("left");
		if (horizontal > 0) avatar.face("right");

		const vecLen = Math.hypot(horizontal, vertical);
		const dirX = horizontal / vecLen;
		const dirY = -(vertical / vecLen); // screen Y is inverted
		const distancePx = MOVE_SPEED_PX_PER_SEC * deltaSec;
		const centerScreen = map.project(map.getCenter());
		const nextLngLat = map.unproject([
			centerScreen.x + dirX * distancePx,
			centerScreen.y + dirY * distancePx,
		]);
		map.setCenter(nextLngLat);
		avatar.setLngLat([nextLngLat.lng, nextLngLat.lat]);
	}

	avatar.setMoving(hasInput);
	const cameraCenter = map.getCenter();
	avatar.setLngLat([cameraCenter.lng, cameraCenter.lat]);
	storeUserLocation([cameraCenter.lng, cameraCenter.lat]);
	checkProximity([cameraCenter.lng, cameraCenter.lat]);

	moveRaf = requestAnimationFrame(moveAvatarFrame);
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

onMounted(async () => {
	const initialCenter = await getInitialCenter();

	mapStore.initializeMapBox("mapbox://styles/mapbox/streets-v12");
	loadLocationData();

	const { map } = mapStore;
	const onLoad = () => {
		map.keyboard.disable();
		applyGameEnvironment(map);
		hideMinorRoadLabels(map);
		hideMapboxPOIs(map);
		centerMapOnAvatar(initialCenter);

		avatar = new AvatarMarker(map, initialCenter);
		avatar.start(); // no-op; animation controlled by setMoving()
		setupPikminLayers(map);

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

		moveRaf = requestAnimationFrame(moveAvatarFrame);
	};

	if (map.loaded()) onLoad();
	else map.once("load", onLoad);

	window.addEventListener("keydown", onKeyDown);
	window.addEventListener("keyup", onKeyUp);
});

onBeforeUnmount(() => {
	window.removeEventListener("keydown", onKeyDown);
	window.removeEventListener("keyup", onKeyUp);
	if (moveRaf)    { cancelAnimationFrame(moveRaf); moveRaf = null; }
	lastMoveTs = 0;
	if (flashTimer) { clearTimeout(flashTimer);  flashTimer = null; }
	if (avatar)     { avatar.destroy();          avatar     = null; }
	if (mapStore.map) {
		mapStore.map.keyboard.enable();
		for (const { event, layer, fn } of mapHandlers) {
			mapStore.map.off(event, layer, fn);
		}
		teardownPikmin(mapStore.map);
	}
	persistGameState({ force: true });
});
</script>

<template>
  <div class="pikmin-view">
    <div
      id="mapboxBox"
      class="pikmin-map"
    />

    <div class="pikmin-hud-top">
      <div class="pikmin-top-main">
        <div class="pikmin-title">
          <span class="pikmin-title-emoji">🌱</span>
          <span>循環經濟探險</span>
        </div>
        <div class="pikmin-actions">
          <button
            class="pikmin-btn"
            :disabled="isRequestingLocation"
            @click="requestUserLocation"
          >
            {{ isRequestingLocation ? "定位中..." : "定位到我" }}
          </button>
        </div>
      </div>
    </div>

    <div class="pikmin-bottom-panels">
      <div class="pikmin-layer-panel">
        <div class="pikmin-hud-label">
          圖層
        </div>
        <div class="pikmin-layer-list">
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
            >x{{ completionCounts[c.id] || 0 }}</span>
          </button>
        </div>
      </div>

      <div class="xp-bar">
        <div class="pikmin-hud-label">
          Level
        </div>
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
          {{ xp }} XP<template v-if="xpLevel.max">
            / {{ xpLevel.max }}
          </template>
        </div>
      </div>
    </div>

    <!-- Nearby location hint (bottom-center) -->
    <transition name="fade">
      <div
        v-if="nearbyInfo && !activeDialog"
        class="nearby-hint"
      >
        <span class="nearby-emoji">{{ nearbyInfo.emoji }}</span>
        <div class="nearby-text">
          <div class="nearby-top-row">
            <span class="nearby-name">{{ nearbyInfo.name }}</span>
            <span
              v-if="nearbyInfo.details?.pointName"
              class="nearby-point-name"
            >{{ nearbyInfo.details.pointName }}</span>
          </div>
          <span
            v-if="nearbyInfo.details?.address"
            class="nearby-address"
          >{{ nearbyInfo.details.address }}</span>
          <span class="nearby-tip">點擊地圖圖標互動</span>
        </div>
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
            <span class="dialog-name">{{ activeDialog.name }}</span>
          </div>
          <div class="dialog-action">
            {{ activeDialog.action }}
          </div>
          <div
            v-if="activeDialog.details"
            class="dialog-details"
          >
            <div
              v-if="activeDialog.details.pointName"
              class="detail-pointname"
            >
              {{ activeDialog.details.pointName }}
            </div>
            <div
              v-if="activeDialog.details.grade"
              class="detail-row"
            >
              🏅 環保認證：{{ activeDialog.details.grade }}
            </div>
            <div
              v-if="activeDialog.details.operator"
              class="detail-row"
            >
              🏢 {{ activeDialog.details.operator }}
            </div>
            <div
              v-if="activeDialog.details.address"
              class="detail-row"
            >
              📍 {{ activeDialog.details.address }}
            </div>
            <div
              v-if="activeDialog.details.phone"
              class="detail-row"
            >
              📞 {{ activeDialog.details.phone }}
            </div>
            <div
              v-if="activeDialog.details.openTime"
              class="detail-row"
            >
              🕐 {{ activeDialog.details.openTime }}
            </div>
            <div
              v-if="activeDialog.details.floorLocation"
              class="detail-row"
            >
              🗺 {{ activeDialog.details.floorLocation }}
            </div>
          </div>
          <div class="dialog-xp">
            <template v-if="activeDialog.isCompleted">
              <span class="completed-text">此地點已完成集點</span>
            </template>
            <template v-else>
              完成可獲得 +{{ activeDialog.xp }} XP
            </template>
          </div>
          <div class="dialog-btns">
            <button
              v-if="!activeDialog.isCompleted"
              class="dialog-btn confirm"
              @click="confirmInteraction"
            >
              是，參與！
            </button>
            <button
              class="dialog-btn cancel"
              @click="cancelInteraction"
            >
              {{ activeDialog.isCompleted ? '關閉' : '暫不參與' }}
            </button>
          </div>
        </div>
      </div>
    </transition>

    <transition name="dialog-fade">
      <div
        v-if="locationPermissionModal && !activeDialog"
        class="dialog-overlay"
      >
        <div class="dialog-box location-dialog">
          <div class="dialog-header">
            <span class="dialog-name">需要定位權限</span>
          </div>
          <div class="dialog-action">
            請允許定位權限，讓小狐狸從你的目前位置開始探險。
          </div>
          <div class="dialog-btns">
            <button
              class="dialog-btn confirm"
              :disabled="isRequestingLocation"
              @click="requestUserLocation"
            >
              {{ isRequestingLocation ? "定位中..." : "重新要求權限" }}
            </button>
            <button
              class="dialog-btn cancel"
              @click="locationPermissionModal = false"
            >
              稍後再說
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
	background: #090909;
}

.pikmin-map {
	width: 100%;
	height: 100%;

	// Hide Mapbox navigation controls (zoom buttons) in game view
	:deep(.mapboxgl-ctrl-group:not(:has(.mapboxgl-ctrl-geolocate))) {
		display: none;
	}
}

.pikmin-hud-top {
	position: absolute;
	top: 16px;
	left: 16px;
	right: 16px;
	z-index: 5;
}

.pikmin-top-main {
	display: flex;
	justify-content: space-between;
	gap: 10px;
	align-items: stretch;
}

.pikmin-bottom-panels {
	position: absolute;
	left: 16px;
	right: 16px;
	bottom: calc(75px + env(safe-area-inset-bottom));
	display: flex;
	gap: 10px;
	align-items: stretch;
	justify-content: space-between;
	z-index: 5;
}

.pikmin-title {
	display: flex;
	align-items: center;
	gap: 8px;
	padding: 10px 14px;
	background: rgba(40, 42, 44, 0.96);
	color: #fff;
	border: 1px solid #494b4e;
	font-weight: 600;
	letter-spacing: 1px;

	&-emoji {
		font-size: 1.1rem;
	}
}

.pikmin-actions {
	display: flex;
	gap: 8px;
}

.pikmin-btn {
	padding: 10px 14px;
	border: 1px solid #494b4e;
	background: rgba(40, 42, 44, 0.96);
	color: #fff;
	cursor: pointer;
	font-size: 0.85rem;
	transition: background 0.15s, border-color 0.15s, color 0.15s;

	&:hover {
		background: rgba(90, 156, 248, 0.15);
		border-color: #5a9cf8;
	}

	&:disabled {
		color: #888787;
		cursor: not-allowed;
		border-color: #353739;
	}
}

.pikmin-hud-label {
	color: #888787;
	font-size: 0.72rem;
	letter-spacing: 1.5px;
	margin-bottom: 6px;
	text-transform: uppercase;
}

.pikmin-layer-panel,
.xp-bar {
	background: rgba(40, 42, 44, 0.96);
	border: 1px solid #494b4e;
	padding: 10px;
}

.pikmin-layer-panel {
	flex: 0 0 auto;
	display: flex;
	flex-direction: column;
	width: fit-content;
	max-width: calc(100% - 270px);
}

.pikmin-layer-list {
	display: flex;
	flex-wrap: wrap;
	gap: 8px;
	width: fit-content;
	max-width: 100%;
}

.pikmin-layer-btn {
	display: flex;
	align-items: center;
	gap: 8px;
	padding: 6px 10px 6px 6px;
	width: fit-content;
	border: 1px solid #494b4e;
	background: rgba(9, 9, 9, 0.4);
	color: #888787;
	cursor: pointer;
	transition: all 0.15s;
	font-size: 0.85rem;

	.dot {
		width: 22px;
		height: 22px;
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
		font-size: 0.72rem;
		padding-left: 2px;
		font-weight: 700;
		letter-spacing: 0.2px;
	}

	&.active {
		color: #fff;
		background: rgba(90, 156, 248, 0.16);
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

.xp-bar {
	flex: 0 0 260px;
	display: flex;
	flex-direction: column;
	justify-content: center;
	text-align: right;
	box-sizing: border-box;
}

.xp-bar .xp-level {
	justify-content: flex-end;
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
	overflow: hidden;
	margin-bottom: 5px;
}

.xp-fill {
	height: 100%;
	background: #5a9cf8;
	transition: width 0.5s cubic-bezier(0.25, 1, 0.5, 1);
}

.xp-text,
.nearby-tip {
	color: #888787;
	font-size: 0.74rem;
}

.nearby-hint {
	position: absolute;
	bottom: calc(190px + env(safe-area-inset-bottom));
	left: 50%;
	transform: translateX(-50%);
	z-index: 5;
	display: flex;
	align-items: flex-start;
	gap: 10px;
	padding: 10px 14px;
	background: rgba(40, 42, 44, 0.96);
	border: 1px solid rgba(90, 156, 248, 0.75);
	color: #fff;
	font-size: 0.88rem;
	pointer-events: none;
	max-width: min(480px, calc(100vw - 32px));
}

.nearby-emoji {
	font-size: 1.15rem;
	flex-shrink: 0;
	margin-top: 1px;
}

.nearby-text {
	display: flex;
	flex-direction: column;
	gap: 2px;
	min-width: 0;
}

.nearby-top-row {
	display: flex;
	align-items: baseline;
	gap: 6px;
	flex-wrap: wrap;
}

.nearby-point-name {
	color: #d0d3d8;
	font-size: 0.85rem;
	font-weight: 500;
}

.nearby-address {
	color: #888787;
	font-size: 0.75rem;
	white-space: nowrap;
	overflow: hidden;
	text-overflow: ellipsis;
	max-width: 100%;
}

.flash-msg {
	position: absolute;
	top: 62px;
	left: 50%;
	transform: translateX(-50%);
	z-index: 10;
	padding: 8px 16px;
	font-size: 0.9rem;
	font-weight: 600;
	pointer-events: none;
	white-space: nowrap;

	&.error {
		background: rgba(150, 34, 34, 0.92);
		color: #fff;
		border: 1px solid rgba(221, 95, 95, 0.6);
	}

	&.success {
		background: rgba(46, 108, 79, 0.92);
		color: #fff;
		border: 1px solid rgba(100, 210, 140, 0.5);
	}
}

.dialog-overlay {
	position: absolute;
	inset: 0;
	z-index: 20;
	display: flex;
	align-items: center;
	justify-content: center;
	background: rgba(0, 0, 0, 0.56);
}

.dialog-box {
	background: rgba(40, 42, 44, 0.98);
	border: 1px solid var(--dialog-color, #5a9cf8);
	padding: 24px;
	min-width: 320px;
	max-width: 380px;
	text-align: center;
}

.location-dialog {
	border-color: #5a9cf8;
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
	margin-bottom: 10px;
}

.dialog-details {
	background: rgba(9, 9, 9, 0.45);
	border: 1px solid #3a3b3e;
	padding: 10px 12px;
	margin-bottom: 14px;
	text-align: left;
	display: flex;
	flex-direction: column;
	gap: 5px;
}

.detail-pointname {
	font-size: 0.95rem;
	font-weight: 600;
	color: #fff;
	margin-bottom: 3px;
}

.detail-row {
	font-size: 0.78rem;
	color: #a8abb0;
	line-height: 1.45;
}

.dialog-xp {
	font-size: 0.85rem;
	color: #ffd700;
	margin-bottom: 22px;

	.completed-text {
		color: #4caf50;
		font-weight: 600;
	}
}

.dialog-btns {
	display: flex;
	gap: 12px;
	justify-content: center;
}

.dialog-btn {
	padding: 9px 18px;
	border: 1px solid transparent;
	cursor: pointer;
	font-size: 0.9rem;
	font-weight: 600;
	transition: background 0.15s, border-color 0.15s, color 0.15s;

	&.confirm {
		background: var(--dialog-color, #5a9cf8);
		color: #fff;
		border-color: var(--dialog-color, #5a9cf8);

		&:hover {
			background: #4c8de8;
		}
	}

	&.cancel {
		background: rgba(9, 9, 9, 0.3);
		color: #888787;
		border-color: #494b4e;

		&:hover {
			background: rgba(255, 255, 255, 0.1);
			color: #fff;
		}
	}

	&:disabled {
		opacity: 0.7;
		cursor: not-allowed;
	}
}

@media (max-width: 1000px) {
	.pikmin-hud-top {
		left: 10px;
		right: 10px;
		top: 10px;
	}

	.pikmin-top-main,
	.pikmin-bottom-panels {
		flex-direction: column;
	}

	.pikmin-bottom-panels {
		left: 10px;
		right: 10px;
		bottom: calc(44px + env(safe-area-inset-bottom));
	}

	.pikmin-actions {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
	}

	.pikmin-layer-panel,
	.pikmin-layer-list {
		width: 100%;
		max-width: none;
	}

	.xp-bar {
		flex: 0 0 auto;
		align-self: flex-end;
		width: min(100%, 280px);
	}

	.dialog-box {
		min-width: 0;
		width: calc(100vw - 24px);
		max-width: 420px;
		max-height: 80vh;
		overflow-y: auto;
	}

	.nearby-hint {
		bottom: calc(280px + env(safe-area-inset-bottom));
		max-width: calc(100vw - 20px);
	}
}

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
		transition: transform 0.2s ease;
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