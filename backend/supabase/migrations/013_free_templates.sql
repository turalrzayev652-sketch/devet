-- Free guest-page templates (web/public/templates/free-01..03) replace the seed placeholders. Idempotent.
insert into public.templates (id, name, is_premium, store_product_id, version, thumbnail_url, sort_order) values
  ('free-01', '{"az":"Qızıl gecə","ru":"Золотая ночь","en":"Golden Night","tr":"Altın Gece"}', false, null, 1, '/templates/free-01/thumb.jpg', 10),
  ('free-02', '{"az":"Pudra bağı","ru":"Розовый сад","en":"Blush Garden","tr":"Pudra Bahçesi"}', false, null, 1, '/templates/free-02/thumb.jpg', 20),
  ('free-03', '{"az":"Buta","ru":"Бута","en":"Buta","tr":"Buta"}', false, null, 1, '/templates/free-03/thumb.jpg', 30)
on conflict (id) do update set
  name = excluded.name, is_premium = false, store_product_id = null,
  version = excluded.version, thumbnail_url = excluded.thumbnail_url, sort_order = excluded.sort_order, active = true;
