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
  readonly property int cursorPercent: panelLoader.item ? (parseInt(panelLoader.item.data.cursorPercent, 10) || 0) : 0
  readonly property color cursorMark: panelLoader.item ? panelLoader.item.cursorColor : Color.accent
  readonly property real openPanelIndicatorWidth: button.usageWidth

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
      anchors.horizontalCenterOffset: 1
      percent: root.cursorPercent
      mark: button.active && button.useActiveColor ? button.activeColor : root.cursorMark
      alert: button.active && button.useActiveColor
      diameter: Style.bar.iconFont
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

    property int percent: 0
    property color mark: Color.foreground
    property bool alert: false
    property int diameter: Style.bar.iconFont
    // Shift the mark toward magenta so the used arc isn't the same cyan as the digits.
    readonly property color used: Qt.hsla((mark.hslHue + 0.42) % 1, Math.max(0.55, mark.hslSaturation), Math.min(0.72, Math.max(0.58, mark.hslLightness)), 1)
    readonly property real stroke: Math.max(2, Style.space(2))

    width: diameter
    height: diameter
    implicitWidth: diameter
    implicitHeight: diameter

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: Qt.rgba(circle.mark.r, circle.mark.g, circle.mark.b, 0.16)
    }

    Canvas {
      id: ring
      anchors.fill: parent
      antialiasing: true

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var stroke = circle.stroke
        var r = Math.max(1, (width - stroke) / 2)
        var cx = width / 2
        var cy = height / 2
        ctx.lineWidth = stroke
        ctx.lineCap = "butt"

        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, Math.PI * 2)
        ctx.strokeStyle = circle.alert ? circle.mark : Qt.rgba(circle.mark.r, circle.mark.g, circle.mark.b, 0.35)
        ctx.stroke()

        var sweep = circle.alert ? 0 : Math.max(0, Math.min(100, circle.percent)) / 100
        if (sweep <= 0) return
        ctx.beginPath()
        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + sweep * Math.PI * 2)
        ctx.strokeStyle = circle.used
        ctx.stroke()
      }

      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      Component.onCompleted: requestPaint()
    }

    Connections {
      target: circle
      function onPercentChanged() { ring.requestPaint() }
      function onMarkChanged() { ring.requestPaint() }
      function onAlertChanged() { ring.requestPaint() }
      function onUsedChanged() { ring.requestPaint() }
    }
  }
}
