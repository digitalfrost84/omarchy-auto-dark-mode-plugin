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
  property bool manualOverride: false
  property double manualOverrideUntil: 0
  property bool stateLoaded: false
  property string errorMessage: ""
  property string pendingTheme: ""
  property bool pendingManual: false

  readonly property string pluginId: "digitalfrost84.auto-dark-mode"
  readonly property var settings: findSettings()
  readonly property bool automatic: setting("automatic", true) === true
  readonly property real latitude: Number(setting("latitude", NaN))
  readonly property real longitude: Number(setting("longitude", NaN))
  readonly property string eventName: String(setting("event", "civil")) === "sunrise" ? "sunrise" : "civil"
  readonly property int dawnOffset: Number(setting("dawnOffset", 0))
  readonly property int duskOffset: Number(setting("duskOffset", 0))
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
    solar = Solar.schedule(now, latitude, longitude, eventName, dawnOffset, duskOffset)
    return true
  }

  function evaluate(force) {
    if (!stateLoaded) return
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
    errorMessage = ""
    themeCheck.command = ["omarchy", "theme", "dir", name]
    themeCheck.running = true
  }

  function runApplyTheme(name, manual) {
    if (manual) {
      manualOverride = true
      manualOverrideUntil = solar.nextAt ? solar.nextAt.getTime() : now.getTime() + 12 * 60 * 60 * 1000
      persistOverride()
    }
    lastAppliedTheme = name
    currentTheme = name
    applyProcess.command = ["omarchy", "theme", "set", name]
    applyProcess.running = true
  }

  function clearManualOverride() {
    if (!stateLoaded) return
    if (!manualOverride && manualOverrideUntil === 0) return
    manualOverride = false
    manualOverrideUntil = 0
    persistOverride()
  }

  function persistOverride() {
    stateFile.setText(JSON.stringify({
      manualOverride: manualOverride,
      overrideUntil: manualOverrideUntil
    }, null, 2) + "\n")
  }

  function restoreOverride(raw) {
    var state = ({})
    try { state = JSON.parse(String(raw || "{}")) } catch (e) { state = ({}) }
    manualOverrideUntil = Number(state.overrideUntil || 0)
    manualOverride = state.manualOverride === true && manualOverrideUntil > Date.now()
    if (!manualOverride) manualOverrideUntil = 0
    stateLoaded = true
    Qt.callLater(function() { root.evaluate(false) })
  }

  function setAutomatic(value) {
    clearManualOverride()
    if (value) Qt.callLater(function() { root.evaluate(true) })
  }

  function refreshTheme() {
    if (!themeProbe.running) themeProbe.running = true
  }

  function nextLabel() {
    if (errorMessage) return errorMessage
    if (!automatic) return "Automatic switching is off"
    if (solar.polar) return solar.polar === "day" ? "Polar day · light theme" : "Polar night · dark theme"
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
    onExited: function(exitCode) {
      var name = root.pendingTheme
      var manual = root.pendingManual
      root.pendingTheme = ""
      root.pendingManual = false
      if (exitCode === 0) root.runApplyTheme(name, manual)
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
            root.persistOverride()
          }
        root.currentTheme = observed
      }
    }
  }

  Process {
    id: applyProcess
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim()) root.errorMessage = text.trim().split("\n")[0]
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.currentTheme = ""
      root.refreshTheme()
    }
  }
}
