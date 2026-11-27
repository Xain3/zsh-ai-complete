'use strict';

const fs = require('node:fs');
const path = require('node:path');

function validateRelease(version, tag) {
  const match = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$/.exec(version);
  if (!match || (match[4] && match[4].split('.').some(part => /^\d+$/.test(part) && part.length > 1 && part.startsWith('0')))) {
    throw new Error('package.json version must be valid SemVer');
  }
  if (tag !== `v${version}`) throw new Error('tag must exactly match package.json version with a v prefix');
  return { prerelease: Boolean(match[4]) };
}

if (require.main === module) {
  try {
    const { version } = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8'));
    const { prerelease } = validateRelease(version, process.argv[2]);
    console.log(`prerelease=${prerelease}`);
  } catch (error) {
    console.error(`Invalid release: ${error.message}`);
    process.exitCode = 1;
  }
}

module.exports = { validateRelease };
