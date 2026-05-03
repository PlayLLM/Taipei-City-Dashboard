<!-- Developed by Taipei Urban Intelligence Center 2023-2024-->

<!-- This component is mounted programmically by the mapstore. "mapConfig" and "popupContent" are passed in in the mapStore -->
<script setup>
import { onBeforeUnmount, ref } from "vue";

const copiedAddressKey = ref("");
const copyResetTimer = ref(null);

const isAddressItem = (item) => {
	return (
		item?.name === "地址" ||
		item?.key?.toLowerCase().includes("address")
	);
};

const getPopupValue = (content, item) => {
	return content?.properties?.[item.key] ?? "";
};

const copyText = async (text) => {
	if (
		typeof navigator !== "undefined" &&
		navigator.clipboard?.writeText
	) {
		try {
			await navigator.clipboard.writeText(text);
			return;
		} catch {
			// Fall back for browsers or contexts where Clipboard API is blocked.
		}
	}

	const textarea = document.createElement("textarea");
	textarea.value = text;
	textarea.setAttribute("readonly", "");
	textarea.style.position = "fixed";
	textarea.style.opacity = "0";
	document.body.appendChild(textarea);
	textarea.select();
	document.execCommand("copy");
	document.body.removeChild(textarea);
};

const copyAddress = async (value, copyKey) => {
	const text = String(value ?? "").trim();
	if (!text) return;

	await copyText(text);
	copiedAddressKey.value = copyKey;

	if (copyResetTimer.value) {
		clearTimeout(copyResetTimer.value);
	}
	copyResetTimer.value = setTimeout(() => {
		if (copiedAddressKey.value === copyKey) {
			copiedAddressKey.value = "";
		}
	}, 1500);
};

onBeforeUnmount(() => {
	if (copyResetTimer.value) {
		clearTimeout(copyResetTimer.value);
	}
});
</script>

<template>
  <div class="mappopup">
    <div class="mappopup-tab">
      <div
        v-for="(mapConfig, index) in mapConfigs"
        :key="mapConfig.id"
        :class="{ 'mappopup-tab-active': activeTab === index }"
      >
        <button
          @click="
            () => {
              activeTab = index;
            }
          "
        >
          {{
            activeTab === index
              ? mapConfig.title
              : mapConfig.title.length > 5
                ? mapConfig.title.slice(0, 4) + "..."
                : mapConfig.title
          }}
        </button>
      </div>
    </div>
    <div class="mappopup-content">
      <div
        v-for="item in mapConfigs[activeTab].property"
        :key="item.key"
        :style="{
          display: 'flex',
          flexDirection: 'column',
        }"
      >
        <div
          v-if="item.mode === 'video'"
          class="mappopup-video"
        >
          <!-- <h3>{{ item.name }}</h3> -->
          <!-- <p>{{ popupContent[activeTab]?.properties[item.key] }}</p>
          <p>影像載入中...</p>
          <img
            :src="popupContent[activeTab]?.properties[item.key]"
            width="100%"
            height="100%"
          > -->
          <template v-if="popupContent[activeTab]?.properties[item.key].includes('freeway.gov.tw')">
            <img
              width="100%"
              height="100%"
              :src="popupContent[activeTab]?.properties[item.key]"
            >
          </template>
          <template v-else-if="popupContent[activeTab]?.properties[item.key].includes('youtube')">
            <iframe
              :src="popupContent[activeTab]?.properties[item.key]"
              width="100%"
              height="100%"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              referrerpolicy="strict-origin-when-cross-origin"
              allowfullscreen
            />
          </template>
          <template v-else>
            <video
              ref="videoRef"
              width="300"
              height="180"
              controls
              autoplay
              muted
            />
          </template>
        </div>
        <div v-else>
          <h3>{{ item.name }}</h3>
          <p
            :class="{
              'mappopup-address': isAddressItem(item),
            }"
          >
            <span>{{ getPopupValue(popupContent[activeTab], item) }}</span>
            <button
              v-if="isAddressItem(item) && getPopupValue(popupContent[activeTab], item)"
              class="mappopup-address-copy"
              type="button"
              :aria-label="`複製${item.name}`"
              :title="`複製${item.name}`"
              @click="copyAddress(getPopupValue(popupContent[activeTab], item), `${activeTab}-${item.key}`)"
            >
              <svg
                v-if="copiedAddressKey === `${activeTab}-${item.key}`"
                class="mappopup-address-copy-check"
                aria-hidden="true"
                viewBox="0 0 24 24"
              >
                <path
                  d="M9.2 16.6 4.9 12.3 3.5 13.7 9.2 19.4 20.5 8.1 19.1 6.7z"
                  fill="currentColor"
                />
              </svg>
              <svg
                v-else
                aria-hidden="true"
                viewBox="0 0 24 24"
              >
                <path
                  d="M16 1H4C2.9 1 2 1.9 2 3v12h2V3h12V1zm3 4H8C6.9 5 6 5.9 6 7v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"
                  fill="currentColor"
                />
              </svg>
            </button>
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss">
@keyframes easein {
	0% {
		opacity: 0;
	}

	100% {
		opacity: 1;
	}
}

.mapboxgl-popup {
	width: fit-content;
	min-width: 310px !important;
	animation: easein 0.2s linear;
}

.mapboxgl-popup-content {
	padding: 0 !important;
	border: solid 1px var(--color-border);
	box-shadow: 0px 0px 10px rgb(35, 35, 35) !important;
	border-radius: 5px !important;
	background-color: var(--color-component-background) !important;
}

.mapboxgl-popup-anchor-bottom .mapboxgl-popup-tip,
.mapboxgl-popup-anchor-bottom-left .mapboxgl-popup-tip,
.mapboxgl-popup-anchor-bottom-right .mapboxgl-popup-tip {
	border-top-color: var(--color-border) !important;
}

.mapboxgl-popup-anchor-top .mapboxgl-popup-tip,
.mapboxgl-popup-anchor-top-left .mapboxgl-popup-tip,
.mapboxgl-popup-anchor-top-right .mapboxgl-popup-tip {
	border-bottom-color: var(--color-border) !important;
}

.mapboxgl-popup-anchor-left .mapboxgl-popup-tip {
	border-right-color: var(--color-border) !important;
}

.mapboxgl-popup-anchor-right .mapboxgl-popup-tip {
	border-left-color: var(--color-border) !important;
}

.mapboxgl-popup-close-button {
	right: 15px !important;
	top: 10px !important;
	color: var(--color-complement-text);
	font-size: 1.2rem;
	line-height: var(--font-ms);
}

.mappopup {
	max-height: 200px;
	padding: 10px;
	overflow-y: scroll;

	button {
		margin-bottom: 0.5rem;
		color: var(--color-complement-text);
	}

	&-tab {
		display: flex;
		margin-bottom: 0.5rem;

		button {
			margin: 0 4px 0 0;
			padding: 4px 4px;
			border-radius: 5px;
			background-color: rgb(77, 77, 77);
			opacity: 0.6;
			color: var(--color-complement-text);
			font-size: var(--font-s);
			text-align: center;
			transition: color 0.2s, opacity 0.2s;
			user-select: none;

			&:hover {
				opacity: 0.8;
				color: white;
			}
		}

		&-active button {
			opacity: 1;
			color: white;
		}
	}

	&-content {
		width: 100%;

		div {
			display: flex;
		}

		h3 {
			min-width: 100px;
		}

		p {
			text-align: justify;
		}

		.mappopup-address {
			display: inline-flex;
			align-items: center;
			gap: 6px;

			span {
				flex: 1;
			}

			&-copy {
				display: inline-flex;
				flex: 0 0 auto;
				align-items: center;
				justify-content: center;
				width: 20px;
				height: 20px;
				margin: 0;
				padding: 2px;
				border-radius: 4px;
				color: var(--color-complement-text);
				opacity: 0.75;
				transition: color 0.2s, opacity 0.2s, background-color 0.2s;

				&:hover {
					background-color: rgb(77, 77, 77);
					opacity: 1;
				}

				svg {
					width: 16px;
					height: 16px;
				}

				&-check {
					color: #2ecc71;
				}
			}
		}
	}

	&-video {
		position: relative;
		width: min(256px, 100%);
		min-height: 100px;
		aspect-ratio: 16 / 9;
		flex-direction: column;
		align-items: center;
		align-self: center;
		justify-content: center;
		margin: 0 auto;
		margin-top: 5px;
		border-radius: 5px;
		background-color: var(--color-border);

		img {
			width: 100%;
			height: 100%;
			// position: absolute;
			// left: 0;
			// top: 0;
		}
	}
}
</style>
