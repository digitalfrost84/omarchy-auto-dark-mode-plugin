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
  new Date("2026-06-21T12:00:00+02:00"), 52.52, 13.405, "civil", 0, 0)
near(berlinSummer.dawn, new Date("2026-06-21T03:54:00+02:00"), 3,
  "Berlin summer civil dawn")
near(berlinSummer.dusk, new Date("2026-06-21T22:25:00+02:00"), 3,
  "Berlin summer civil dusk")

const berlinWinter = solar.schedule(
  new Date("2026-12-21T12:00:00+01:00"), 52.52, 13.405, "civil", 0, 0)
near(berlinWinter.dawn, new Date("2026-12-21T07:34:00+01:00"), 3,
  "Berlin winter civil dawn")
near(berlinWinter.dusk, new Date("2026-12-21T16:37:00+01:00"), 3,
  "Berlin winter civil dusk")

const shifted = solar.schedule(
  new Date("2026-08-27T12:00:00+02:00"), 52.52, 13.405, "civil", 30, -15)
const plain = solar.schedule(
  new Date("2026-08-27T12:00:00+02:00"), 52.52, 13.405, "civil", 0, 0)
check(Math.round((shifted.dawn - plain.dawn) / 60000) === 30,
  "positive dawn offset applies after dawn")
check(Math.round((shifted.dusk - plain.dusk) / 60000) === -15,
  "negative dusk offset applies before dusk")

check(solar.validCoordinates(52.52, 13.405), "valid coordinates accepted")
check(!solar.validCoordinates(91, 13.405), "invalid latitude rejected")
check(!solar.validCoordinates(52.52, 181), "invalid longitude rejected")

const polarSummer = solar.schedule(
  new Date("2026-06-21T12:00:00+02:00"), 78.2232, 15.6469, "civil", 0, 0)
check(polarSummer.polar === "day", "polar day handled")

const polarWinter = solar.schedule(
  new Date("2026-12-21T12:00:00+01:00"), 78.2232, 15.6469, "civil", 0, 0)
check(polarWinter.polar === "night", "polar night handled")

process.exitCode = failures === 0 ? 0 : 1
