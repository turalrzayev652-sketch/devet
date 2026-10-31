-- 008_get_preview_venue.sql — get_preview also returns venue_name (T24: og:description "date · venue").
-- Still side-effect free. create or replace keeps the existing grants (anon, authenticated).

create or replace function public.get_preview(code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  g public.guests;
  e public.events;
  v_lang public.lang;
  v_base text;
begin
  select * into g from public.guests where id = public.find_guest_id(get_preview.code);
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  select * into e from public.events where id = g.event_id;
  v_lang := coalesce(g.lang, e.default_lang);
  v_base := (select value #>> '{}' from public.app_config where key = 'storage_public_base_url');

  return jsonb_build_object(
    'ok', true,
    'lang', v_lang,
    'display_name', public.format_display_name(g.name, g.salutation, g.with_family, v_lang),
    'event_type', e.type,
    'title_names', e.title_names,
    'starts_at', e.starts_at,
    'venue_name', e.venue_name,
    'preview_url', case when g.preview_path is not null then v_base || '/' || g.preview_path end,
    'template_id', e.template_id
  );
end;
$$;
