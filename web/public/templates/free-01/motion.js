// free-01: staggered reveal, scroll reveal, gold dust. Nothing here is required to read the page.
const reduced = matchMedia('(prefers-reduced-motion: reduce)');

function start() {
  if (reduced.matches) { document.documentElement.dataset.motion = 'reduced'; return; }
  const root = document.documentElement;
  root.dataset.motion = 'full';

  document.querySelectorAll('.hero .reveal').forEach((el, i) => {
    el.style.setProperty('--d', `${0.25 + i * 0.16}s`);
    requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add('in')));
  });

  const io = new IntersectionObserver((entries) => {
    for (const e of entries) if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
  }, { threshold: 0.12, rootMargin: '0px 0px -6% 0px' });
  document.querySelectorAll('.reveal').forEach((el) => { if (!el.closest('.hero')) io.observe(el); });

  const dust = document.querySelector('.dust');
  if (dust && !dust.children.length) {
    for (let i = 0; i < 22; i += 1) {
      const p = document.createElement('i');
      p.style.cssText = `left:${Math.random() * 100}%;--s:${(1.5 + Math.random() * 2.5).toFixed(1)}px;--x:${(Math.random() * 60 - 30).toFixed(0)}px;--t:${(14 + Math.random() * 14).toFixed(1)}s;--w:-${(Math.random() * 20).toFixed(1)}s`;
      dust.append(p);
    }
  }
}

document.addEventListener('invite:ready', start);
reduced.addEventListener?.('change', () => { if (reduced.matches) document.documentElement.dataset.motion = 'reduced'; });
document.addEventListener('invite:rsvp', (e) => {
  if (e.detail.status !== 'yes' || reduced.matches) return;
  const dust = document.querySelector('.dust');
  for (let i = 0; i < 14; i += 1) {
    const p = document.createElement('i');
    p.style.cssText = `left:${35 + Math.random() * 30}%;--s:${(2 + Math.random() * 3).toFixed(1)}px;--x:${(Math.random() * 120 - 60).toFixed(0)}px;--t:${(3 + Math.random() * 3).toFixed(1)}s;--w:0s`;
    dust?.append(p);
    setTimeout(() => p.remove(), 7000);
  }
});
