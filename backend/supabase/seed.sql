-- seed.sql — local demo data only. Never run against production.
-- Demo login (local only): demo@devet.test / demo-password-123

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change, email_change_token_new
) values (
  '00000000-0000-0000-0000-000000000000',
  '11111111-1111-1111-1111-111111111111',
  'authenticated', 'authenticated', 'demo@devet.test',
  extensions.crypt('demo-password-123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}', '{}',
  now(), now(), '', '', '', ''
);

insert into auth.identities (
  id, user_id, provider_id, provider, identity_data,
  last_sign_in_at, created_at, updated_at
) values (
  gen_random_uuid(),
  '11111111-1111-1111-1111-111111111111',
  '11111111-1111-1111-1111-111111111111',
  'email',
  '{"sub":"11111111-1111-1111-1111-111111111111","email":"demo@devet.test","email_verified":true}',
  now(), now(), now()
);

-- profiles row is created by the on_auth_user_created trigger.
update public.profiles
set display_name = 'Demo Ailə'
where id = '11111111-1111-1111-1111-111111111111';

insert into public.templates (id, name, is_premium, version, thumbnail_url, sort_order) values
  ('free-01', '{"az":"Qızıl gecə","ru":"Золотая ночь","en":"Golden Night","tr":"Altın Gece"}', false, 1, '/templates/free-01/thumb.jpg', 10),
  ('free-02', '{"az":"Pudra bağı","ru":"Розовый сад","en":"Blush Garden","tr":"Pudra Bahçesi"}', false, 1, '/templates/free-02/thumb.jpg', 20),
  ('free-03', '{"az":"Buta","ru":"Бута","en":"Buta","tr":"Buta"}', false, 1, '/templates/free-03/thumb.jpg', 30);

insert into public.events (
  id, type, title_names, host_names, starts_at, venue_name, venue_address,
  venue_lat, venue_lng, maps_url, default_lang, template_id, show_tablemates, status
) values (
  '22222222-2222-2222-2222-222222222222',
  'wedding', 'Aysel və Ramin', 'Məmmədovlar və Əliyevlər ailələri',
  '2027-07-10 18:00:00+04', 'Gülüstan sarayı', 'Bakı, Bayıl qəsəbəsi',
  40.3536, 49.8364, 'https://maps.google.com/?q=40.3536,49.8364',
  'az', 'free-01', true, 'active'
);

insert into public.event_members (event_id, user_id, role, side) values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'owner', 'groom');

-- Fixed codes so web tests (T23) can open known invites.
insert into public.guests (
  event_id, code, salutation, name, with_family, invited_count, phone_e164,
  side, table_no, lang, added_by
) values
  ('22222222-2222-2222-2222-222222222222', 'K7D2M9QX', 'muellim', 'Elçin',  true,  4, '+994501234567', 'groom', '12',    null, '11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222', 'P3H8W4ZA', 'xanim',   'Leyla',  false, 1, '+994551112233', 'bride', '12',    null, '11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222', 'R5T6Y7B2', 'bey',     'Rəşad',  true,  3, '+994702223344', 'groom', '12',    'ru', '11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222', 'M9N8V7C6', 'none',    'Aytən',  false, 2, '+994503334455', 'bride', '7',     'en', '11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222', 'Q2W3E4R5', 'xanim',   'Səbinə', true,  5, '+994514445566', 'bride', '7',     'tr', '11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222', 'A1S2D3F4', 'muellim', 'Vüqar',  false, 1, '+994775556677', 'groom', 'VIP-1', null, '11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222', 'G5H6J7K8', 'bey',     'Tural',  false, 2, '+994556667788', 'groom', 'VIP-1', null, '11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222', 'Z9X8C7V6', 'none',    'Nərmin', false, 1, null,            'bride', null,    null, '11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222', 'B4N5M6Q7', 'xanim',   'Günay',  true,  3, '+994508889900', 'none',  '3',     null, '11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222', 'T8Y9W2E3', 'muellim', 'Kamran', false, 1, '+994709990011', 'none',  null,    null, '11111111-1111-1111-1111-111111111111');
