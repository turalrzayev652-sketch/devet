-- 005_cohost_invite.sql — second family (cohost) invites (T14, spec/PRODUCT.md §2, §5 event_invites).
-- Both RPCs return { ok: true, ... } or { ok: false, error: <code> }.

-- ---------------------------------------------------------------------------
-- create_cohost_invite(event_id, email, side) — owner only
-- Errors: not_owner, invalid_email, cohost_exists
-- ---------------------------------------------------------------------------

create function public.create_cohost_invite(event_id uuid, email text, side public.side)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_email text := lower(btrim(create_cohost_invite.email));
  v_invite public.event_invites;
begin
  if auth.uid() is null or not exists (
    select 1 from public.event_members m
    where m.event_id = create_cohost_invite.event_id and m.user_id = auth.uid() and m.role = 'owner'
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;

  if v_email is null or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    return jsonb_build_object('ok', false, 'error', 'invalid_email');
  end if;

  if exists (
    select 1 from public.event_members m
    where m.event_id = create_cohost_invite.event_id and m.role = 'cohost'
  ) then
    return jsonb_build_object('ok', false, 'error', 'cohost_exists');
  end if;

  -- Only one open invite per event: a new invite replaces earlier unaccepted ones.
  delete from public.event_invites i
  where i.event_id = create_cohost_invite.event_id and i.accepted_at is null;

  insert into public.event_invites (event_id, email, side)
  values (create_cohost_invite.event_id, v_email, coalesce(create_cohost_invite.side, 'none'))
  returning * into v_invite;

  return jsonb_build_object(
    'ok', true,
    'token', v_invite.token,
    'expires_at', v_invite.expires_at
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- accept_cohost_invite(token) — signed-in user whose e-mail matches the invite
-- Errors: not_authenticated, not_found, expired, email_mismatch, already_member, cohost_exists
-- ---------------------------------------------------------------------------

create function public.accept_cohost_invite(token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_user_email text;
  v_invite public.event_invites;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;

  select * into v_invite
  from public.event_invites i
  where i.token = upper(btrim(accept_cohost_invite.token)) and i.accepted_at is null
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  if v_invite.expires_at <= now() then
    return jsonb_build_object('ok', false, 'error', 'expired');
  end if;

  select lower(btrim(u.email)) into v_user_email from auth.users u where u.id = v_uid;
  if v_user_email is distinct from v_invite.email then
    return jsonb_build_object('ok', false, 'error', 'email_mismatch');
  end if;

  if exists (
    select 1 from public.event_members m where m.event_id = v_invite.event_id and m.user_id = v_uid
  ) then
    return jsonb_build_object('ok', false, 'error', 'already_member');
  end if;

  begin
    insert into public.event_members (event_id, user_id, role, side)
    values (v_invite.event_id, v_uid, 'cohost', v_invite.side);
  exception when unique_violation then
    return jsonb_build_object('ok', false, 'error', 'cohost_exists');
  end;

  update public.event_invites set accepted_at = now() where id = v_invite.id;

  return jsonb_build_object('ok', true, 'event_id', v_invite.event_id);
end;
$$;

revoke all on function public.create_cohost_invite(uuid, text, public.side) from public, anon;
revoke all on function public.accept_cohost_invite(text) from public, anon;
grant execute on function public.create_cohost_invite(uuid, text, public.side) to authenticated;
grant execute on function public.accept_cohost_invite(text) to authenticated;
