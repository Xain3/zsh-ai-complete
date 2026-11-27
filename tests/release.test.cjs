'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { validateRelease } = require('../scripts/check-release.cjs');

test('accepts matching stable and prerelease tags', () => {
  assert.deepEqual(validateRelease('1.2.3', 'v1.2.3'), { prerelease: false });
  assert.deepEqual(validateRelease('1.2.3-beta.1', 'v1.2.3-beta.1'), { prerelease: true });
  assert.deepEqual(validateRelease('1.2.3+build.01', 'v1.2.3+build.01'), { prerelease: false });
});

test('rejects mismatched, incomplete, and invalid versions', () => {
  for (const [version, tag] of [
    ['1.2.3', 'v1.2.4'], ['1.2.3', '1.2.3'], ['1.2', 'v1.2'],
    ['01.2.3', 'v01.2.3'], ['1.2.3-beta.01', 'v1.2.3-beta.01'],
    ['1.2.3-', 'v1.2.3-'], ['1.2.3; echo bad', 'v1.2.3; echo bad'],
  ]) assert.throws(() => validateRelease(version, tag));
});
