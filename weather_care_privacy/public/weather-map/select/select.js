(() => {
  const confirmButton = document.getElementById('confirm-grid');
  const bridgeStatus = document.getElementById('bridge-status');
  let selectedGrid = window.weatherSelectedGrid;

  function updateSelectedGrid(grid) {
    if (!grid || !Number.isInteger(grid.nx) || !Number.isInteger(grid.ny)) return;
    selectedGrid = grid;
    confirmButton.disabled = false;
    bridgeStatus.textContent = '';
  }

  window.addEventListener('weather-grid-selected', (event) => {
    updateSelectedGrid(event.detail);
  });
  updateSelectedGrid(selectedGrid);

  confirmButton.addEventListener('click', () => {
    if (!selectedGrid) return;
    const bridge = window.WeatherGridSelection;
    if (!bridge || typeof bridge.postMessage !== 'function') {
      bridgeStatus.textContent = '날씨챙겨 앱에서 다시 열어주세요.';
      return;
    }
    confirmButton.disabled = true;
    bridge.postMessage(JSON.stringify({
      type: 'weather-grid-selection',
      gridId: selectedGrid.id,
      nx: selectedGrid.nx,
      ny: selectedGrid.ny,
    }));
    setTimeout(() => {
      confirmButton.disabled = false;
    }, 1200);
  });
})();
