const assert = require('assert');
const { spawnSync } = require('child_process');
const crypto = require('crypto');
const path = require('path');

const script = path.resolve(__dirname, '../../scripts/codex_guard_verify.js');
const TEST_SECRET = 'test_secret';
const SHA = '1234567890abcdef';
const expected = crypto.createHmac('sha256', TEST_SECRET).update(SHA).digest('hex');

function run(body) {
  return spawnSync('node', [script], {
    env: { ...process.env, CODEX_MIRROR_SECRET: TEST_SECRET, PR_HEAD_SHA: SHA, PR_BODY: body },
    encoding: 'utf8'
  });
}

// pass case
{
  const body = `Intro\nCodex-Mirror-Signature: ${expected}\nOutro`;
  const res = run(body);
  assert.strictEqual(res.status, 0, res.stdout + res.stderr);
  const json = JSON.parse(res.stdout.trim());
  assert.strictEqual(json.status, 'pass');
  assert.strictEqual(json.provided, expected);
}

// wrong signature
{
  const body = 'Codex-Mirror-Signature: ' + '0'.repeat(64);
  const res = run(body);
  assert.notStrictEqual(res.status, 0);
  const json = JSON.parse(res.stdout.trim());
  assert.strictEqual(json.status, 'fail');
}

// missing token
{
  const body = 'no signature here';
  const res = run(body);
  assert.notStrictEqual(res.status, 0);
  const json = JSON.parse(res.stdout.trim());
  assert.strictEqual(json.status, 'fail');
}
