-- Cohost invite tests (T14). Run after migrations + seed; everything is rolled back.
-- A = seed owner (demo@devet.test), C = invited cohost, D = someone else, B = owner of another event.

begin;

insert into auth.users (id, email) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Cohost@Devet.test'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'd@devet.test'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b@devet.test');

insert into public.events (id, type, title_names, starts_at, venue_name, template_id)
values ('66666666-6666-6666-6666-666666666666', 'birthday', 'B event', now() + interval '30 days', 'Hall', 'free-01');
insert into public.event_members (event_id, user_id, role)
values ('66666666-6666-6666-6666-666666666666', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'owner');

create temp table t_tokens (name text primary key, token text);
grant all on t_tokens to authenticated;

set local role authenticated;

-- C before the invite: sees nothing
select set_config('request.jwt.claim.sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);
do $$ begin
  assert (select count(*) from public.events) = 0, 'C sees no events before invite';
  assert public.create_cohost_invite('22222222-2222-2222-2222-222222222222', 'c@x.test', 'bride')
         = '{"ok":false,"error":"not_owner"}', 'non-member cannot create invite';
end $$;

-- A (owner) creates the invite
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
do $$
declare r jsonb;
begin
  assert public.create_cohost_invite('22222222-2222-2222-2222-222222222222', 'not-an-email', 'bride')
         = '{"ok":false,"error":"invalid_email"}', 'invalid email';
  assert public.create_cohost_invite('66666666-6666-6666-6666-666666666666', 'cohost@devet.test', 'bride')
         = '{"ok":false,"error":"not_owner"}', 'A cannot invite to B''s event';

  r := public.create_cohost_invite('22222222-2222-2222-2222-222222222222', 'first@devet.test', 'bride');
  assert r->>'ok' = 'true', 'first invite created';
  insert into t_tokens values ('replaced', r->>'token');

  r := public.create_cohost_invite('22222222-2222-2222-2222-222222222222', '  COHOST@devet.test ', 'bride');
  assert r->>'ok' = 'true', 'invite created: ' || r::text;
  assert r->>'token' ~ '^[0-9A-HJKMNP-TV-Z]{8}$', 'token format';
  assert (r->>'expires_at')::timestamptz between now() + interval '13 days 23 hours' and now() + interval '14 days 1 hour', '14 day expiry';
  insert into t_tokens values ('main', r->>'token');

  assert (select count(*) from public.event_invites where accepted_at is null) = 1, 'new invite replaces the old one';
  assert (select email from public.event_invites) = 'cohost@devet.test', 'email normalized';
end $$;

-- D (wrong e-mail) cannot accept
select set_config('request.jwt.claim.sub', 'dddddddd-dddd-dddd-dddd-dddddddddddd', true);
do $$ begin
  assert public.accept_cohost_invite((select token from t_tokens where name = 'main'))
         = '{"ok":false,"error":"email_mismatch"}', 'email mismatch';
  assert (select count(*) from public.events) = 0, 'D still sees nothing';
end $$;

-- C accepts
select set_config('request.jwt.claim.sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);
do $$
declare r jsonb;
begin
  assert public.accept_cohost_invite((select token from t_tokens where name = 'replaced'))
         = '{"ok":false,"error":"not_found"}', 'replaced token no longer works';
  assert public.accept_cohost_invite('ZZZZZZZZ') = '{"ok":false,"error":"not_found"}', 'unknown token';

  r := public.accept_cohost_invite(lower((select token from t_tokens where name = 'main')));
  assert r = '{"ok":true,"event_id":"22222222-2222-2222-2222-222222222222"}', 'accept: ' || r::text;

  -- Ready criterion: C sees this event and its guests, not B's event
  assert (select count(*) from public.events) = 1, 'C sees exactly one event';
  assert exists (select 1 from public.events where id = '22222222-2222-2222-2222-222222222222'), 'C sees A''s event';
  assert not exists (select 1 from public.events where id = '66666666-6666-6666-6666-666666666666'), 'C does not see B''s event';
  assert (select count(*) from public.guests) = 10, 'C sees the guests';
  assert (select role::text || '/' || side::text from public.event_members where user_id = auth.uid()) = 'cohost/bride', 'role and side from invite';

  -- Token is single use
  assert public.accept_cohost_invite((select token from t_tokens where name = 'main'))
         = '{"ok":false,"error":"not_found"}', 'token single use';

  -- Cohost cannot invite or delete
  assert public.create_cohost_invite('22222222-2222-2222-2222-222222222222', 'x@devet.test', 'none')
         = '{"ok":false,"error":"not_owner"}', 'cohost cannot invite';
  delete from public.events where id = '22222222-2222-2222-2222-222222222222';
  assert (select count(*) from public.events) = 1, 'cohost cannot delete event';
end $$;

-- Owner cannot add a second cohost
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
do $$ begin
  assert public.create_cohost_invite('22222222-2222-2222-2222-222222222222', 'd@devet.test', 'bride')
         = '{"ok":false,"error":"cohost_exists"}', 'only one cohost';
end $$;

-- Expired invite (B invites D, then the invite is aged)
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
do $$ begin
  insert into t_tokens values ('expired',
    public.create_cohost_invite('66666666-6666-6666-6666-666666666666', 'd@devet.test', 'groom')->>'token');
end $$;
reset role;
update public.event_invites set expires_at = now() - interval '1 minute'
where token = (select token from t_tokens where name = 'expired');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'dddddddd-dddd-dddd-dddd-dddddddddddd', true);
do $$ begin
  assert public.accept_cohost_invite((select token from t_tokens where name = 'expired'))
         = '{"ok":false,"error":"expired"}', 'expired invite';
  assert (select count(*) from public.events) = 0, 'D sees nothing after expired invite';
end $$;

-- Owner accepting own-event invite -> already_member
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
do $$ declare r jsonb; begin
  r := public.create_cohost_invite('66666666-6666-6666-6666-666666666666', 'b@devet.test', 'none');
  assert public.accept_cohost_invite(r->>'token') = '{"ok":false,"error":"already_member"}', 'owner cannot become cohost';
end $$;

-- Not signed in / anon
select set_config('request.jwt.claim.sub', '', true);
do $$ begin
  assert public.accept_cohost_invite('ZZZZZZZZ') = '{"ok":false,"error":"not_authenticated"}', 'no user';
end $$;
reset role;
set local role anon;
do $$
declare denied boolean;
begin
  begin perform public.accept_cohost_invite('ZZZZZZZZ'); denied := false; exception when insufficient_privilege then denied := true; end;
  assert denied, 'anon cannot call accept_cohost_invite';
  begin perform public.create_cohost_invite('22222222-2222-2222-2222-222222222222', 'a@b.cc', 'none'); denied := false; exception when insufficient_privilege then denied := true; end;
  assert denied, 'anon cannot call create_cohost_invite';
end $$;

reset role;
select 'cohost_invite: ALL PASSED' as result;
rollback;
