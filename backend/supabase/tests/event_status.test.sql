-- Event status tests (migration 010). Run with: supabase test db

begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into public.events (id, type, title_names, starts_at, venue_name, template_id)
values ('cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd', 'birthday', 'Status', now() + interval '20 days', 'Hall', 'free-01');
insert into public.event_members (event_id, user_id, role)
values ('cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd', '11111111-1111-1111-1111-111111111111', 'owner');

select is((select status from public.events where id = 'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd'), 'draft', 'new event is draft');

-- As the signed-in owner, like the app's send flow.
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);

insert into public.guests (event_id, name) values
  ('cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd', 'Status A'),
  ('cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd', 'Status B');
update public.guests set table_no = '1' where name = 'Status A';
select is((select status from public.events where id = 'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd'), 'draft', 'editing guests does not activate');

update public.guests set sent_at = now() where name = 'Status A';
select is((select status from public.events where id = 'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd'), 'active', 'first sent_at activates the event');

update public.guests set sent_at = null where name = 'Status A';
select is((select status from public.events where id = 'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd'), 'active', 'never goes back to draft');

update public.events set status = 'archived' where id = 'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd';
update public.guests set sent_at = now() where name = 'Status B';
select is((select status from public.events where id = 'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd'), 'archived', 'archived is left alone');

select throws_ok($$ select public.activate_event_on_first_send() $$, '42501'::char(5), null::text, 'trigger function not callable by apps');

reset role;
select * from finish();
rollback;
