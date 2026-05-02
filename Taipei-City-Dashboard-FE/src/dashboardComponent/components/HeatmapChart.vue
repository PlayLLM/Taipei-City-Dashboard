<!-- Developed by Taipei Urban Intelligence Center 2023-2024-->

<script setup>
import { computed, ref } from "vue";
import VueApexCharts from "vue3-apexcharts";

const props = defineProps([
	"chart_config",
	"activeChart",
	"series",
	"map_config",
	"map_filter",
	"map_filter_on",
]);

const emits = defineEmits([
	"filterByParam",
	"filterByLayer",
	"clearByParamFilter",
	"clearByLayerFilter",
	"fly",
]);

const heatmapData = computed(() => {
	let output = {};
	let highest = 0;
	let sum = 0;
	if (props.series.length === 1) {
		props.series[0].data.forEach((item) => {
			output[item.x] = item.y;
			if (item.y > highest) {
				highest = item.y;
			}
			sum += item.y;
		});
	} else {
		props.series.forEach((serie) => {
			for (let i = 0; i < props.chart_config.categories.length; i++) {
				if (!output[props.chart_config.categories[i]]) {
					output[props.chart_config.categories[i]] = 0;
				}
				output[props.chart_config.categories[i]] += +serie.data[i];

				if (+serie.data[i] > highest) highest = +serie.data[i];
			}
		});
		sum = Object.values(output).reduce(
			(partialSum, a) => partialSum + a,
			0,
		);
	}

	output.highest = highest;
	output.sum = sum;
	return output;
});

const colorScale = computed(() => {
	const ranges = props.chart_config.color.map((el, index) => ({
		to: Math.floor(
			(heatmapData.value.highest / props.chart_config.color.length) *
				(props.chart_config.color.length - index),
		),
		from:
			Math.floor(
				(heatmapData.value.highest / props.chart_config.color.length) *
					(props.chart_config.color.length - index - 1),
			) + 1,
		color: el,
	}));
	ranges.unshift({
		to: 0,
		from: 0,
		color: "#444444",
	});
	return ranges;
});

const isScrollableHeatmap = computed(() => {
	const categoryCount = props.chart_config.categories?.length || 0;
	return categoryCount >= 20;
});

const rowLabels = computed(() =>
	props.series.map((item) => item.name).reverse(),
);

const chartWidth = computed(() => {
	const categoryCount = props.chart_config.categories?.length || 0;
	const cellWidth = 28;

	if (!isScrollableHeatmap.value) {
		return "100%";
	}

	return `${categoryCount * cellWidth}px`;
});

const chartOptions = computed(() => ({
	chart: {
		stacked: true,
		toolbar: {
			show: false,
		},
	},
	dataLabels: {
		distributed: true,
		style: {
			fontSize: "12px",
			fontWeight: "normal",
		},
	},
	grid: {
		show: false,
	},
	legend: {
		show: false,
	},
	markers: {
		size: 3,
		strokeWidth: 0,
	},
	plotOptions: {
		heatmap: {
			enableShades: false,
			radius: 4,
			colorScale: {
				ranges: colorScale.value,
			},
		},
	},
	stroke: {
		show: true,
		width: 2,
		colors: ["#282a2c"],
	},
	tooltip: {
		custom: function ({ series, seriesIndex, dataPointIndex, w }) {
			// The class "chart-tooltip" could be edited in /assets/styles/chartStyles.css
			return (
				'<div class="chart-tooltip">' +
				"<h6>" +
				`${w.globals.labels[dataPointIndex]}-${props.series[seriesIndex].name}` +
				"</h6>" +
				"<span>" +
				`${series[seriesIndex][dataPointIndex]}` +
				`${props.chart_config.unit}` +
				"</span>" +
				"</div>"
			);
		},
	},
	xaxis: {
		axisBorder: {
			show: false,
		},
		axisTicks: {
			show: false,
		},
		categories: props.chart_config.categories
			? props.chart_config.categories
			: [],
		labels: {
			offsetY: 5,
			formatter: function (value) {
				return value.length > 7 ? value.slice(0, 6) + "..." : value;
			},
		},
		tooltip: {
			enabled: false,
		},
		type: "category",
	},
	yaxis: {
		labels: {
			show: !isScrollableHeatmap.value,
		},
		max: function (max) {
			if (!props.chart_config.categories) {
				return max;
			}
			return heatmapData.value.highest;
		},
	},
}));

const selectedIndex = ref(null);

function handleDataSelection(_e, _chartContext, config) {
	if (!props.map_filter || !props.map_filter_on) {
		return;
	}
	if (
		`${config.dataPointIndex}-${config.seriesIndex}` !== selectedIndex.value
	) {
		// Supports filtering by xAxis + yAxis
		if (props.map_filter.mode === "byParam") {
			emits(
				"filterByParam",
				props.map_filter,
				props.map_config,
				config.w.globals.labels[config.dataPointIndex],
				props.series[config.seriesIndex].name,
			);
		}
		// Supports filtering by xAxis
		else if (props.map_filter.mode === "byLayer") {
			emits(
				"filterByLayer",
				props.map_config,
				config.w.globals.labels[config.dataPointIndex],
			);
		}
		selectedIndex.value = `${config.dataPointIndex}-${config.seriesIndex}`;
	} else {
		if (props.map_filter.mode === "byParam") {
			emits("clearByParamFilter", props.map_config);
		} else if (props.map_filter.mode === "byLayer") {
			emits("clearByLayerFilter", props.map_config);
		}
		selectedIndex.value = null;
	}
}
</script>

<template>
	<div v-if="activeChart === 'HeatmapChart'" class="heatmapchart">
		<div class="heatmapchart-title">
			<h5>總合</h5>
			<h6>{{ heatmapData.sum }} {{ chart_config.unit }}</h6>
		</div>
		<div class="heatmapchart-body">
			<div v-if="isScrollableHeatmap" class="heatmapchart-row-labels">
				<span v-for="label in rowLabels" :key="label" :title="label">
					{{ label }}
				</span>
			</div>
			<div class="heatmapchart-scroll">
				<div class="heatmapchart-chart">
					<VueApexCharts
						:width="chartWidth"
						height="360px"
						type="heatmap"
						:options="chartOptions"
						:series="series"
						@data-point-selection="handleDataSelection"
					/>
				</div>
			</div>
		</div>
	</div>
</template>

<style scoped lang="scss">
.heatmapchart {
	&-body {
		display: flex;
		align-items: stretch;
		gap: 12px;
		width: 100%;
	}

	&-row-labels {
		width: 128px;
		flex: 0 0 70px;
		display: grid;
		grid-auto-rows: 34px;
		margin-top: 26px;
		margin-bottom: 58px;
		color: var(--color-complement-text);
		font-size: 14px;
		font-weight: 600;
		text-align: right;

		span {
			display: flex;
			align-items: center;
			justify-content: flex-start;
			min-width: 0;
			overflow: hidden;
			text-overflow: ellipsis;
			white-space: nowrap;
		}
	}

	&-scroll {
		flex: 1 1 auto;
		min-width: 0;
		width: 100%;
		overflow-x: auto;
		overflow-y: hidden;
		padding-bottom: 4px;
	}

	&-chart {
		width: max-content;
		padding: 0 10px;
	}

	&-title {
		display: flex;
		justify-content: center;
		flex-direction: column;
		margin: -0.2rem 0 -1.5rem;

		h5 {
			margin: 0;
			color: var(--color-complement-text);
		}

		h6 {
			margin: 0;
			color: var(--color-complement-text);
			font-size: var(--font-m);
			font-weight: 400;
		}
	}
}
</style>
