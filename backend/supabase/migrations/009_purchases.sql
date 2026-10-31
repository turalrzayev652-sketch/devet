-- 009_purchases.sql — server side of in-app purchases (T4C, PRODUCT.md §5 purchases, §7).
-- Called only by the verify-purchase / store-notifications Edge Functions (service role) after the store
-- (Google Play / App Store) has confirmed the transaction. Never callable by apps or guests.

insert into public.app_config (key, value) values
  ('limit_addon_product_id', '"limit_addon_200"')
on conflict (key) do nothing;

-- New tables/functions are not auto-exposed to API roles (config.toml), so the service role needs explicit grants
-- for what the Edge Functions read: guests/events for signed media URLs (T24).
grant select on public.guests, public.events to service_role;

-- ---------------------------------------------------------------------------
-- record_purchase — idempotent on store_transaction_id
-- ---------------------------------------------------------------------------
-- Returns { ok: true, status: 'created' | 'already_recorded', kind, is_paid, guest_limit }
--      or { ok: false, error: 'not_member' | 'unknown_product' | 'template_mismatch' | 'transaction_used' | 'refunded' }

create function public.record_purchase(
  p_user_id uuid,
  p_event_id uuid,
  p_product_id text,
  p_store public.store,
  p_transaction_id text,
  p_amount_minor int default null,
  p_currency text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_event public.events;
  v_kind public.purchase_kind;
  v_template_id text;
  v_existing public.purchases;
  v_status text := 'created';
begin
  if p_transaction_id is null or btrim(p_transaction_id) = '' then
    raise exception 'transaction id required';
  end if;

  -- Serializes purchases for the same event (is_paid / limit stay consistent).
  select * into v_event from public.events where id = p_event_id for update;
  if not found or not exists (
    select 1 from public.event_members m where m.event_id = p_event_id and m.user_id = p_user_id
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_member');
  end if;

  if p_product_id = (select value #>> '{}' from public.app_config where key = 'limit_addon_product_id') then
    v_kind := 'limit_addon';
  else
    select t.id into v_template_id
    from public.templates t
    where t.store_product_id = p_product_id and t.is_premium;
    if v_template_id is null then
      return jsonb_build_object('ok', false, 'error', 'unknown_product');
    end if;
    -- A paid template is bought for one event and must be the event's chosen template.
    if v_event.template_id is distinct from v_template_id then
      return jsonb_build_object('ok', false, 'error', 'template_mismatch');
    end if;
    v_kind := 'template';
  end if;

  insert into public.purchases (user_id, event_id, kind, template_id, store, store_transaction_id, amount_minor, currency)
  values (p_user_id, p_event_id, v_kind, v_template_id, p_store, p_transaction_id, p_amount_minor, p_currency)
  on conflict (store_transaction_id) do nothing;

  if not found then
    select * into v_existing from public.purchases where store_transaction_id = p_transaction_id;
    if v_existing.event_id <> p_event_id or v_existing.user_id <> p_user_id or v_existing.store <> p_store then
      return jsonb_build_object('ok', false, 'error', 'transaction_used');
    end if;
    if v_existing.refunded_at is not null then
      return jsonb_build_object('ok', false, 'error', 'refunded');
    end if;
    v_status := 'already_recorded';
  end if;

  if v_kind = 'template' then
    update public.events set is_paid = true where id = p_event_id and not is_paid;
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', v_status,
    'kind', v_kind,
    'is_paid', (select is_paid from public.events where id = p_event_id),
    'guest_limit', public.event_guest_limit(p_event_id)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- record_refund — after the store confirmed a refund / revocation
-- ---------------------------------------------------------------------------
-- Returns { ok: true, status: 'refunded' | 'already_refunded', event_id, is_paid, guest_limit }
--      or { ok: false, error: 'not_found' }
-- Existing guests are kept when the limit drops (T13): only new guests are blocked.

create function public.record_refund(p_store public.store, p_transaction_id text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_purchase public.purchases;
  v_status text := 'refunded';
begin
  select * into v_purchase
  from public.purchases
  where store = p_store and store_transaction_id = p_transaction_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  perform 1 from public.events where id = v_purchase.event_id for update;

  if v_purchase.refunded_at is null then
    update public.purchases set refunded_at = now() where id = v_purchase.id;
  else
    v_status := 'already_refunded';
  end if;

  if v_purchase.kind = 'template' then
    update public.events e
    set is_paid = exists (
      select 1 from public.purchases p
      where p.event_id = e.id and p.kind = 'template' and p.refunded_at is null and p.template_id = e.template_id
    )
    where e.id = v_purchase.event_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', v_status,
    'event_id', v_purchase.event_id,
    'is_paid', (select is_paid from public.events where id = v_purchase.event_id),
    'guest_limit', public.event_guest_limit(v_purchase.event_id)
  );
end;
$$;

revoke all on function public.record_purchase(uuid, uuid, text, public.store, text, int, text) from public, anon, authenticated;
revoke all on function public.record_refund(public.store, text) from public, anon, authenticated;
grant execute on function public.record_purchase(uuid, uuid, text, public.store, text, int, text) to service_role;
grant execute on function public.record_refund(public.store, text) to service_role;
