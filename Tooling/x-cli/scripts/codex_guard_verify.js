const crypto = require('crypto');

const secret = process.env.CODEX_MIRROR_SECRET;
const headSha = process.env.PR_HEAD_SHA;
const body = process.env.PR_BODY || '';

function emit(status, details, provided, expected) {
  const result = {
    check: 'mirror_signature',
    status,
    details,
    provided: (provided || '').trim(),
    expected_prefix: expected ? expected.slice(0, 8) : ''
  };
  console.log(JSON.stringify(result));
}

if (!secret || !headSha || !body) {
  emit('fail', 'missing env', '', secret && headSha ? crypto.createHmac('sha256', secret).update(headSha).digest('hex') : '');
  process.exit(1);
}

const match = body.match(/^Codex-Mirror-Signature:\s*([0-9a-fA-F]{64})$/m);
if (!match) {
  const expected = crypto.createHmac('sha256', secret).update(headSha).digest('hex');
  emit('fail', 'signature not found', '', expected);
  process.exit(1);
}

const provided = match[1];
const expected = crypto.createHmac('sha256', secret).update(headSha).digest('hex');

if (provided.toLowerCase() === expected) {
  emit('pass', 'signature matches', provided, expected);
  process.exit(0);
} else {
  emit('fail', 'signature mismatch', provided, expected);
  process.exit(1);
}
