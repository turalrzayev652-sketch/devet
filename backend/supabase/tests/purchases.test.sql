-- Purchase recording tests (T4C). Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

-- Fixtures: premium template, event using it, owner A (seed), cohost C, stranger B.
insert into public.templates (id, name, is_premium, store_product_id, version, sort_order)
values ('premium-01', '{"az":"Premium","ru":"Премиум","en":"Premium","tr":"Premium"}', true, 'template_premium_01', 1, 100),
       ('premium-02', '{"az":"P2","ru":"P2","en":"P2","tr":"P2"}', true, 'template_premium_02', 1, 110);
insert into auth.users (id, email) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b@devet.test'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'c@devet.test');
insert into public.events (id, type, title_names, starts_at, venue_name, template_id)
values ('abababab-abab-abab-abab-abababababab', 'wedding', 'Paid', now() + interval '60 days', 'Hall', 'premium-01');
insert into public.event_members (event_id, user_id, role) values
  ('abababab-abab-abab-abab-abababababab', '11111111-1111-1111-1111-111111111111', 'owner'),
  ('abababab-abab-abab-abab-abababababab', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'cohost');

-- Template purchase
select is(public.record_purchase('11111111-1111-1111-1111-111111111111', 'abababab-abab-abab-abab-abababababab', 'template_premium_01', 'google', 'GPA.1111')->>'status',
  'created', 'template purchase recorded');
select is((select is_paid from public.events where id = 'abababab-abab-abab-abab-abababababab'), true, 'event unlocked');
select is(public.event_guest_limit('abababab-abab-abab-abab-abababababab'), 300, 'premium limit 300');

-- Idempotency
select is(public.record_purchase('11111111-1111-1111-1111-111111111111', 'abababab-abab-abab-abab-abababababab', 'template_premium_01', 'google', 'GPA.1111')->>'status',
  'already_recorded', 'same transaction twice is not counted twice');
select is((select count(*)::int from public.purchases where store_transaction_id = 'GPA.1111'), 1, 'one purchase row');

-- Limit add-on by cohost (cohost may buy, PRODUCT.md §2)
select is(public.record_purchase('cccccccc-cccc-cccc-cccc-cccccccccccc', 'abababab-abab-abab-abab-abababababab', 'limit_addon_200', 'apple', '2000000001')->>'guest_limit',
  '500', 'add-on raises limit to 500');
select is(public.record_purchase('cccccccc-cccc-cccc-cccc-cccccccccccc', 'abababab-abab-abab-abab-abababababab', 'limit_addon_200', 'apple', '2000000001')->>'guest_limit',
  '500', 'repeated add-on transaction does not raise again');
select is((public.record_purchase('cccccccc-cccc-cccc-cccc-cccccccccccc', 'abababab-abab-abab-abab-abababababab', 'limit_addon_200', 'apple', '2000000002')->>'guest_limit')::int,
  700, 'second add-on transaction -> 700');

-- Rejections
select is(public.record_purchase('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'abababab-abab-abab-abab-abababababab', 'limit_addon_200', 'google', 'GPA.2222')->>'error',
  'not_member', 'stranger cannot buy for the event');
select is(public.record_purchase('11111111-1111-1111-1111-111111111111', 'abababab-abab-abab-abab-abababababab', 'template_unknown', 'google', 'GPA.3333')->>'error',
  'unknown_product', 'unknown product');
select is(public.record_purchase('11111111-1111-1111-1111-111111111111', 'abababab-abab-abab-abab-abababababab', 'template_premium_02', 'google', 'GPA.4444')->>'error',
  'template_mismatch', 'template must be the event''s template');
select is(public.record_purchase('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'limit_addon_200', 'google', 'GPA.1111')->>'error',
  'transaction_used', 'a transaction cannot be reused for another event');
select is(public.record_purchase('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'limit_addon_200', 'google', 'GPA.5555')->>'error',
  'not_member', 'unknown event');
select is((select count(*)::int from public.purchases where store_transaction_id in ('GPA.2222', 'GPA.3333', 'GPA.4444', 'GPA.5555')), 0, 'rejected purchases leave no rows');

-- Refunds
select is(public.record_refund('apple', '2000000002')->>'guest_limit', '500', 'refunded add-on drops the limit');
select is(public.record_refund('apple', '2000000002')->>'status', 'already_refunded', 'refund is idempotent');
select is(public.record_refund('google', '2000000001')->>'error', 'not_found', 'refund matches store and transaction');
select is(public.record_refund('google', 'GPA.1111')->>'is_paid', 'false', 'refunded template locks the event again');
select is(public.event_guest_limit('abababab-abab-abab-abab-abababababab'), 300, 'free 100 + one active add-on 200');
select is(public.record_purchase('11111111-1111-1111-1111-111111111111', 'abababab-abab-abab-abab-abababababab', 'template_premium_01', 'google', 'GPA.1111')->>'error',
  'refunded', 'a refunded transaction cannot be re-activated');
select is(public.record_purchase('11111111-1111-1111-1111-111111111111', 'abababab-abab-abab-abab-abababababab', 'template_premium_01', 'google', 'GPA.6666')->>'is_paid',
  'true', 'a new purchase unlocks again');

-- Only the service role may call these
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select throws_ok($$ select public.record_purchase('11111111-1111-1111-1111-111111111111', 'abababab-abab-abab-abab-abababababab', 'limit_addon_200', 'google', 'GPA.7777') $$,
  '42501'::char(5), null::text, 'apps cannot record purchases directly');
select throws_ok($$ select public.record_refund('google', 'GPA.6666') $$, '42501'::char(5), null::text, 'apps cannot record refunds');
reset role;
set local role anon;
select throws_ok($$ select public.record_purchase('11111111-1111-1111-1111-111111111111', 'abababab-abab-abab-abab-abababababab', 'limit_addon_200', 'google', 'GPA.8888') $$,
  '42501'::char(5), null::text, 'guests cannot record purchases');
reset role;

select * from finish();
rollback;
