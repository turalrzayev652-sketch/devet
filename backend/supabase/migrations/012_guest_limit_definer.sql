-- 012_guest_limit_definer.sql — event_guest_limit for apps (found while writing spec/api.md, T31).
-- Before: invoker rights, so a cohost only saw add-ons they bought themselves (purchases RLS = own rows), and
-- config_int was not executable by `authenticated` once new functions stopped being auto-exposed.
-- Now: security definer (all purchases + config), but a signed-in user who is not a member of the event gets null.
-- Server-side callers (record_purchase, the limit trigger, seed) have no auth.uid() and are unaffected.

create or replace function public.event_guest_limit(p_event_id uuid)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select
    case when e.is_paid
      then public.config_int('premium_guest_limit')
      else public.config_int('free_guest_limit')
    end
    + public.config_int('addon_guest_step') * (
      select count(*)::int
      from public.purchases p
      where p.event_id = e.id
        and p.kind = 'limit_addon'
        and p.refunded_at is null
    )
  from public.events e
  where e.id = p_event_id
    and (auth.uid() is null or public.is_event_member(p_event_id));
$$;

revoke all on function public.event_guest_limit(uuid) from public, anon;
grant execute on function public.event_guest_limit(uuid) to authenticated, service_role;
