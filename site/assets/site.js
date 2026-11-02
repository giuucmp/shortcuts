// Local, click-only illustration. No keyboard listeners, storage or network requests.
const demo = document.querySelector('[data-demo]');
if (demo) {
  const buttons = [...demo.querySelectorAll('[data-modifier]')];
  const rows = [...demo.querySelectorAll('[data-keys]')];
  const status = demo.querySelector('[role="status"]');
  const update = () => {
    const active = buttons.filter(button => button.getAttribute('aria-pressed') === 'true').map(button => button.dataset.modifier);
    let count = 0;
    for (const row of rows) {
      const visible = active.every(key => row.dataset.keys.split(' ').includes(key));
      row.hidden = !visible;
      if (visible) count++;
    }
    status.textContent = count ? demo.dataset.result.replace('{count}', count) : demo.dataset.empty;
  };
  for (const button of buttons) {
    button.addEventListener('click', () => {
      button.setAttribute('aria-pressed', String(button.getAttribute('aria-pressed') !== 'true'));
      update();
    });
  }
  update();
}
for (const image of document.querySelectorAll('[data-app-image]')) {
  const unavailable = () => image.closest('figure').classList.add('asset-pending');
  image.addEventListener('error', unavailable);
  if (image.complete && image.naturalWidth === 0) unavailable();
}
