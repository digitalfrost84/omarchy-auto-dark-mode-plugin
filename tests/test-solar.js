#!/usr/bin/env node

const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(path.join(__dirname, "..", "Solar.js"), "utf8")
  .replace(".pragma library", "")
const solar = { Date, Math, isFinite }
vm.createContext(solar)
vm.runInContext(source, solar)

let failures = 0

function check(condition, message) {
  if (condition) process.stdout.write(`✓ ${message}\n`)
  else {
    failures += 1
    process.stderr.write(`✗ ${message}\n`)
  }
}

function near(actual, expected, toleranceMinutes, message) {
  const delta = Math.abs(actual.getTime() - expected.getTime()) / 60000
  check(delta <= toleranceMinutes, `${message} (Δ ${delta.toFixed(1)} min)`)
}

const berlinSummer = solar.schedule(
  new Date("2026-06-21T12:00:00+02:00"), 52.52, 13.405, -6, -6)
near(berlinSummer.dawn, new Date("2026-06-21T03:54:00+02:00"), 3,
  "Berlin summer civil dawn")
near(berlinSummer.dusk, new Date("2026-06-21T22:25:00+02:00"), 3,
  "Berlin summer civil dusk")

const berlinWinter = solar.schedule(
  new Date("2026-12-21T12:00:00+01:00"), 52.52, 13.405, -6, -6)
near(berlinWinter.dawn, new Date("2026-12-21T07:34:00+01:00"), 3,
  "Berlin winter civil dawn")
near(berlinWinter.dusk, new Date("2026-12-21T16:37:00+01:00"), 3,
  "Berlin winter civil dusk")

const darkLonger = solar.schedule(
  new Date("2026-08-27T12:00:00+02:00"), 52.52, 13.405, 3, 3)
const horizon = solar.schedule(
  new Date("2026-08-27T12:00:00+02:00"), 52.52, 13.405, -0.833, -0.833)
check(darkLonger.dawn > horizon.dawn,
  "higher angle switches to light later")
check(darkLonger.dusk < horizon.dusk,
  "higher angle switches to dark earlier")

const independent = solar.schedule(
  new Date("2026-08-27T12:00:00+02:00"), 52.52, 13.405, 6, 0)
check(independent.dawn > darkLonger.dawn,
  "morning angle can delay light independently")
check(independent.dusk > darkLonger.dusk,
  "evening angle can delay dark independently")

check(solar.validCoordinates(52.52, 13.405), "valid coordinates accepted")
check(!solar.validCoordinates(91, 13.405), "invalid latitude rejected")
check(!solar.validCoordinates(52.52, 181), "invalid longitude rejected")

const polarSummer = solar.schedule(
  new Date("2026-06-21T12:00:00+02:00"), 78.2232, 15.6469, 3, 3)
check(polarSummer.polar === "day", "polar day handled")

const polarWinter = solar.schedule(
  new Date("2026-12-21T12:00:00+01:00"), 78.2232, 15.6469, 3, 3)
check(polarWinter.polar === "night", "polar night handled")

process.exitCode = failures === 0 ? 0 : 1
