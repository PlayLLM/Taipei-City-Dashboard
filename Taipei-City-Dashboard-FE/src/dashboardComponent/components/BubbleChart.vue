<!-- Developed by Taipei Urban Intelligence Center 2023-2024-->
<script setup>
import { ref } from "vue";
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

// 標準格式：x_axis, y_axis, z_axis（氣泡大小）
const data = props.series[0]?.data || [];

const chartOptions = ref({
	chart: {
		type: "bubble",
		toolbar: {
			show: false,
		},
		zoom: {
			enabled: false,
		},
	},
	colors: props.chart_config.color || ["#4CAF50", "#2196F3", "#FF9800"],
	dataLabels: {
		enabled: false,
	},
	legend: {
		show: false,
	},
	fill: {
		opacity: 0.8,
	},
	xaxis: {
		title: {
			text: "X 軸",
		},
	},
	yaxis: {
		title: {
			text: "Y 軸",
		},
	},
	tooltip: {
		enabled: true,
		theme: "dark",
		z: {
			title: "大小",
		},
		followCursor: true,
		intersect: true,
	},
	plotOptions: {
		bubble: {
			minBubbleRadius: 5,
			maxBubbleRadius: 50,
		},
	},
});

// 轉換為 ApexCharts bubble chart 格式
const chartSeries = ref([
	{
		data: data.map((item) => ({
			x: parseFloat(item.x_axis || item.x || 0),
			y: parseFloat(item.y_axis || item.y || 0),
			z: parseFloat(item.z_axis || item.data || item.z || 10),
		})),
	},
]);
</script>

<template>
	<div v-if="activeChart === 'BubbleChart'" style="min-height: 250px">
		<VueApexCharts
			width="100%"
			height="250px"
			type="bubble"
			:options="chartOptions"
			:series="chartSeries"
		/>
	</div>
</template>

<style scoped></style>
