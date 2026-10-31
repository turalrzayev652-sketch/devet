// App Store Server API (Get Transaction Info) with an App Store Connect API key.
import { decodeJwsPayload, importEcPrivateKey, signJwt } from './jwt.ts';
import { StoreError, type Fetch } from './google-play.ts';

export interface AppleConfig {
  bundleId: string;
  issuerId: string;
  keyId: string;
  privateKey: string;
  // App Review and TestFlight purchase in the sandbox, so production usually has to accept it (see README).
  allowSandbox: boolean;
}

export interface AppleTransaction {
  transactionId: string;
  originalTransactionId?: string;
  bundleId: string;
  productId: string;
  appAccountToken?: string;
  revocationDate?: number;
  price?: number;      // milli-units: 19990 = 19.99
  currency?: string;
  environment?: 'Production' | 'Sandbox';
}

const HOSTS = {
  Production: 'https://api.storekit.itunes.apple.com',
  Sandbox: 'https://api.storekit-sandbox.itunes.apple.com',
};

export async function appleAuthToken(cfg: AppleConfig, now = Date.now()): Promise<string> {
  const iat = Math.floor(now / 1000);
  return signJwt(
    { alg: 'ES256', kid: cfg.keyId, typ: 'JWT' },
    { iss: cfg.issuerId, iat, exp: iat + 20 * 60, aud: 'appstoreconnect-v1', bid: cfg.bundleId },
    await importEcPrivateKey(cfg.privateKey),
  );
}

// Returns the transaction decoded from Apple's signedTransactionInfo, or null if Apple does not know it.
// The JWS comes straight from Apple's API over TLS with our credentials, so its signature is not re-checked here.
export async function getTransaction(cfg: AppleConfig, transactionId: string, fetchImpl: Fetch): Promise<AppleTransaction | null> {
  if (!/^\d{1,30}$/.test(transactionId)) return null;
  const token = await appleAuthToken(cfg);
  const environments: Array<keyof typeof HOSTS> = cfg.allowSandbox ? ['Production', 'Sandbox'] : ['Production'];
  for (const env of environments) {
    const res = await fetchImpl(`${HOSTS[env]}/inApps/v1/transactions/${transactionId}`, {
      headers: { authorization: `Bearer ${token}` },
    });
    if (res.status === 404) continue; // try the sandbox (Apple's recommended order)
    if (!res.ok) throw new StoreError('store_unavailable', `apple ${env} ${res.status}`);
    const { signedTransactionInfo } = await res.json();
    const tx = decodeJwsPayload<AppleTransaction>(signedTransactionInfo);
    return { ...tx, environment: tx.environment ?? env };
  }
  return null;
}

export function checkAppleTransaction(
  tx: AppleTransaction,
  expected: { transactionId: string; productId: string; bundleId: string; userId: string; allowSandbox: boolean },
): { ok: true } | { ok: false; error: string } {
  if (String(tx.transactionId) !== expected.transactionId) return { ok: false, error: 'purchase_mismatch' };
  if (tx.bundleId !== expected.bundleId || tx.productId !== expected.productId) return { ok: false, error: 'purchase_mismatch' };
  if (tx.environment === 'Sandbox' && !expected.allowSandbox) return { ok: false, error: 'test_purchase_not_allowed' };
  if (tx.revocationDate) return { ok: false, error: 'revoked' };
  // The app sets appAccountToken = user id when purchasing (StoreKit 2 .appAccountToken).
  if (tx.appAccountToken && tx.appAccountToken.toLowerCase() !== expected.userId.toLowerCase()) return { ok: false, error: 'purchase_mismatch' };
  return { ok: true };
}

// 19990 milli-units -> 1999 minor units (cents / qəpik).
export const appleAmountMinor = (price?: number) => (typeof price === 'number' ? Math.round(price / 10) : null);
