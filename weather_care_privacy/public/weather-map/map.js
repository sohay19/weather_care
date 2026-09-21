(() => {
  const mapElement = document.getElementById('grid-map');
  const mapStatus = document.getElementById('map-status');
  const search = document.getElementById('region-search');
  const searchResults = document.getElementById('search-results');
  const selectionTitle = document.getElementById('selection-title');
  const selectionSummary = document.getElementById('selection-summary');
  const selectionRegions = document.getElementById('selection-regions');
  const number = new Intl.NumberFormat('ko-KR');
  const koreaCenter = [36.35, 127.85];
  const colors = {
    1: '#d5ebf6',
    2: '#91c9df',
    3: '#4598bf',
    4: '#155978',
  };

  let catalog;
  let naverReady = false;
  let map;
  let gridById = new Map();
  let featureById = new Map();
  let searchItems = [];
  let selectedFeature;
  let loadTimeout;
  let apiPoll;

  function levelFor(count) {
    if (count >= 10) return 4;
    if (count >= 5) return 3;
    if (count >= 2) return 2;
    return 1;
  }

  function showMapError(message) {
    clearTimeout(loadTimeout);
    clearInterval(apiPoll);
    mapStatus.textContent = message;
    mapStatus.hidden = false;
    mapStatus.classList.add('error');
    mapElement.classList.add('map-failed');
  }

  window.navermap_authFailure = () => {
    showMapError('네이버 지도 인증에 실패했습니다. 등록된 웹 서비스 URL을 확인해 주세요.');
  };

  function markNaverReady() {
    if (!window.naver?.maps) return;
    clearInterval(apiPoll);
    naverReady = true;
    startMap();
  }

  window.initNaverWeatherMap = markNaverReady;

  function updateUrl(id) {
    const url = new URL(window.location.href);
    url.searchParams.set('grid', id);
    history.replaceState(null, '', url);
  }

  function updateSelection(grid) {
    selectionTitle.textContent = `nx ${grid.nx} · ny ${grid.ny}`;
    const count = document.createElement('span');
    count.className = 'selection-count';
    count.textContent = `${number.format(grid.count)}개 지역 항목`;
    selectionSummary.replaceChildren(
      count,
      document.createElement('br'),
      '아래 지역들이 같은 기본예보 격자를 사용합니다.',
    );
    selectionRegions.replaceChildren(...grid.regions.map((region) => {
      const row = document.createElement('div');
      row.className = 'region-row';
      row.textContent = region.fullName;
      if (region.code) {
        const code = document.createElement('small');
        code.textContent = `지역 코드 ${region.code}`;
        row.append(code);
      }
      return row;
    }));
  }

  function selectGrid(id, focusMap = false) {
    const grid = gridById.get(id);
    const feature = featureById.get(id);
    if (!grid || !feature || !map) return;

    if (selectedFeature) map.data.revertStyle(selectedFeature);
    selectedFeature = feature;
    map.data.overrideStyle(feature, {
      fillOpacity: 0.7,
      strokeColor: '#f2b544',
      strokeOpacity: 1,
      strokeWeight: 4,
      zIndex: 100,
    });
    updateSelection(grid);
    updateUrl(id);

    if (focusMap) {
      map.setCenter(new naver.maps.LatLng(grid.center[1], grid.center[0]));
      map.setZoom(Math.max(map.getZoom(), 12));
    }
  }

  function closeSearchResults() {
    searchResults.hidden = true;
    searchResults.replaceChildren();
  }

  function showSearchResults() {
    const query = search.value.trim().toLocaleLowerCase('ko-KR');
    if (!query) {
      closeSearchResults();
      return;
    }
    const matches = searchItems.filter((item) =>
      item.region.fullName.toLocaleLowerCase('ko-KR').includes(query)).slice(0, 10);
    if (matches.length === 0) {
      const empty = document.createElement('div');
      empty.className = 'region-row';
      empty.textContent = '일치하는 지역이 없습니다.';
      searchResults.replaceChildren(empty);
      searchResults.hidden = false;
      return;
    }
    searchResults.replaceChildren(...matches.map((item) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.setAttribute('role', 'option');
      button.textContent = item.region.fullName;
      const detail = document.createElement('small');
      detail.textContent = `nx ${item.grid.nx} · ny ${item.grid.ny} · ${number.format(item.grid.count)}개 연결`;
      button.append(detail);
      button.addEventListener('click', () => {
        search.value = item.region.fullName;
        closeSearchResults();
        selectGrid(item.grid.id, true);
      });
      return button;
    }));
    searchResults.hidden = false;
  }

  function gridFeatureCollection(grids) {
    return {
      type: 'FeatureCollection',
      features: grids.map((grid) => ({
        type: 'Feature',
        id: grid.id,
        properties: {
          gridId: grid.id,
          count: grid.count,
          level: levelFor(grid.count),
        },
        geometry: {
          type: 'Polygon',
          coordinates: [grid.polygon],
        },
      })),
    };
  }

  function startMap() {
    if (map || !catalog || !naverReady || !window.naver?.maps) return;
    clearTimeout(loadTimeout);

    map = new naver.maps.Map(mapElement, {
      center: new naver.maps.LatLng(koreaCenter[0], koreaCenter[1]),
      zoom: 7,
      minZoom: 6,
      maxZoom: 18,
      mapTypeId: naver.maps.MapTypeId?.NORMAL ?? 'normal',
      mapTypeControl: true,
      zoomControl: true,
      zoomControlOptions: {
        position: naver.maps.Position.TOP_RIGHT,
      },
    });

    map.data.setStyle((feature) => ({
      fillColor: colors[feature.getProperty('level')],
      fillOpacity: 0.38,
      strokeColor: '#ffffff',
      strokeOpacity: 0.92,
      strokeWeight: 1,
    }));

    const features = map.data.addGeoJson(gridFeatureCollection(catalog.grids));
    featureById = new Map(features.map((feature) => [
      String(feature.getProperty('gridId')),
      feature,
    ]));
    mapElement.dataset.gridCount = String(featureById.size);
    mapElement.dataset.ready = 'true';
    mapStatus.textContent = '';
    mapStatus.hidden = true;

    map.data.addListener('click', (event) => {
      selectGrid(String(event.feature.getProperty('gridId')));
    });
    map.data.addListener('mouseover', (event) => {
      if (event.feature === selectedFeature) return;
      map.data.overrideStyle(event.feature, {
        fillOpacity: 0.62,
        strokeColor: '#155978',
        strokeOpacity: 1,
        strokeWeight: 2,
      });
    });
    map.data.addListener('mouseout', (event) => {
      if (event.feature !== selectedFeature) map.data.revertStyle(event.feature);
    });

    const requested = new URL(window.location.href).searchParams.get('grid');
    if (requested && gridById.has(requested)) selectGrid(requested, true);
  }

  async function loadCatalog() {
    const response = await fetch('/weather-map/data/grid-areas.json', { cache: 'no-cache' });
    if (!response.ok) throw new Error(`grid data ${response.status}`);
    catalog = await response.json();
    gridById = new Map(catalog.grids.map((grid) => [grid.id, grid]));
    searchItems = catalog.grids.flatMap((grid) =>
      grid.regions.map((region) => ({ grid, region })));

    document.getElementById('source-date').textContent =
      `지역 목록 기준 ${catalog.meta.retrievedAt.slice(0, 10)} · ${catalog.meta.source} · 배경 지도 네이버`;
    startMap();
  }

  search.addEventListener('input', showSearchResults);
  search.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeSearchResults();
    if (event.key === 'Enter') {
      const first = searchResults.querySelector('button');
      if (first) {
        event.preventDefault();
        first.click();
      }
    }
  });
  document.addEventListener('click', (event) => {
    if (!event.target.closest('.search-wrap')) closeSearchResults();
  });
  document.getElementById('reset-map').addEventListener('click', () => {
    if (!map) return;
    map.setCenter(new naver.maps.LatLng(koreaCenter[0], koreaCenter[1]));
    map.setZoom(7);
  });

  loadTimeout = setTimeout(() => {
    if (!map) showMapError('네이버 지도를 불러오지 못했습니다. 잠시 뒤 다시 시도해 주세요.');
  }, 12000);
  apiPoll = setInterval(markNaverReady, 100);
  markNaverReady();

  loadCatalog().catch(() => {
    showMapError('예보 격자 데이터를 불러오지 못했습니다. 잠시 뒤 다시 시도해 주세요.');
  });
})();
