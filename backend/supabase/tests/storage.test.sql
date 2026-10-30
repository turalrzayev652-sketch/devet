-- Storage permission tests (T15). Run after migrations + seed; everything is rolled back.
-- Simulates Storage API writes as rows in storage.objects (RLS is what the API enforces).
-- A = seed owner (event 2222…), B = stranger.

begin;
create extension if not exists pgtap with schema extensions;
select plan(1);

insert into auth.users (id, email) values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b@devet.test');

-- Buckets and hard limits
do $$ begin
  assert (select public from storage.buckets where id = 'event-media') = false, 'event-media is private';
  assert (select file_size_limit from storage.buckets where id = 'event-media') = 5242880, 'event-media 5 MB';
  assert (select public from storage.buckets where id = 'previews') = true, 'previews is public';
  assert (select file_size_limit from storage.buckets where id = 'previews') = 153600, 'previews 150 KB';
  assert (select allowed_mime_types from storage.buckets where id = 'previews') = array['image/jpeg'], 'previews jpeg only';
end $$;

create temp table t_result (name text primary key, ok boolean);
grant all on t_result to authenticated, anon;

create function pg_temp.try_insert(p_bucket text, p_name text, p_meta jsonb) returns boolean language plpgsql as $$
begin
  insert into storage.objects (bucket_id, name, metadata) values (p_bucket, p_name, p_meta);
  return true;
exception when insufficient_privilege then
  return false;
end $$;
grant execute on function pg_temp.try_insert(text, text, jsonb) to anon, authenticated;

set local role authenticated;

-- Owner A
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
do $$
declare ev constant text := '22222222-2222-2222-2222-222222222222';
begin
  assert pg_temp.try_insert('event-media', ev || '/photos/a.jpg', '{"mimetype":"image/jpeg","size":1500000}'), 'member uploads photo';
  assert pg_temp.try_insert('event-media', ev || '/music/song.mp3', '{"mimetype":"audio/mpeg","size":4900000}'), 'member uploads music';
  assert not pg_temp.try_insert('event-media', ev || '/photos/big.jpg', '{"mimetype":"image/jpeg","size":2200000}'), 'photo > 2 MB rejected';
  assert not pg_temp.try_insert('event-media', ev || '/photos/x.mp3', '{"mimetype":"audio/mpeg","size":1000}'), 'audio in photos rejected';
  assert not pg_temp.try_insert('event-media', ev || '/music/x.jpg', '{"mimetype":"image/jpeg","size":1000}'), 'image in music rejected';
  assert not pg_temp.try_insert('event-media', ev || '/other/x.jpg', '{"mimetype":"image/jpeg","size":1000}'), 'unknown folder rejected';
  assert not pg_temp.try_insert('event-media', ev || '/photos/sub/x.jpg', '{"mimetype":"image/jpeg","size":1000}'), 'nested path rejected';
  assert not pg_temp.try_insert('event-media', 'not-a-uuid/photos/x.jpg', '{"mimetype":"image/jpeg","size":1000}'), 'bad event folder rejected';
  assert not pg_temp.try_insert('event-media', '66666666-6666-6666-6666-666666666666/photos/x.jpg', '{"mimetype":"image/jpeg","size":1000}'), 'non-member event rejected';

  assert pg_temp.try_insert('previews', 'K7D2M9QX.jpg', '{"mimetype":"image/jpeg","size":60000}'), 'member uploads preview';
  assert not pg_temp.try_insert('previews', 'ZZZZZZZZ.jpg', '{"mimetype":"image/jpeg","size":60000}'), 'preview for unknown code rejected';
  assert not pg_temp.try_insert('previews', 'k7d2m9qx.jpg', '{"mimetype":"image/jpeg","size":60000}'), 'preview name must be exact code';
  assert not pg_temp.try_insert('previews', 'x/K7D2M9QX.jpg', '{"mimetype":"image/jpeg","size":60000}'), 'preview must be at bucket root';

  assert (select count(*) from storage.objects) = 3, 'A sees own 3 objects';
end $$;

-- Stranger B
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
do $$
declare ev constant text := '22222222-2222-2222-2222-222222222222'; n int;
begin
  assert (select count(*) from storage.objects) = 0, 'B sees no objects of A';
  assert not pg_temp.try_insert('event-media', ev || '/photos/b.jpg', '{"mimetype":"image/jpeg","size":1000}'), 'B cannot upload to A event';
  assert not pg_temp.try_insert('previews', 'P3H8W4ZA.jpg', '{"mimetype":"image/jpeg","size":1000}'), 'B cannot write A previews';
  update storage.objects set metadata = '{}' where true;
  get diagnostics n = row_count;
  assert n = 0, 'B cannot overwrite A objects';
  delete from storage.objects where true;
  get diagnostics n = row_count;
  assert n = 0, 'B cannot delete A objects';
end $$;

-- Cohost can write media too
reset role;
insert into public.event_members (event_id, user_id, role, side)
values ('22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'cohost', 'bride');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
do $$ begin
  assert pg_temp.try_insert('event-media', '22222222-2222-2222-2222-222222222222/photos/c.jpg', '{"mimetype":"image/png","size":1000}'), 'cohost uploads photo';
  assert pg_temp.try_insert('previews', 'P3H8W4ZA.jpg', '{"mimetype":"image/jpeg","size":1000}'), 'cohost writes preview';
end $$;

-- anon: no listing of either bucket (public preview URLs bypass this table)
reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$ begin
  assert (select count(*) from storage.objects) = 0, 'anon cannot list objects';
  assert not pg_temp.try_insert('previews', 'M9N8V7C6.jpg', '{"mimetype":"image/jpeg","size":1000}'), 'anon cannot upload';
end $$;

reset role;
select pass('storage: all assertions passed');
select * from finish();
rollback;
