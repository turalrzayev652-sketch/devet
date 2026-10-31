-- 011_account_deletion.sql — "Delete account" (T17, screens.md §15.9; required by App Store and Google Play).
-- Run by the delete-account Edge Function (service role) in this order:
--   1. account_deletion_plan(user)  -> which events/files will go
--   2. Storage files of those events are removed through the Storage API
--   3. delete_account_data(user)    -> owned events deleted, cohost memberships removed
--   4. auth user deleted (Auth admin API) -> profile and remaining rows follow by FK

-- Purchases a user made as cohost stay with the event (its limit must not drop); the buyer link is cleared.
alter table public.purchases alter column user_id drop not null;
alter table public.purchases drop constraint purchases_user_id_fkey;
alter table public.purchases
  add constraint purchases_user_id_fkey foreign key (user_id) references auth.users (id) on delete set null;

-- { owned_events: [uuid], cohost_events: [uuid], preview_files: ["<CODE>.jpg"] }
create function public.account_deletion_plan(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'owned_events', coalesce((
      select jsonb_agg(m.event_id order by m.event_id)
      from public.event_members m where m.user_id = p_user_id and m.role = 'owner'), '[]'::jsonb),
    'cohost_events', coalesce((
      select jsonb_agg(m.event_id order by m.event_id)
      from public.event_members m where m.user_id = p_user_id and m.role = 'cohost'), '[]'::jsonb),
    'preview_files', coalesce((
      select jsonb_agg(g.code || '.jpg' order by g.code)
      from public.guests g
      join public.event_members m on m.event_id = g.event_id
      where m.user_id = p_user_id and m.role = 'owner'), '[]'::jsonb)
  );
$$;

-- { ok: true, deleted_events: n, left_events: n }
create function public.delete_account_data(p_user_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_deleted int;
  v_left int;
begin
  -- Owned events go completely (guests, members, invites, purchases cascade).
  delete from public.events e
  using public.event_members m
  where m.event_id = e.id and m.user_id = p_user_id and m.role = 'owner';
  get diagnostics v_deleted = row_count;

  delete from public.event_members where user_id = p_user_id;
  get diagnostics v_left = row_count;

  -- Events the user created but no longer owns keep existing without a creator.
  update public.events set created_by = null where created_by = p_user_id;

  return jsonb_build_object('ok', true, 'deleted_events', v_deleted, 'left_events', v_left);
end;
$$;

revoke all on function public.account_deletion_plan(uuid) from public, anon, authenticated;
revoke all on function public.delete_account_data(uuid) from public, anon, authenticated;
grant execute on function public.account_deletion_plan(uuid) to service_role;
grant execute on function public.delete_account_data(uuid) to service_role;
