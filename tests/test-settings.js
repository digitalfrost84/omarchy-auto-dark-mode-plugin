#!/usr/bin/env node
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const source = fs.readFileSync(path.join(__dirname, '..', 'Service.qml'), 'utf8')
const context = { pluginId: 'digitalfrost84.auto-dark-mode' }
vm.createContext(context)
vm.runInContext(source.slice(source.indexOf('  function findSettings()'), source.indexOf('  function evaluate(')), context)
vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'Solar.js'), 'utf8').replace('.pragma library', ''), context)
context.Solar = { validCoordinates: context.validCoordinates, schedule: context.schedule }
const entry = { id: context.pluginId, latitude: 38, longitude: 23, lightTheme: 'Flexoki Light', darkTheme: 'Gruvbox' }
for (const section of ['left', 'center', 'right']) {
  context.shell = { barConfig: { layout: { [section]: [entry] } } }
  context.settings = context.findSettings()
  context.latitude = Number(context.setting('latitude', NaN))
  context.longitude = Number(context.setting('longitude', NaN))
  context.lightAngle = 1
  context.darkAngle = 3
  assert.equal(context.refreshSchedule(), true, `${section}: ${context.errorMessage}`)
  assert.equal(context.setting('lightTheme', ''), entry.lightTheme)
  assert.ok(context.solar.nextAt)
}
context.shell.barConfig = { layout: { right: [{ ...entry, latitude: 91 }] } }
context.settings = context.findSettings()
context.latitude = Number(context.setting('latitude', NaN))
assert.equal(context.refreshSchedule(), false)
assert.equal(context.errorMessage, 'Invalid latitude or longitude')
console.log('PASS: scoped shell settings produce a schedule; invalid coordinates are rejected')
