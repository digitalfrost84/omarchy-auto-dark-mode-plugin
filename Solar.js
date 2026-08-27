.pragma library

var dayMs = 86400000
var rad = Math.PI / 180
var epochJulian = 2440587.5
var j2000 = 2451545.0
var j0 = 0.0009

function toJulian(date) {
  return date.getTime() / dayMs + epochJulian
}

function fromJulian(julian) {
  return new Date((julian - epochJulian) * dayMs)
}

function solarMeanAnomaly(days) {
  return rad * (357.5291 + 0.98560028 * days)
}

function eclipticLongitude(meanAnomaly) {
  var center = rad * (1.9148 * Math.sin(meanAnomaly)
    + 0.0200 * Math.sin(2 * meanAnomaly)
    + 0.0003 * Math.sin(3 * meanAnomaly))
  return meanAnomaly + center + rad * 102.9372 + Math.PI
}

function declination(longitude) {
  return Math.asin(Math.sin(longitude) * Math.sin(rad * 23.4397))
}

function altitudeFor(eventName) {
  return eventName === "sunrise" ? -0.833 : -6.0
}

// SunCalc/NOAA-style solar transit calculation. The supplied Date may be at
// any local time; local noon is used by the caller to select the civil day.
function timesFor(date, latitude, longitude, eventName, dawnOffset, duskOffset) {
  var lw = -Number(longitude) * rad
  var phi = Number(latitude) * rad
  var days = toJulian(date) - j2000
  var cycle = Math.round(days - j0 - lw / (2 * Math.PI))
  var approxTransit = j0 + (0 + lw) / (2 * Math.PI) + cycle
  var meanAnomaly = solarMeanAnomaly(approxTransit)
  var ecliptic = eclipticLongitude(meanAnomaly)
  var transit = j2000 + approxTransit + 0.0053 * Math.sin(meanAnomaly)
    - 0.0069 * Math.sin(2 * ecliptic)
  var decl = declination(ecliptic)
  var height = altitudeFor(eventName) * rad
  var denominator = Math.cos(phi) * Math.cos(decl)
  var cosHour = (Math.sin(height) - Math.sin(phi) * Math.sin(decl)) / denominator

  if (cosHour > 1) return { polar: "night", dawn: null, dusk: null }
  if (cosHour < -1) return { polar: "day", dawn: null, dusk: null }

  var hourAngle = Math.acos(cosHour)
  var setJulian = transit + hourAngle / (2 * Math.PI)
  var riseJulian = transit - hourAngle / (2 * Math.PI)
  return {
    polar: "",
    dawn: new Date(fromJulian(riseJulian).getTime() + Number(dawnOffset || 0) * 60000),
    dusk: new Date(fromJulian(setJulian).getTime() + Number(duskOffset || 0) * 60000)
  }
}

function localNoon(date, dayDelta) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + (dayDelta || 0), 12, 0, 0, 0)
}

function schedule(now, latitude, longitude, eventName, dawnOffset, duskOffset) {
  var today = timesFor(localNoon(now, 0), latitude, longitude, eventName, dawnOffset, duskOffset)
  if (today.polar) {
    return {
      phase: today.polar,
      nextKind: "",
      nextAt: null,
      dawn: null,
      dusk: null,
      polar: today.polar
    }
  }

  var phase = now >= today.dawn && now < today.dusk ? "day" : "night"
  var nextKind
  var nextAt
  if (now < today.dawn) {
    nextKind = "dawn"
    nextAt = today.dawn
  } else if (now < today.dusk) {
    nextKind = "dusk"
    nextAt = today.dusk
  } else {
    var tomorrow = timesFor(localNoon(now, 1), latitude, longitude, eventName, dawnOffset, duskOffset)
    nextKind = tomorrow.polar ? "" : "dawn"
    nextAt = tomorrow.dawn
  }

  return {
    phase: phase,
    nextKind: nextKind,
    nextAt: nextAt,
    dawn: today.dawn,
    dusk: today.dusk,
    polar: ""
  }
}

function validCoordinates(latitude, longitude) {
  var lat = Number(latitude)
  var lon = Number(longitude)
  return isFinite(lat) && isFinite(lon) && lat >= -90 && lat <= 90
    && lon >= -180 && lon <= 180
}

function durationLabel(milliseconds) {
  var minutes = Math.max(0, Math.round(Number(milliseconds) / 60000))
  var hours = Math.floor(minutes / 60)
  var remainder = minutes % 60
  if (hours < 1) return minutes + " min"
  if (remainder === 0) return hours + " h"
  return hours + " h " + remainder + " min"
}
