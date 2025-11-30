import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import yaml from 'js-yaml';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, '..', '..', '..');

const composites = [
  {
    name: 'prepare-fixture',
    inputs: ['results-root', 'fixture-path', 'manifest-path'],
    outputs: ['report-json', 'report-markdown', 'manifest-json', 'results-root'],
  },
  {
    name: 'simulate-build',
    inputs: ['results-root'],
    outputs: [
      'results-root',
      'manifest-path',
      'metadata-path',
      'package-version',
      'vip-diff-root',
      'vip-diff-requests-path',
    ],
  },
  {
    name: 'stage-artifacts',
    inputs: ['results-root'],
    outputs: ['results-root', 'packages-path', 'reports-path', 'logs-path', 'summary-json'],
  },
  {
    name: 'prepare-vi-diff',
    inputs: ['report-path', 'baseline-manifest-path', 'output-dir'],
    outputs: ['requests_path', 'request_count', 'has_requests', 'output_dir'],
  },
  {
    name: 'invoke-vi-diff',
    inputs: ['requests-path', 'captures-root', 'summary-path'],
    outputs: ['summary_path', 'captures_root', 'requests_path'],
  },
  {
    name: 'render-vi-report',
    inputs: ['summary-path'],
    outputs: ['report_path'],
  },
];

test('icon-editor composites expose required inputs/outputs', () => {
  for (const composite of composites) {
    const actionPath = join(
      repoRoot,
      '.github',
      'actions',
      'icon-editor',
      composite.name,
      'action.yml',
    );
    const raw = readFileSync(actionPath, 'utf8');
    const action = yaml.load(raw);

    assert.equal(
      action?.runs?.using,
      'composite',
      `Expected composite action for ${composite.name}`,
    );

    for (const inputName of composite.inputs) {
      assert.ok(
        action.inputs?.[inputName],
        `Missing input "${inputName}" in ${composite.name}`,
      );
    }

    for (const outputName of composite.outputs) {
      assert.ok(
        action.outputs?.[outputName],
        `Missing output "${outputName}" in ${composite.name}`,
      );
    }
  }
});
