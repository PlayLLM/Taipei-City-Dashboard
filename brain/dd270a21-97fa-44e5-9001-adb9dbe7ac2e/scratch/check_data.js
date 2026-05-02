
import fs from 'fs';

const content = fs.readFileSync('/Users/ncchen/Documents/Taipei-City-Dashboard/db-sample-data/add_reusable_cup_data.sql', 'utf8');

const statsLines = content.match(/INSERT INTO public\.reusable_cup_stats \(district, count, city\) VALUES \('(.*?)', (\d+), '(.*?)'\);/g);
const stats = {};
if (statsLines) {
    statsLines.forEach(line => {
        const m = line.match(/VALUES \('(.*?)', (\d+), '(.*?)'\)/);
        if (m) {
            stats[m[1]] = parseInt(m[2]);
        }
    });
}

const storeLines = content.match(/INSERT INTO public\.reusable_cup_stores \(brand, city, store_name, address, phone, lng, lat, wkb_geometry\) VALUES \('(.*?)', '(.*?)', '(.*?)', '(.*?)', '(.*?)',/g);
// This regex might be too simple if addresses have single quotes. 
// Let's use a more robust approach.

const districtCounts = {};
const lines = content.split('\n');
lines.forEach(line => {
    if (line.startsWith("INSERT INTO public.reusable_cup_stores")) {
        // Extract city and address to find district
        const valuesPart = line.substring(line.indexOf("VALUES") + 6);
        // Simple split by comma is dangerous due to commas in strings.
        // But the format is ('brand', 'city', 'store_name', 'address', 'phone', lng, lat, 'geom')
        const matches = valuesPart.match(/\('(.*?)', '(.*?)', '(.*?)', '(.*?)', '(.*?)', (.*?), (.*?), '(.*?)'\)/);
        if (matches) {
            const city = matches[2];
            const address = matches[4];
            // District is usually after city name in address
            let district = "";
            if (address.includes("區")) {
                const start = address.indexOf(city) === 0 ? city.length : 0;
                const end = address.indexOf("區", start);
                if (end !== -1) {
                    district = address.substring(start, end + 1);
                }
            }
            if (district) {
                districtCounts[district] = (districtCounts[district] || 0) + 1;
            }
        }
    }
});

console.log("Stats in SQL file:");
console.log(JSON.stringify(stats, null, 2));
console.log("\nActual counts calculated from stores in SQL file:");
console.log(JSON.stringify(districtCounts, null, 2));

const mismatches = [];
for (const d in districtCounts) {
    if (stats[d] !== districtCounts[d]) {
        mismatches.push(`${d}: expected ${districtCounts[d]}, found ${stats[d]}`);
    }
}
console.log("\nMismatches:");
console.log(mismatches.join('\n'));
