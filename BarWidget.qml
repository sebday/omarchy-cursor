import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "evo.cursor"


  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function openDashboard() {
    if (panelLoader.item && panelLoader.item.openDashboard) {
      panelLoader.item.openDashboard()
      return
    }
    Quickshell.execDetached(["xdg-open", "https://cursor.com/dashboard/spending"])
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  readonly property bool iconError: panelLoader.item ? panelLoader.item.iconError === true : false
  readonly property bool iconBusy: panelLoader.item ? panelLoader.item.iconBusy === true : false
  readonly property bool iconMuted: panelLoader.item ? panelLoader.item.iconMuted === true : false
  readonly property string tooltip: panelLoader.item ? panelLoader.item.barTooltip : "Cursor usage"
  readonly property string valueText: panelLoader.item ? panelLoader.item.barValue : ""
  property color themeGreen: "#a6e3a1"
  property color themeBlue: "#89b4fa"
  property color themeOrange: "#fab387"
  property color themeRed: "#f38ba8"
  readonly property real openPanelIndicatorWidth: button.usageWidth

  function loadThemeColors(raw) {
    var green = ""
    var blue = ""
    var orange = ""
    var yellow = ""
    var red = ""
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*(green|blue|orange|yellow|red)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
      if (!match) continue
      if (match[1] === "green") green = match[2]
      else if (match[1] === "blue") blue = match[2]
      else if (match[1] === "orange") orange = match[2]
      else if (match[1] === "yellow") yellow = match[2]
      else if (match[1] === "red") red = match[2]
    }
    themeGreen = green || "#a6e3a1"
    themeBlue = blue || "#89b4fa"
    themeOrange = orange || yellow || "#fab387"
    themeRed = red || "#f38ba8"
  }

  // colors.toml lives inside current/theme, and theme set deletes that
  // directory. A watch on the file dies after the first switch. theme.name
  // is rewritten in place on every switch, after the new colors are in place.
  property FileView themeColorsFile: FileView {
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: false
    printErrors: false
    onLoaded: root.loadThemeColors(text())
  }

  property FileView themeNameFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: root.themeColorsFile.reload()
    onFileChanged: reload()
  }

  Connections {
    target: Color
    function onForegroundChanged() { root.themeColorsFile.reload() }
    function onAccentChanged() { root.themeColorsFile.reload() }
    function onBackgroundChanged() { root.themeColorsFile.reload() }
  }

  visible: valueText !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: implicitWidth
  height: implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
    onStatusChanged: {
      if (status === Loader.Error)
        console.warn("evo.cursor panel failed:", sourceComponent ? sourceComponent.errorString() : "unknown error")
    }
  }

  IpcHandler {
    target: "evo.cursor"

    function refresh(): void { root.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.valueText
    labelVisible: false
    hasVisualContent: root.valueText !== ""
    horizontalMargin: 8.75
    fixedWidth: contentRow.implicitWidth + scaledHorizontalMargin * 2
    active: root.iconError
    useActiveColor: root.iconError
    dimmed: root.iconMuted && !root.iconError
    tooltipText: Model.plain(root.tooltip)
    opacity: root.iconBusy && !root.iconError ? pulseOpacity : 1
    property real pulseOpacity: 1
    readonly property real usageWidth: contentRow.implicitWidth

    UsageCircle {
      id: contentRow
      anchors.centerIn: parent
      fontFamily: button.fontFamily
      color: button.foreground
    }

    SequentialAnimation on pulseOpacity {
      running: root.iconBusy && !root.iconError
      loops: Animation.Infinite
      NumberAnimation { from: 1.0; to: 0.42; duration: 880; easing.type: Easing.InOutSine }
      NumberAnimation { from: 0.42; to: 1.0; duration: 880; easing.type: Easing.InOutSine }
    }

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.openDashboard()
      else if (b === Qt.RightButton) root.refresh()
      else root.togglePanel()
    }
  }

  component UsageCircle: Item {
    id: circle

    property color color: Color.foreground
    property string fontFamily: Style.font.family
    readonly property int glyphBox: Style.bar.iconCanvas

    width: glyphBox
    height: glyphBox
    implicitWidth: glyphBox
    implicitHeight: glyphBox

    OpticalGlyph {
      anchors.fill: parent
      text: "󱚣"
      fontFamily: circle.fontFamily
      fontSize: Style.bar.iconFont
      color: circle.color
    }
  }
}
