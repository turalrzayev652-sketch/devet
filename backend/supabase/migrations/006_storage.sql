-- 006_storage.sql — Storage buckets and object policies (T15).
--
-- event-media (private): <event_id>/photos/<file>  images, <= 2 MB
--                        <event_id>/music/<file>   audio,  <= 5 MB
--   Only event members read/write. Guests get signed URLs created by the Cloudflare Pages Function
--   with the service role key (decision 2026-10-29; see TASKS.md T24).
-- previews (public):     <guest_code>.jpg          JPEG,   <= 150 KB
--   Public URL read; no listing (codes must not be enumerable). Only members of the guest's event write.
--
-- Bucket file_size_limit is a hard limit enforced by the Storage API. The 2 MB photo limit inside
-- event-media is checked from object metadata when Storage provides it; the app also compresses photos.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('event-media', 'event-media', false, 5242880,
   array['image/jpeg', 'image/png', 'image/webp', 'audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg']),
  ('previews', 'previews', true, 153600, array['image/jpeg'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- Path helpers
-- ---------------------------------------------------------------------------

-- event-media: first folder as event id (null if not a uuid).
create function public.media_event_id(p_name text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_first text := split_part(p_name, '/', 1);
begin
  if v_first ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    return v_first::uuid;
  end if;
  return null;
end;
$$;

-- event-media: is <event_id>/<photos|music>/<file> with a size/type allowed for that folder.
create function public.media_object_allowed(p_name text, p_metadata jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case split_part(p_name, '/', 2)
    when 'photos' then
      coalesce(p_metadata->>'mimetype', 'image/') like 'image/%'
      and coalesce((p_metadata->>'size')::bigint, 0) <= 2097152
    when 'music' then
      coalesce(p_metadata->>'mimetype', 'audio/') like 'audio/%'
      and coalesce((p_metadata->>'size')::bigint, 0) <= 5242880
    else false
  end
  and split_part(p_name, '/', 3) <> ''
  and split_part(p_name, '/', 4) = '';
$$;

-- previews: <CODE>.jpg whose guest belongs to an event the caller is a member of.
create function public.can_write_preview(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_name ~ '^[0-9A-HJKMNP-TV-Z]{8}\.jpg$'
    and exists (
      select 1
      from public.guests g
      join public.event_members m on m.event_id = g.event_id
      where g.code = left(p_name, 8)
        and m.user_id = auth.uid()
    );
$$;

revoke all on function public.media_event_id(text) from public, anon;
revoke all on function public.media_object_allowed(text, jsonb) from public, anon;
revoke all on function public.can_write_preview(text) from public, anon;
grant execute on function public.media_event_id(text) to authenticated;
grant execute on function public.media_object_allowed(text, jsonb) to authenticated;
grant execute on function public.can_write_preview(text) to authenticated;

-- ---------------------------------------------------------------------------
-- event-media policies
-- ---------------------------------------------------------------------------

create policy event_media_select on storage.objects
  for select to authenticated
  using (bucket_id = 'event-media' and public.is_event_member(public.media_event_id(name)));

create policy event_media_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'event-media'
    and public.is_event_member(public.media_event_id(name))
    and public.media_object_allowed(name, metadata)
  );

create policy event_media_update on storage.objects
  for update to authenticated
  using (bucket_id = 'event-media' and public.is_event_member(public.media_event_id(name)))
  with check (
    bucket_id = 'event-media'
    and public.is_event_member(public.media_event_id(name))
    and public.media_object_allowed(name, metadata)
  );

create policy event_media_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'event-media' and public.is_event_member(public.media_event_id(name)));

-- ---------------------------------------------------------------------------
-- previews policies (public read happens through the public URL, not through this table)
-- ---------------------------------------------------------------------------

create policy previews_select_member on storage.objects
  for select to authenticated
  using (bucket_id = 'previews' and public.can_write_preview(name));

create policy previews_insert_member on storage.objects
  for insert to authenticated
  with check (bucket_id = 'previews' and public.can_write_preview(name));

create policy previews_update_member on storage.objects
  for update to authenticated
  using (bucket_id = 'previews' and public.can_write_preview(name))
  with check (bucket_id = 'previews' and public.can_write_preview(name));

create policy previews_delete_member on storage.objects
  for delete to authenticated
  using (bucket_id = 'previews' and public.can_write_preview(name));
