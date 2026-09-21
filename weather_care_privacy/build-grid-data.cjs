const fs = require('node:fs');
const path = require('node:path');

const sourcePath = path.join(
  __dirname,
  '..',
  'weather_care_app',
  'assets',
  'data',
  'kma_regions.json',
);
const outputPath = path.join(
  __dirname,
  'public',
  'weather-map',
  'data',
  'grid-areas.json',
);

const catalog = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const rows = catalog.regions.map(([code, parentCode, name, nx, ny]) => ({
  code,
  parentCode,
  name,
  nx,
  ny,
}));
const byCode = new Map();
for (const row of rows) {
  if (!byCode.has(row.code)) byCode.set(row.code, row);
}

function fullRegionName(row) {
  const names = [row.name];
  const visited = new Set([row.code]);
  let parentCode = row.parentCode;
  while (parentCode && !visited.has(parentCode)) {
    visited.add(parentCode);
    const parent = byCode.get(parentCode);
    if (!parent) break;
    if (parent.name !== names[0]) names.unshift(parent.name);
    parentCode = parent.parentCode;
  }
  return names.join(' ');
}

const groups = new Map();
for (const row of rows) {
  const id = `${row.nx}_${row.ny}`;
  const group = groups.get(id) ?? {
    id,
    nx: row.nx,
    ny: row.ny,
    regions: [],
  };
  group.regions.push({
    code: row.code,
    name: row.name,
    fullName: fullRegionName(row),
  });
  groups.set(id, group);
}

const radians = Math.PI / 180;
const earthRadiusKilometers = 6371.00877;
const gridSpacingKilometers = 5;
const firstStandardParallel = 30 * radians;
const secondStandardParallel = 60 * radians;
const originLongitude = 126 * radians;
const originLatitude = 38 * radians;
const originX = 43;
const originY = 136;
const scaledRadius = earthRadiusKilometers / gridSpacingKilometers;
let cone = Math.tan(Math.PI * 0.25 + secondStandardParallel * 0.5) /
  Math.tan(Math.PI * 0.25 + firstStandardParallel * 0.5);
cone = Math.log(Math.cos(firstStandardParallel) / Math.cos(secondStandardParallel)) /
  Math.log(cone);
let scale = Math.tan(Math.PI * 0.25 + firstStandardParallel * 0.5);
scale = Math.pow(scale, cone) * Math.cos(firstStandardParallel) / cone;
let originRadius = Math.tan(Math.PI * 0.25 + originLatitude * 0.5);
originRadius = scaledRadius * scale / Math.pow(originRadius, cone);

function inverseGrid(x, y) {
  const horizontal = x - originX;
  const vertical = originRadius - y + originY;
  const radius = Math.sqrt(horizontal * horizontal + vertical * vertical);
  const latitude = 2 * Math.atan(Math.pow(
    scaledRadius * scale / radius,
    1 / cone,
  )) - Math.PI * 0.5;
  const angle = Math.atan2(horizontal, vertical);
  return [
    Number(((angle / cone + originLongitude) / radians).toFixed(5)),
    Number((latitude / radians).toFixed(5)),
  ];
}

function cellPolygon(nx, ny) {
  return [
    inverseGrid(nx - 0.5, ny - 0.5),
    inverseGrid(nx + 0.5, ny - 0.5),
    inverseGrid(nx + 0.5, ny + 0.5),
    inverseGrid(nx - 0.5, ny + 0.5),
    inverseGrid(nx - 0.5, ny - 0.5),
  ];
}

const grids = [...groups.values()]
  .map((group) => ({
    ...group,
    count: group.regions.length,
    center: inverseGrid(group.nx, group.ny),
    polygon: cellPolygon(group.nx, group.ny),
    regions: group.regions.sort((left, right) =>
      left.fullName.localeCompare(right.fullName, 'ko')),
  }))
  .sort((left, right) => left.ny - right.ny || left.nx - right.nx);

const counts = grids.map((grid) => grid.count);
const payload = {
  meta: {
    source: catalog.source,
    sourceUrl: catalog.sourceUrl,
    retrievedAt: catalog.retrievedAt,
    regionCount: rows.length,
    gridCount: grids.length,
    sharedGridCount: counts.filter((count) => count >= 2).length,
    maxRegionCount: Math.max(...counts),
  },
  grids,
};

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(payload)}\n`, 'utf8');
console.log(
  `Generated ${grids.length} grids from ${rows.length} region rows: ${outputPath}`,
);
