-- 002_rls.sql — row level security (T11).
-- Guests (anon) get no table access; they only use RPCs (T12).
-- Writes to purchases/templates/app_config are service role only.

-- ---------------------------------------------------------------------------
-- events.created_by: lets the creator read the row back before membership exists
-- ---------------------------------------------------------------------------

alter table public.events
  add column created_by uuid references auth.users (id) on delete set null default auth.uid();

alter table public.guests alter column added_by set default auth.uid();

-- Creator becomes owner automatically.
create function public.add_event_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.created_by is not null then
    insert into public.event_members (event_id, user_id, role)
    values (new.id, new.created_by, 'owner')
    on conflict (event_id, user_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger events_add_owner after insert on public.events
  for each row execute function public.add_event_owner();

-- ---------------------------------------------------------------------------
-- Membership helpers (security definer avoids RLS recursion on event_members)
-- ---------------------------------------------------------------------------

create function public.is_event_member(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.event_members
    where event_id = p_event_id and user_id = auth.uid()
  );
$$;

create function public.is_event_owner(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.event_members
    where event_id = p_event_id and user_id = auth.uid() and role = 'owner'
  );
$$;

revoke all on function public.is_event_member(uuid) from public, anon;
revoke all on function public.is_event_owner(uuid) from public, anon;
grant execute on function public.is_event_member(uuid) to authenticated;
grant execute on function public.is_event_owner(uuid) to authenticated;

-- Code generators are column defaults, so inserting users need EXECUTE. Security definer
-- makes the uniqueness check see all rows, not only those visible under RLS.
alter function public.new_guest_code() security definer;
alter function public.new_invite_token() security definer;
revoke all on function public.new_guest_code() from public, anon;
revoke all on function public.new_invite_token() from public, anon;
grant execute on function public.new_guest_code() to authenticated;
grant execute on function public.new_invite_token() to authenticated;

-- Internal helper, not part of the client API.
revoke all on function public.random_code(int) from public, anon, authenticated;
revoke all on function public.event_guest_limit(uuid) from public, anon;
grant execute on function public.event_guest_limit(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.templates enable row level security;
alter table public.events enable row level security;
alter table public.event_members enable row level security;
alter table public.event_invites enable row level security;
alter table public.purchases enable row level security;
alter table public.guests enable row level security;
alter table public.app_config enable row level security;

-- ---------------------------------------------------------------------------
-- Table privileges (defense in depth on top of RLS)
-- ---------------------------------------------------------------------------

revoke all on all tables in schema public from anon, authenticated;

grant select on public.templates to anon, authenticated;
grant select on public.app_config to authenticated;
grant select on public.purchases to authenticated;
grant select on public.event_members, public.event_invites to authenticated;
grant delete on public.event_members, public.event_invites to authenticated;

grant select, update (display_name, ui_lang) on public.profiles to authenticated;

-- is_paid is set only by verify-purchase (service role).
grant select, delete on public.events to authenticated;
grant insert (type, title_names, host_names, starts_at, venue_name, venue_address,
              venue_lat, venue_lng, maps_url, default_lang, template_id, customization,
              show_tablemates, status, created_by)
  on public.events to authenticated;
grant update (type, title_names, host_names, starts_at, venue_name, venue_address,
              venue_lat, venue_lng, maps_url, default_lang, template_id, customization,
              show_tablemates, status)
  on public.events to authenticated;

-- code is always generated server side; clients cannot choose it.
grant select, delete on public.guests to authenticated;
grant insert (event_id, salutation, name, with_family, invited_count, phone_e164, side,
              table_no, lang, preview_path, sent_at, rsvp_status, rsvp_count, rsvp_at, added_by)
  on public.guests to authenticated;
grant update (salutation, name, with_family, invited_count, phone_e164, side,
              table_no, lang, preview_path, sent_at, rsvp_status, rsvp_count, rsvp_at)
  on public.guests to authenticated;

-- ---------------------------------------------------------------------------
-- Policies
-- ---------------------------------------------------------------------------

-- profiles: only self
create policy profiles_select_self on public.profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_update_self on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- templates: everyone reads, nobody writes
create policy templates_select_all on public.templates
  for select to anon, authenticated using (true);

-- app_config: signed-in users read
create policy app_config_select on public.app_config
  for select to authenticated using (true);

-- events
create policy events_select_member on public.events
  for select to authenticated
  using (public.is_event_member(id) or created_by = auth.uid());
create policy events_insert_self on public.events
  for insert to authenticated
  with check (created_by = auth.uid());
create policy events_update_member on public.events
  for update to authenticated
  using (public.is_event_member(id))
  with check (public.is_event_member(id));
create policy events_delete_owner on public.events
  for delete to authenticated
  using (public.is_event_owner(id));

-- event_members: members see co-members; owner removes cohost. Inserts via trigger/RPC only.
create policy event_members_select on public.event_members
  for select to authenticated using (public.is_event_member(event_id));
create policy event_members_delete_owner on public.event_members
  for delete to authenticated
  using (public.is_event_owner(event_id) and role <> 'owner');

-- event_invites: owner only. Created/accepted via RPC (T14).
create policy event_invites_select_owner on public.event_invites
  for select to authenticated using (public.is_event_owner(event_id));
create policy event_invites_delete_owner on public.event_invites
  for delete to authenticated using (public.is_event_owner(event_id));

-- purchases: read own; writes are service role only
create policy purchases_select_own on public.purchases
  for select to authenticated using (user_id = auth.uid());

-- guests
create policy guests_select_member on public.guests
  for select to authenticated using (public.is_event_member(event_id));
create policy guests_insert_member on public.guests
  for insert to authenticated
  with check (public.is_event_member(event_id) and added_by = auth.uid());
create policy guests_update_member on public.guests
  for update to authenticated
  using (public.is_event_member(event_id))
  with check (public.is_event_member(event_id));
create policy guests_delete_owner on public.guests
  for delete to authenticated
  using (public.is_event_owner(event_id));
