// POST /functions/v1/delete-account — "Delete account" in Settings (T17, screens.md §15.9).
// Authorization: Bearer <user access token>. No body.
// 200 { ok: true, deleted_events, left_events } | 401 unauthorized | 502 storage_unavailable / delete_failed
//
// Order matters: files first (a failure leaves everything in place and the user can retry), then database rows,
// then the Auth user. Doing it the other way round could leave private photos in Storage with no owner.
import type { Config } from './config.ts';
import type { Fetch } from './google-play.ts';
import { accountDeletionPlan, deleteAccountData, deleteAuthUser, getUserId } from './db.ts';
import { listFiles, removeFiles } from './storage.ts';

export async function deleteAccount(cfg: Config, authorization: string | null, fetchImpl: Fetch): Promise<{ status: number; body: Record<string, unknown> }> {
  const userId = await getUserId(cfg.db, authorization, fetchImpl);
  if (!userId) return { status: 401, body: { ok: false, error: 'unauthorized' } };

  try {
    const plan = await accountDeletionPlan(cfg.db, userId, fetchImpl);
    const media: string[] = [];
    for (const eventId of plan.owned_events) {
      for (const folder of ['photos', 'music']) media.push(...(await listFiles(cfg.db, 'event-media', `${eventId}/${folder}`, fetchImpl)));
    }
    await removeFiles(cfg.db, 'event-media', media, fetchImpl);
    await removeFiles(cfg.db, 'previews', plan.preview_files, fetchImpl);
  } catch (e) {
    console.error('delete-account: storage step failed, nothing deleted', e);
    return { status: 502, body: { ok: false, error: 'storage_unavailable' } };
  }

  try {
    const result = await deleteAccountData(cfg.db, userId, fetchImpl);
    await deleteAuthUser(cfg.db, userId, fetchImpl);
    return { status: 200, body: { ok: true, deleted_events: result.deleted_events, left_events: result.left_events } };
  } catch (e) {
    // Data deletion is idempotent: calling again finishes the job.
    console.error('delete-account: database/auth step failed', e);
    return { status: 502, body: { ok: false, error: 'delete_failed' } };
  }
}
