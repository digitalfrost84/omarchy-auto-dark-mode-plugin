import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "digitalfrost84.auto-dark-mode"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  property bool popupOpen: false
  property var themeOptions: []
  readonly property bool opened: popupOpen
  readonly property bool popoutSwitchClosing: false

  function open() {
    popupOpen = true
    loadFields()
    if (!themeListProcess.running) themeListProcess.running = true
  }
  function close() { popupOpen = false }
  function toggle() { popupOpen ? close() : open() }
  function closeForPopoutSwitch() { close() }

  function persist(values) {
    var entry = { id: moduleName }
    for (var existing in settings) if (existing !== "id") entry[existing] = settings[existing]
    for (var key in values) entry[key] = values[key]
    settings = entry
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, entry)
  }

  function loadFields() {
    var lat = setting("latitude", "")
    var lon = setting("longitude", "")
    latitudeField.text = lat === null ? "" : String(lat)
    longitudeField.text = lon === null ? "" : String(lon)
    dawnOffsetField.text = String(setting("dawnOffset", 0))
    duskOffsetField.text = String(setting("duskOffset", 0))
    lightThemeField.value = String(setting("lightTheme", "Catppuccin Latte"))
    darkThemeField.value = String(setting("darkTheme", "Catppuccin"))
  }

  function saveFields() {
    var lat = Number(latitudeField.text)
    var lon = Number(longitudeField.text)
    if (!isFinite(lat) || lat < -90 || lat > 90 || !isFinite(lon) || lon < -180 || lon > 180) {
      formError.text = "Coordinates must be latitude −90…90 and longitude −180…180."
      return
    }
    formError.text = ""
    persist({
      latitude: lat,
      longitude: lon,
      dawnOffset: Math.round(Number(dawnOffsetField.text) || 0),
      duskOffset: Math.round(Number(duskOffsetField.text) || 0),
      lightTheme: lightThemeField.value,
      darkTheme: darkThemeField.value
    })
    if (service) service.evaluate(true)
  }

  function setAutomaticEnabled(value) {
    if (value) {
      var lat = Number(latitudeField.text)
      var lon = Number(longitudeField.text)
      if (!isFinite(lat) || lat < -90 || lat > 90 || !isFinite(lon) || lon < -180 || lon > 180) {
        formError.text = "Set valid coordinates before enabling automatic switching."
        return
      }
      saveFields()
      if (formError.text !== "") return
    }
    persist({ automatic: value })
    if (service) service.setAutomatic(value)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.service && root.service.solar.phase === "day" ? "󰖙" : "󰖔"
    active: root.service ? root.service.automatic : false
    tooltipText: root.service ? root.service.nextLabel() : "Solar Theme"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton && root.service) root.service.evaluate(true)
      else root.toggle()
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: fittedContentWidth(Style.space(390))
    contentHeight: fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      anchors.fill: parent
      spacing: Style.space(14)

      Row {
        width: parent.width
        spacing: Style.space(10)

        Column {
          width: parent.width - automaticSwitch.width - Style.space(10)
          spacing: Style.space(3)
          Text {
            text: "AUTO DARK MODE"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
          Text {
            text: root.service ? root.service.nextLabel() : "Starting…"
            color: root.bar ? root.bar.foreground : Color.foreground
            opacity: 0.72
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }

        ToggleSwitch {
          id: automaticSwitch
          checked: root.setting("automatic", true) === true
          onToggled: {
            root.setAutomaticEnabled(!checked)
          }
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)
        Button {
          width: (parent.width - parent.spacing) / 2
          text: "󰖨  Light now"
          bordered: true
          selected: root.service && root.service.currentTheme === root.setting("lightTheme", "Catppuccin Latte")
          onClicked: if (root.service) root.service.applyTheme(root.setting("lightTheme", "Catppuccin Latte"), true)
        }
        Button {
          width: (parent.width - parent.spacing) / 2
          text: "󰖔  Dark now"
          bordered: true
          selected: root.service && root.service.currentTheme === root.setting("darkTheme", "Catppuccin")
          onClicked: if (root.service) root.service.applyTheme(root.setting("darkTheme", "Catppuccin"), true)
        }
      }

      Rectangle { width: parent.width; height: 1; color: root.bar ? root.bar.foreground : Color.foreground; opacity: 0.14 }

      Grid {
        width: parent.width
        columns: 2
        columnSpacing: Style.space(8)
        rowSpacing: Style.space(8)

        LabeledField { id: latitudeField; label: "LATITUDE"; placeholderText: "52.5200" }
        LabeledField { id: longitudeField; label: "LONGITUDE"; placeholderText: "13.4050" }
        LabeledField { id: dawnOffsetField; label: "DAWN OFFSET · MIN"; placeholderText: "0" }
        LabeledField { id: duskOffsetField; label: "DUSK OFFSET · MIN"; placeholderText: "0" }
        Dropdown {
          id: lightThemeField
          width: (content.width - Style.space(8)) / 2
          label: "LIGHT THEME"
          options: root.themeOptions
          value: String(root.setting("lightTheme", "Catppuccin Latte"))
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }
        Dropdown {
          id: darkThemeField
          width: (content.width - Style.space(8)) / 2
          label: "DARK THEME"
          options: root.themeOptions
          value: String(root.setting("darkTheme", "Catppuccin"))
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - eventButton.width - parent.spacing
          text: "Solar event"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
        }
        Button {
          id: eventButton
          text: root.setting("event", "civil") === "sunrise" ? "Sunrise / sunset" : "Civil dawn / dusk"
          bordered: true
          onClicked: root.persist({ event: root.setting("event", "civil") === "sunrise" ? "civil" : "sunrise" })
        }
      }

      Text {
        id: formError
        width: parent.width
        visible: text !== ""
        wrapMode: Text.WordWrap
        color: Color.urgent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }

      Button {
        width: parent.width
        text: "Save schedule"
        iconText: "󰆓"
        bordered: true
        active: true
        onClicked: root.saveFields()
      }
    }
  }

  component LabeledField: Column {
    property string label: ""
    property string placeholderText: ""
    property alias text: input.text
    width: (content.width - Style.space(8)) / 2
    spacing: Style.space(4)
    Text {
      text: parent.label
      color: root.bar ? root.bar.foreground : Color.foreground
      opacity: 0.65
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
    }
    TextField {
      id: input
      width: parent.width
      placeholderText: parent.placeholderText
    }
  }

  Process {
    id: themeListProcess
    command: ["omarchy", "theme", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var names = text.split("\n").map(function(value) { return value.trim() })
          .filter(function(value) { return value !== "" })
        var currentLight = String(root.setting("lightTheme", "Catppuccin Latte"))
        var currentDark = String(root.setting("darkTheme", "Catppuccin"))
        if (names.indexOf(currentLight) === -1) names.unshift(currentLight)
        if (names.indexOf(currentDark) === -1) names.unshift(currentDark)
        root.themeOptions = names
      }
    }
  }

  Component.onCompleted: loadFields()
}
