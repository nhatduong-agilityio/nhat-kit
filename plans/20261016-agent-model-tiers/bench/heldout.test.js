// Held-out acceptance tests for the slugify fixture. Cook never sees this file.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { slugify } from '../src/slugify.js';

const cli = (...args) => execFileSync('node', ['src/cli.js', ...args]).toString().trim();

test('diacritics are removed', () => assert.equal(slugify('Crème Brûlée'), 'creme-brulee'));
test('đ becomes d', () => assert.equal(slugify('Đà Nẵng'), 'da-nang'));
test('symbols and spaces collapse, no edge separators', () => assert.equal(slugify('  Hello, World!!  '), 'hello-world'));
test('digits are kept', () => assert.equal(slugify('Version 2.0 Release'), 'version-2-0-release'));
test('empty input', () => assert.equal(slugify(''), ''));
test('all-symbol input', () => assert.equal(slugify('!!! ???'), ''));
test('non-Latin scripts are dropped', () => assert.equal(slugify('Привет world'), 'world'));
test('custom separator', () => assert.equal(slugify('Hello World', { separator: '_' }), 'hello_world'));
test('multi-char separator', () => assert.equal(slugify('a b', { separator: '--' }), 'a--b'));
test('custom separator is trimmed at the edges', () => assert.equal(slugify('  a b  ', { separator: '_' }), 'a_b'));
test('cut at a word boundary', () => assert.equal(slugify('the quick brown fox', { maxLength: 10 }), 'the-quick'));
test('exact fit is not cut', () => assert.equal(slugify('abc def', { maxLength: 7 }), 'abc-def'));
test('first word longer than maxLength is cut', () => assert.equal(slugify('supercalifragilistic word', { maxLength: 5 }), 'super'));
test('default maxLength is 80', () => {
  const s = slugify('word '.repeat(40));
  assert.ok(s.length <= 80, `length ${s.length}`);
  assert.ok(!s.endsWith('-'));
  assert.ok(s.startsWith('word-word'));
});
test('cli --slug', () => assert.equal(cli('--slug', 'Hello', 'World'), 'hello-world'));
test('cli --slug --sep _', () => assert.equal(cli('--slug', '--sep', '_', 'Hello', 'World'), 'hello_world'));
test('cli --slug --max 5', () => assert.equal(cli('--slug', '--max', '5', 'Hello', 'World'), 'hello'));
test('cli without --slug still echoes', () => assert.equal(cli('hi', 'there'), 'hi there'));
