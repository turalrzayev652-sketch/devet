// Storage API calls with the service role (listing and removing files). Rows in storage.objects must not be deleted
// with SQL: the files themselves would stay in the bucket.
import type { DbConfig } from './db.ts';
import type { Fetch } from './google-play.ts';

const PAGE = 1000;
const DELETE_BATCH = 100;

const headers = (cfg: DbConfig) => ({ apikey: cfg.serviceKey, authorization: `Bearer ${cfg.serviceKey}`, 'content-type': 'application/json' });

// Full paths of the files directly inside `folder` (e.g. "<event_id>/photos").
export async function listFiles(cfg: DbConfig, bucket: string, folder: string, fetchImpl: Fetch): Promise<string[]> {
  const paths: string[] = [];
  for (let offset = 0; ; offset += PAGE) {
    const res = await fetchImpl(`${cfg.url}/storage/v1/object/list/${bucket}`, {
      method: 'POST',
      headers: headers(cfg),
      body: JSON.stringify({ prefix: folder, limit: PAGE, offset }),
    });
    if (!res.ok) throw new Error(`storage list ${bucket}/${folder}: ${res.status}`);
    const items: Array<{ name: string; id: string | null }> = await res.json();
    for (const item of items) if (item.id) paths.push(`${folder}/${item.name}`); // id null = sub-folder
    if (items.length < PAGE) return paths;
  }
}

export async function removeFiles(cfg: DbConfig, bucket: string, paths: string[], fetchImpl: Fetch): Promise<void> {
  for (let i = 0; i < paths.length; i += DELETE_BATCH) {
    const res = await fetchImpl(`${cfg.url}/storage/v1/object/${bucket}`, {
      method: 'DELETE',
      headers: headers(cfg),
      body: JSON.stringify({ prefixes: paths.slice(i, i + DELETE_BATCH) }),
    });
    if (!res.ok) throw new Error(`storage delete ${bucket}: ${res.status}`);
  }
}
