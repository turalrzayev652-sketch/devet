// free-02: staggered reveal, scroll reveal, falling petals. Page stays fully readable without this file.
const reduced = matchMedia('(prefers-reduced-motion: reduce)');

function petal(layer, burst) {
  const p = document.createElement('i');
  const t = burst ? 3 + Math.random() * 3 : 12 + Math.random() * 12;
  p.style.cssText = `left:${burst ? 30 + Math.random() * 40 : Math.random() * 100}%;--s:${(9 + Math.random() * 10).toFixed(0)}px;--x:${(Math.random() * 140 - 70).toFixed(0)}px;--r:${(Math.random() * 540 - 270).toFixed(0)}deg;--t:${t.toFixed(1)}s;--w:${burst ? 0 : -(Math.random() * 20).toFixed(1)}s`;
  layer.append(p);
  if (burst) setTimeout(() => p.remove(), t * 1000 + 300);
}

function start() {
  if (reduced.matches) { document.documentElement.dataset.motion = 'reduced'; return; }
  document.documentElement.dataset.motion = 'full';

  document.querySelectorAll('.hero .reveal').forEach((el, i) => {
    el.style.setProperty('--d', `${0.5 + i * 0.14}s`);
    requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add('in')));
  });
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
  }, { threshold: 0.12, rootMargin: '0px 0px -6% 0px' });
  document.querySelectorAll('.reveal').forEach((el) => { if (!el.closest('.hero')) io.observe(el); });

  const layer = document.querySelector('.petals');
  if (layer && !layer.children.length) for (let i = 0; i < 14; i += 1) petal(layer, false);
}

document.addEventListener('invite:ready', start);
reduced.addEventListener?.('change', () => { if (reduced.matches) document.documentElement.dataset.motion = 'reduced'; });
document.addEventListener('invite:rsvp', (e) => {
  const layer = document.querySelector('.petals');
  if (e.detail.status !== 'yes' || reduced.matches || !layer) return;
  for (let i = 0; i < 24; i += 1) petal(layer, true);
});
