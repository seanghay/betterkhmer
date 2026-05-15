// @ts-check
const fs = require('fs');
const path = require('path');
const { normalize } = require('../dist/index');

const FIXTURES = process.argv[2] ?? path.join(__dirname, '..', '..', '..', 'fixtures');

const got = normalize('ខ្មែរ');
if (got !== 'ខ្មែរ') throw new Error(`basic FAILED: got ${got}`);
console.log('basic: ok');

const inputs   = fs.readFileSync(path.join(FIXTURES, 'input.txt'),   'utf8').split('\n').filter(Boolean);
const expected = fs.readFileSync(path.join(FIXTURES, 'expected.txt'), 'utf8').split('\n').filter(Boolean);
if (inputs.length !== expected.length) throw new Error('length mismatch');

let failures = 0;
for (let i = 0; i < inputs.length; i++) {
  const result = normalize(inputs[i]);
  if (result !== expected[i]) {
    failures++;
    if (failures <= 10) process.stderr.write(`[${i}] got ${result}, want ${expected[i]}\n`);
  }
}
if (failures > 0) throw new Error(`${failures}/${inputs.length} fixture failures`);
console.log(`fixtures: ${inputs.length} ok`);
