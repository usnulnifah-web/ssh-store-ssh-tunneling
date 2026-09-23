import crypto from 'node:crypto';
import { promises as fs } from 'node:fs';

const enabled = process.env.LICENSE_ENFORCEMENT !== 'false';
const serverUrl = process.env.LICENSE_SERVER_URL;
const apiKey = process.env.LICENSE_API_KEY;
const fingerprint = process.env.LICENSE_FINGERPRINT;
const publicKeyFile = process.env.LICENSE_PUBLIC_KEY_FILE || '/etc/ssh-store-agent/license-public.pem';
const support = process.env.LICENSE_SUPPORT_CONTACT || '081374452477';

function fail(message) { throw new Error(`${message} Silakan pastikan perpanjangan paket ke ${support}.`); }
async function assertLicense() {
  if (!enabled) return;
  if (!serverUrl || !apiKey || !fingerprint) fail('Konfigurasi lisensi belum lengkap.');
  let result;
  try {
    const response = await fetch(`${serverUrl.replace(/\/$/, '')}/v1/check`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-api-key': apiKey }, body: JSON.stringify({ fingerprint }) });
    result = await response.json();
    if (!response.ok || !result.signed) fail(result.message || result.error || 'Lisensi tidak valid.');
    const publicKey = await fs.readFile(publicKeyFile, 'utf8');
    const valid = crypto.verify(null, Buffer.from(result.signed.data), publicKey, Buffer.from(result.signed.signature, 'base64url'));
    if (!valid) fail('Signature lisensi tidak valid.');
    if (result.license.status === 'expired' || Date.parse(result.license.expiresAt) <= Date.now()) fail('Lisensi sudah kadaluarsa.');
  } catch (error) {
    if (error.message.includes('Silakan pastikan')) throw error;
    fail(`License server tidak dapat dihubungi: ${error.message}`);
  }
}

export { assertLicense };
if (process.argv[1] && process.argv[1].endsWith('license-agent-check.js')) {
  await assertLicense();
  console.log('Lisensi SSH Store valid.');
}
