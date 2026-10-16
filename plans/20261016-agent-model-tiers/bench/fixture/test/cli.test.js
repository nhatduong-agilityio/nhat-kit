import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';

test('cli echoes text', () => {
  assert.equal(execFileSync('node', ['src/cli.js', 'hi there']).toString().trim(), 'hi there');
});
