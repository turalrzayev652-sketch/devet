// Fixture motion: records what invite-core reported, so tests can check reduced-motion handling.
document.addEventListener('invite:ready', (e) => {
  document.documentElement.dataset.motion = e.detail.reducedMotion ? 'reduced' : 'full';
});
document.addEventListener('invite:rsvp', (e) => {
  document.documentElement.dataset.lastRsvp = `${e.detail.status}:${e.detail.count}`;
});
