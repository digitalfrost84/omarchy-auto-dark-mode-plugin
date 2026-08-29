import QtQuick
import Quickshell
import Quickshell.Io
import "Solar.js" as Solar

Item {
  id: root

  property var shell: null
  property var manifest: null
  property date now: new Date()
  property var solar: ({ phase: "night", nextKind: "", nextAt: null, polar: "" })
  property string currentTheme: ""
  property string lastAppliedTheme: ""
  property bool themeLoaded: false
  property bool manualOverride: false
  property double manualOverrideUntil: 0
  property var wallpapers: ({})
  property bool stateLoaded: false
  property string errorMessage: ""
  property string pendingTheme: ""
  property bool pendingManual: false
  property bool themeCheckFound: false
  property string applyingTheme: ""
  property string backgroundProbePurpose: ""
  property string backgroundProbeTheme: ""
  property string probedBackgroundPath: ""

  readonly property string pluginId: "digitalfrost84.auto-dark-mode"
  readonly property var settings: findSettings()
  readonly property bool automatic: setting("automatic", true) === true
  readonly property real latitude: Number(setting("latitude", NaN))
  readonly property real longitude: Number(setting("longitude", NaN))
  readonly property real lightAngle: Number(setting("lightAngle", 3))
  readonly property real darkAngle: Number(setting("darkAngle", 3))
  readonly property string lightTheme: String(setting("lightTheme", "Catppuccin Latte"))
  readonly property string darkTheme: String(setting("darkTheme", "Catppuccin"))
  readonly property string desiredTheme: solar.phase === "day" ? lightTheme : darkTheme

  function findSettings() {
    var config = shell ? shell.shellConfig : null
    if (!config) return ({})
    var sections = ["left", "center", "right"]
    var layout = config.bar && config.bar.layout ? config.bar.layout : ({})
    for (var s = 0; s < sections.length; s++) {
      var entries = layout[sections[s]] || []
      for (var i = 0; i < entries.length; i++)
        if (entries[i] && entries[i].id === pluginId) return entries[i]
    }
    var plugins = config.plugins || []
    for (var p = 0; p < plugins.length; p++)
      if (plugins[p] && plugins[p].id === pluginId) return plugins[p]
    return ({})
  }

  function setting(key, fallback) {
    var value = settings ? settings[key] : undefined
    return value === undefined || value === null || value === "" ? fallback : value
  }

  function refreshSchedule() {
    now = new Date()
    if (!Solar.validCoordinates(latitude, longitude)) {
      errorMessage = "Invalid latitude or longitude"
      return false
    }
    errorMessage = ""
    solar = Solar.schedule(now, latitude, longitude, lightAngle, darkAngle)
    return true
  }

  function evaluate(force) {
    // Reading Omarchy's persisted current theme first prevents a shell restart
    // from needlessly reapplying the same theme and rotating its wallpaper.
    if (!stateLoaded || !themeLoaded) return
    var previousKind = solar.nextKind
    var previousAt = solar.nextAt ? solar.nextAt.getTime() : 0
    if (!refreshSchedule() || !automatic) return

    var crossedTransition = previousAt > 0 && now.getTime() >= previousAt
    if (manualOverride && manualOverrideUntil > 0 && now.getTime() >= manualOverrideUntil)
      clearManualOverride()
    if (crossedTransition || (previousKind !== "" && previousKind !== solar.nextKind))
      clearManualOverride()

    if (manualOverride && !force) return
    if (desiredTheme && currentTheme !== desiredTheme && !applyProcess.running)
      applyTheme(desiredTheme, false)
  }

  function applyTheme(themeName, manual) {
    var name = String(themeName || "").trim()
    if (!name || applyProcess.running || themeCheck.running) return
    pendingTheme = name
    pendingManual = manual === true
    themeCheckFound = false
    errorMessage = ""
    themeCheck.command = ["omarchy", "theme", "list"]
    themeCheck.running = true
  }

  function runApplyTheme(name, manual) {
    if (manual) {
      manualOverride = true
      manualOverrideUntil = solar.nextAt ? solar.nextAt.getTime() : now.getTime() + 12 * 60 * 60 * 1000
      persistState()
    }
    applyingTheme = name
    if (currentTheme) {
      if (backgroundProbe.running)
        backgroundProbePurpose = "beforeApply"
      else
        probeBackground(currentTheme, "beforeApply")
    } else {
      startThemeApply()
    }
  }

  function startThemeApply() {
    if (!applyingTheme || applyProcess.running) return
    applyProcess.command = ["omarchy", "theme", "set", applyingTheme]
    applyProcess.running = true
  }

  function wallpaperKey(themeName) {
    return String(themeName || "").trim().toLowerCase()
  }

  function rememberedWallpaper(themeName) {
    return String(wallpapers[wallpaperKey(themeName)] || "")
  }

  function rememberWallpaper(themeName, path) {
    var key = wallpaperKey(themeName)
    var value = String(path || "").trim()
    if (!key || !value || value[0] !== "/" || wallpapers[key] === value) return
    var updated = ({})
    for (var existing in wallpapers) updated[existing] = wallpapers[existing]
    updated[key] = value
    wallpapers = updated
    persistState()
  }

  function probeBackground(themeName, purpose) {
    if (!themeName || backgroundProbe.running) return
    backgroundProbeTheme = themeName
    backgroundProbePurpose = purpose || "observe"
    probedBackgroundPath = ""
    backgroundProbe.command = ["readlink", "-f",
      Quickshell.env("HOME") + "/.local/state/omarchy/current/background"]
    backgroundProbe.running = true
  }

  function clearManualOverride() {
    if (!stateLoaded) return
    if (!manualOverride && manualOverrideUntil === 0) return
    manualOverride = false
    manualOverrideUntil = 0
    persistState()
  }

  function persistState() {
    stateFile.setText(JSON.stringify({
      manualOverride: manualOverride,
      overrideUntil: manualOverrideUntil,
      wallpapers: wallpapers
    }, null, 2) + "\n")
  }

  function restoreOverride(raw) {
    var state = ({})
    try { state = JSON.parse(String(raw || "{}")) } catch (e) { state = ({}) }
    manualOverrideUntil = Number(state.overrideUntil || 0)
    manualOverride = state.manualOverride === true && manualOverrideUntil > Date.now()
    wallpapers = state.wallpapers && typeof state.wallpapers === "object"
      ? state.wallpapers : ({})
    if (!manualOverride) manualOverrideUntil = 0
    stateLoaded = true
    Qt.callLater(function() { root.evaluate(false) })
  }

  function setAutomatic(value) {
    clearManualOverride()
    if (value) Qt.callLater(function() { root.evaluate(true) })
  }

  function refreshTheme() {
    if (!themeProbe.running && !applyProcess.running && !applyingTheme)
      themeProbe.running = true
  }

  function nextLabel() {
    if (errorMessage) return errorMessage
    if (!automatic) return "Automatic switching is off"
    if (solar.polar) return solar.polar === "day"
      ? "Sun stays above threshold · light theme"
      : "Sun stays below threshold · dark theme"
    if (!solar.nextAt) return "No solar transition"
    var label = solar.nextKind === "dawn" ? "Light" : "Dark"
    return label + " at " + Qt.formatTime(solar.nextAt, "HH:mm")
      + " · in " + Solar.durationLabel(solar.nextAt.getTime() - now.getTime())
  }

  onSettingsChanged: {
    if (stateLoaded) {
      clearManualOverride()
      Qt.callLater(function() { root.evaluate(true) })
    }
  }

  FileView {
    id: stateFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/auto-dark-mode.json"
    printErrors: false
    onLoaded: root.restoreOverride(text())
    onLoadFailed: root.restoreOverride("")
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.evaluate(false)
      root.refreshTheme()
    }
  }

  Process {
    id: themeCheck
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var names = text.split("\n").map(function(value) { return value.trim() })
          .filter(function(value) { return value !== "" })
        root.themeCheckFound = names.indexOf(root.pendingTheme) !== -1
      }
    }
    onExited: function(exitCode) {
      var name = root.pendingTheme
      var manual = root.pendingManual
      root.pendingTheme = ""
      root.pendingManual = false
      if (exitCode === 0 && root.themeCheckFound) root.runApplyTheme(name, manual)
      else root.errorMessage = "Theme not found: " + name
    }
  }

  Process {
    id: themeProbe
    command: ["omarchy", "theme", "current"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var observed = text.trim()
        if (!observed) return
        if (root.currentTheme && observed !== root.currentTheme
            && observed !== root.lastAppliedTheme && root.automatic)
          {
            root.manualOverride = true
            root.manualOverrideUntil = root.solar.nextAt
              ? root.solar.nextAt.getTime() : Date.now() + 12 * 60 * 60 * 1000
            root.persistState()
          }
        root.currentTheme = observed
        root.themeLoaded = true
        root.probeBackground(observed, "observe")
        Qt.callLater(function() { root.evaluate(false) })
      }
    }
  }

  Process {
    id: backgroundProbe
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.probedBackgroundPath = text.trim()
    }
    onExited: function(exitCode) {
      var purpose = root.backgroundProbePurpose
      var themeName = root.backgroundProbeTheme
      root.backgroundProbePurpose = ""
      root.backgroundProbeTheme = ""
      if (exitCode === 0) root.rememberWallpaper(themeName, root.probedBackgroundPath)
      root.probedBackgroundPath = ""
      if (purpose === "beforeApply") root.startThemeApply()
    }
  }

  Process {
    id: restoreBackground
    onExited: function(exitCode) {
      // If a remembered file was removed, Omarchy keeps the theme's selected
      // default. Probing it replaces the stale entry for the next switch.
      root.probeBackground(root.currentTheme, "afterApply")
      root.applyingTheme = ""
      root.refreshTheme()
    }
  }

  Process {
    id: applyProcess
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim()) root.errorMessage = text.trim().split("\n")[0]
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.currentTheme = ""
        root.applyingTheme = ""
        root.refreshTheme()
        return
      }
      root.lastAppliedTheme = root.applyingTheme
      root.currentTheme = root.applyingTheme
      root.themeLoaded = true
      var wallpaper = root.rememberedWallpaper(root.currentTheme)
      if (wallpaper) {
        restoreBackground.command = ["omarchy", "theme", "bg", "set", wallpaper]
        restoreBackground.running = true
      } else {
        root.probeBackground(root.currentTheme, "afterApply")
        root.applyingTheme = ""
        root.refreshTheme()
      }
    }
  }
}
