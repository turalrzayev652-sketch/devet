-- 010_event_status.sql — events.status follows the sending flow (screens.md §15.2, decision 2026-10-30).
-- draft -> active when the first guest gets sent_at. "Archive" (7 days after the event) is computed in the app;
-- the column is not changed for it. Status never goes back to draft.

create function public.activate_event_on_first_send()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.sent_at is not null and (tg_op = 'INSERT' or old.sent_at is null) then
    update public.events set status = 'active' where id = new.event_id and status = 'draft';
  end if;
  return null;
end;
$$;

revoke all on function public.activate_event_on_first_send() from public, anon, authenticated;

create trigger guests_activate_event
  after insert or update of sent_at on public.guests
  for each row execute function public.activate_event_on_first_send();
