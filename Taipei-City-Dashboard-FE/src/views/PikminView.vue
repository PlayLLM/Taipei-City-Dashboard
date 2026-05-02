<script setup>
import { onMounted, onBeforeUnmount, ref } from "vue";
import { useMapStore } from "../store/mapStore";
import {
	PIKMIN_COMPONENTS,
	setupPikminLayers,
	setPikminLayerVisibility,
	AvatarMarker,
	applyGameEnvironment,
	teardownPikmin,
} from "../assets/utilityFunctions/pikminGame.js";

const mapStore = useMapStore();

const visible = ref(
	Object.fromEntries(PIKMIN_COMPONENTS.map((c) => [c.id, true])),
);
const components = PIKMIN_COMPONENTS;

let avatar = null;

// Movement step in degrees (~11m per press at Taipei latitude)
const STEP = 0.0001;
// Track which keys are currently held
const heldKeys = new Set();
let moveTimer = null;

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

function moveAvatar() {
	if (!avatar || heldKeys.size === 0) return;
	const pos = avatar.marker.getLngLat();
	let { lng, lat } = pos;
	let moved = false;

	if (heldKeys.has("ArrowUp"))    { lat += STEP; moved = true; }
	if (heldKeys.has("ArrowDown"))  { lat -= STEP; moved = true; }
	if (heldKeys.has("ArrowLeft"))  { lng -= STEP; avatar.face("left");  moved = true; }
	if (heldKeys.has("ArrowRight")) { lng += STEP; avatar.face("right"); moved = true; }

	if (moved) {
		avatar.setLngLat([lng, lat]);
		mapStore.map.easeTo({ center: [lng, lat], duration: 80, easing: (t) => t });
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

onMounted(() => {
	mapStore.initializeMapBox();
	mapStore.setCurrentLocation();

	const {map} = mapStore;
	const onLoad = () => {
		// Disable map's built-in keyboard handler so arrow keys move the avatar instead
		map.keyboard.disable();

		applyGameEnvironment(map);
		map.easeTo({
			center: [121.536609, 25.044808],
			zoom: 16,
			pitch: 60,
			duration: 0,
		});
		setupPikminLayers(map);

		avatar = new AvatarMarker(map, [121.536609, 25.044808]);
		avatar.start();

		// Smooth movement loop at ~30fps
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
	if (moveTimer) { clearInterval(moveTimer); moveTimer = null; }
	if (avatar) {
		avatar.destroy();
		avatar = null;
	}
	if (mapStore.map) {
		mapStore.map.keyboard.enable();
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
      </button>
    </div>
  </div>
</template>

<style scoped lang="scss">
.pikmin-view {
	position: relative;
	width: 100%;
	height: 100%;
	overflow: hidden;
	background: #0b0e1a;
}

.pikmin-map {
	width: 100%;
	height: 100%;
}

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
	background: rgba(11, 14, 26, 0.78);
	color: #fff;
	border-radius: 999px;
	font-weight: 600;
	letter-spacing: 1px;
	backdrop-filter: blur(6px);

	&-emoji {
		font-size: 1.1rem;
	}
}

.pikmin-btn {
	padding: 8px 14px;
	border-radius: 999px;
	border: 1px solid rgba(255, 255, 255, 0.25);
	background: rgba(11, 14, 26, 0.6);
	color: #fff;
	cursor: pointer;
	transition: background 0.15s;
	backdrop-filter: blur(6px);

	&:hover {
		background: rgba(43, 95, 191, 0.7);
	}
}

.pikmin-hud-side {
	position: absolute;
	right: 14px;
	top: 90px;
	display: flex;
	flex-direction: column;
	gap: 8px;
	z-index: 5;
	padding: 12px 10px;
	background: rgba(11, 14, 26, 0.65);
	border-radius: 14px;
	backdrop-filter: blur(8px);

	.pikmin-hud-label {
		color: rgba(255, 255, 255, 0.7);
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
	border: 1px solid rgba(255, 255, 255, 0.15);
	background: rgba(255, 255, 255, 0.06);
	color: rgba(255, 255, 255, 0.55);
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
		opacity: 0.55;
		transition: opacity 0.15s;
	}

	&.active {
		color: #fff;
		background: rgba(255, 255, 255, 0.12);
		border-color: var(--c);

		.dot {
			opacity: 1;
		}
	}

	&:hover .dot {
		opacity: 1;
	}
}
</style>

<style>
.pikmin-avatar img {
	user-select: none;
	-webkit-user-drag: none;
}
</style>
