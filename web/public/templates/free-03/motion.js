// free-03: staggered reveal, scroll reveal, twinkling stars, rotating star. Page stays readable without this file.
const reduced = matchMedia('(prefers-reduced-motion: reduce)');

function start() {
  if (reduced.matches) { document.documentElement.dataset.motion = 'reduced'; return; }
  document.documentElement.dataset.motion = 'full';

  document.querySelectorAll('.hero__band svg').forEach((el, i) => el.style.setProperty('--i', String(i)));
  document.querySelectorAll('.hero .reveal').forEach((el, i) => {
    el.style.setProperty('--d', `${0.35 + i * 0.15}s`);
    requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add('in')));
  });
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
  }, { threshold: 0.12, rootMargin: '0px 0px -6% 0px' });
  document.querySelectorAll('.reveal').forEach((el) => { if (!el.closest('.hero')) io.observe(el); });

  const sky = document.querySelector('.stars');
  if (sky && !sky.children.length) {
    for (let i = 0; i < 36; i += 1) {
      const s = document.createElement('i');
      s.style.cssText = `left:${(Math.random() * 100).toFixed(1)}%;top:${(Math.random() * 100).toFixed(1)}%;--s:${(1 + Math.random() * 2.2).toFixed(1)}px;--t:${(2 + Math.random() * 4).toFixed(1)}s;--w:-${(Math.random() * 6).toFixed(1)}s`;
      sky.append(s);
    }
  }
}

document.addEventListener('invite:ready', start);
reduced.addEventListener?.('change', () => { if (reduced.matches) document.documentElement.dataset.motion = 'reduced'; });
document.addEventListener('invite:rsvp', (e) => {
  const sky = document.querySelector('.stars');
  if (e.detail.status !== 'yes' || reduced.matches || !sky) return;
  for (let i = 0; i < 20; i += 1) {
    const s = document.createElement('i');
    s.style.cssText = `left:${(30 + Math.random() * 40).toFixed(1)}%;top:${(30 + Math.random() * 40).toFixed(1)}%;--s:${(2 + Math.random() * 3).toFixed(1)}px;--t:.5s;--w:-${(Math.random() * .5).toFixed(2)}s`;
    sky.append(s);
    setTimeout(() => s.remove(), 4000);
  }
});
