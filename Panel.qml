import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "evo.cursor"
  ipcTarget: "evo.cursor"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool openedFromHotkey: false
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property color surface: Color.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var palette: Model.heatmapColors(accent)

  readonly property string statusScript: Qt.resolvedUrl("bin/cursor-usage").toString().replace("file://", "")
  readonly property int refreshIntervalSec: Math.max(30, parseInt(setting("refreshIntervalSec", 300), 10) || 300)
  readonly property int gaugeSpacing: Style.space(12)
  readonly property int usageContentWidth: Math.max(Style.space(340), panel.contentWidth - Style.space(24))
  readonly property int gaugeSize: Math.max(Style.space(96), Math.floor((usageContentWidth - gaugeSpacing) / 2))
  readonly property int usageBlockWidth: gaugeSize * 2 + gaugeSpacing
  readonly property int gaugeLabelFont: Math.max(Style.font.body, Math.round(gaugeSize * 0.22))
  readonly property int cycleDaySpacing: Style.spacing.xs

  property bool loading: true
  property var data: Model.parsePayload("")

  readonly property var detail: data.detail || Model.emptyDetail()
  readonly property bool hasData: data.ok === true
  readonly property bool isError: !hasData && data.error !== ""
  readonly property bool showTokens: hasData && Model.showTokens(detail)
  readonly property bool hasModelDetails: hasData && Model.hasModelDetails(detail)
  readonly property var modelSplit: Array.isArray(detail.modelSplit) ? detail.modelSplit : []
  readonly property color cycleColor: Model.cycleColor(detail, palette)
  readonly property color cursorColor: detail.cursorColor || palette[2]
  readonly property color otherColor: detail.otherColor || palette[4]
  readonly property int cycleDaysUsed: parseInt(data.cycleDaysUsed, 10) || 0
  readonly property int cycleDaysTotal: parseInt(data.cycleDaysTotal, 10) || 0
  readonly property bool iconActive: Model.iconActive(data)
  readonly property bool iconError: isError
  readonly property bool iconBusy: loading
  readonly property bool iconMuted: false
  readonly property string barTooltip: Model.barTooltip(data, loading)

  function applyPayload(raw) {
    loading = false
    data = Model.parsePayload(raw)
  }

  function refresh() {
    if (!statusScript || statusProc.running) return
    if (!hasData) loading = true
    statusProc.command = ["bash", statusScript]
    statusProc.running = true
  }

  function openDashboard() {
    Quickshell.execDetached(["xdg-open", "https://cursor.com/dashboard/spending"])
    root.close()
  }

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    root.refresh()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    root.refresh()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  Component.onCompleted: refresh()

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) {
          root.loading = false
          if (!root.hasData) root.applyPayload('{"class":"error","message":"No data"}')
          return
        }
        root.applyPayload(raw)
      }
    }
    stderr: StdioCollector { waitForEnd: true }
    onExited: root.loading = false
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }


  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          Text {
            width: parent.width
            visible: root.isError
            text: root.data.error || ""
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            visible: root.isError
            text: "Open Cursor spending →"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openDashboard()
            }
          }

          PanelSectionHeader {
            visible: !root.isError
            width: parent.width
            text: "USAGE"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            visible: !root.isError && root.showTokens
            width: parent.width
            spacing: Style.space(8)

            PanelStatTile {
              width: (parent.width - parent.spacing) / 2
              value: root.loading ? "…" : Model.formatTokens(root.detail.tokensTotal)
              label: "tokens"
              foreground: root.foreground
              dim: root.dim
              fontFamily: root.fontFamily
            }

            PanelStatTile {
              width: (parent.width - parent.spacing) / 2
              value: root.loading ? "…" : Model.formatTokens(root.detail.tokensToday)
              label: "today"
              valueColor: root.accent
              foreground: root.foreground
              dim: root.dim
              fontFamily: root.fontFamily
            }
          }

          Item {
            width: parent.width
            visible: !root.isError
            implicitHeight: usageBlock.implicitHeight

            Column {
              id: usageBlock
              anchors.horizontalCenter: parent.horizontalCenter
              width: root.usageBlockWidth
              spacing: Style.space(12)

              Row {
                width: parent.width
                spacing: root.gaugeSpacing

                Column {
                  width: root.gaugeSize
                  spacing: Style.spacing.sm

                  UsageGauge {
                    anchors.horizontalCenter: parent.horizontalCenter
                    percent: root.data.cursorPercent || 0
                    gaugeColor: root.cursorColor
                    loading: root.loading
                    gaugeSize: root.gaugeSize
                    labelFontSize: root.gaugeLabelFont
                    foreground: root.foreground
                    trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
                    fontFamily: root.fontFamily
                  }

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Cursor"
                    color: root.cursorColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                Column {
                  width: root.gaugeSize
                  spacing: Style.spacing.sm

                  UsageGauge {
                    anchors.horizontalCenter: parent.horizontalCenter
                    percent: root.data.otherPercent || 0
                    gaugeColor: root.otherColor
                    loading: root.loading
                    gaugeSize: root.gaugeSize
                    labelFontSize: root.gaugeLabelFont
                    foreground: root.foreground
                    trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
                    fontFamily: root.fontFamily
                  }

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Other"
                    color: root.otherColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }
          }

          Row {
            id: cycleDaysSection
            visible: !root.isError
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, root.usageBlockWidth - Style.space(16))
            spacing: Style.spacing.sm

            StatusPill {
              id: cycleDaysPill
              layoutAlignment: Qt.AlignVCenter
              text: Model.cycleDaysLeftText(root.data, root.loading)
              textColor: root.cycleColor
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              id: cycleDaysLabel
              layoutAlignment: Qt.AlignVCenter
              text: "left"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Item {
              id: cycleDaysTrack
              layoutAlignment: Qt.AlignVCenter
              width: Math.max(0, cycleDaysSection.width - cycleDaysPill.implicitWidth - cycleDaysLabel.implicitWidth - parent.spacing * 2)
              visible: root.cycleDaysTotal > 0
              height: cycleDaysPill.implicitHeight

              readonly property int cellCount: root.cycleDaysTotal
              readonly property int cellWidth: cellCount > 0 && width > 0
                ? Math.max(4, Math.floor((width - Math.max(0, cellCount - 1) * root.cycleDaySpacing) / cellCount))
                : 12

              Row {
                id: cycleDaysRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.cycleDaySpacing

                Repeater {
                  model: root.cycleDaysTotal

                  Rectangle {
                    required property int index
                    readonly property bool isToday: {
                      if (root.cycleDaysTotal <= 0) return false
                      if (root.cycleDaysUsed < root.cycleDaysTotal)
                        return index === root.cycleDaysUsed
                      return index === root.cycleDaysTotal - 1
                    }
                    readonly property bool elapsed: index < root.cycleDaysUsed || isToday

                    width: cycleDaysTrack.cellWidth
                    height: cycleDaysTrack.height
                    radius: Math.min(Style.cornerRadius, height / 2)
                    color: elapsed ? root.cycleColor : root.palette[0]
                    opacity: elapsed ? 1 : 0.35
                    border.width: isToday ? 1 : 0
                    border.color: root.accent
                  }
                }
              }
            }
          }

          PanelSeparator {
            visible: !root.isError && root.hasModelDetails
            foreground: root.foreground
          }

          PanelSectionHeader {
            visible: !root.isError && root.hasModelDetails
            width: parent.width
            text: "BREAKDOWN"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: root.modelSplit

            Column {
              required property var modelData
              width: column.width
              spacing: Style.spacing.xs
              visible: !root.isError

              Row {
                width: parent.width
                spacing: Style.space(12)

                Text {
                  width: parent.width - detailText.implicitWidth - parent.spacing
                  text: Model.modelLabel(modelData.model)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  id: detailText
                  text: root.loading
                    ? "…"
                    : Math.round(modelData.percent) + "% · "
                      + Model.formatTokens(modelData.tokens)
                  color: modelData.color || root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
              }

              Item {
                width: parent.width
                height: 4

                Rectangle {
                  anchors.fill: parent
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                }

                Rectangle {
                  height: parent.height
                  width: parent.width * Math.max(0, Math.min(1, modelData.percent / 100))
                  radius: Style.cornerRadius
                  color: modelData.color || root.accent
                  opacity: 0.85
                }
              }
            }
          }

          Row {
            width: parent.width
            visible: !root.isError && root.detail.onDemand === true
            spacing: Style.spacing.sm

            Text {
              text: "On-demand usage enabled"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            StatusPill {
              visible: root.detail.onDemandUsed > 0
              text: Number(root.detail.onDemandUsed).toLocaleString() + " used"
              textColor: root.accent
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
          }
        }
      }
    }
  }

  component UsageGauge: Item {
    id: gaugeRoot

    property int percent: 0
    property color gaugeColor: Color.accent
    property bool loading: false
    property int gaugeSize: 130
    property int labelFontSize: Style.font.body
    property color foreground: Color.foreground
    property color trackColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
    property string fontFamily: Style.font.family

    implicitWidth: gaugeRoot.gaugeSize
    implicitHeight: ring.height

    readonly property int ringSize: Math.round(gaugeRoot.gaugeSize * 0.91)
    readonly property real ringRadius: gaugeRoot.gaugeSize * 0.34
    readonly property real ringLineWidth: Math.max(10, gaugeRoot.gaugeSize * 0.077)
    readonly property real sweep: Math.max(0, Math.min(100, percent)) / 100

    Canvas {
      id: ring
      anchors.horizontalCenter: parent.horizontalCenter
      width: gaugeRoot.ringSize
      height: gaugeRoot.ringSize
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var cx = width / 2
        var cy = height / 2
        var r = gaugeRoot.ringRadius
        var lw = gaugeRoot.ringLineWidth

        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, Math.PI * 2)
        ctx.strokeStyle = gaugeRoot.trackColor
        ctx.lineWidth = lw
        ctx.lineCap = "round"
        ctx.stroke()

        if (gaugeRoot.sweep > 0) {
          ctx.beginPath()
          ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + gaugeRoot.sweep * Math.PI * 2)
          ctx.strokeStyle = gaugeRoot.gaugeColor
          ctx.lineWidth = lw
          ctx.lineCap = "round"
          ctx.stroke()
        }
      }
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      Connections {
        target: gaugeRoot
        function onPercentChanged() { ring.requestPaint() }
        function onGaugeColorChanged() { ring.requestPaint() }
        function onTrackColorChanged() { ring.requestPaint() }
      }
      Component.onCompleted: requestPaint()
    }

    Text {
      anchors.centerIn: ring
      text: gaugeRoot.loading ? "…" : (gaugeRoot.percent + "%")
      color: gaugeRoot.foreground
      font.family: gaugeRoot.fontFamily
      font.pixelSize: gaugeRoot.labelFontSize
      font.bold: true
    }
  }

  component StatusPill: Rectangle {
    property string text: ""
    property color textColor: foreground
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family

    implicitWidth: pillText.implicitWidth + Style.spacing.lg * 2
    implicitHeight: pillText.implicitHeight + Style.spacing.sm * 2
    radius: implicitHeight / 2
    color: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.14)

    Text {
      id: pillText
      anchors.centerIn: parent
      text: parent.text
      color: parent.textColor
      font.family: parent.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  component PanelStatTile: BorderSurface {
    id: tileRoot

    property string value: ""
    property string label: ""
    property color valueColor: Color.accent
    property color foreground: Color.foreground
    property color dim: Qt.darker(foreground, 1.4)
    property string fontFamily: Style.font.family

    implicitHeight: tileColumn.implicitHeight + Style.spacing.lg * 2
    color: Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
    radius: Style.cornerRadius

    Column {
      id: tileColumn
      anchors.centerIn: parent
      width: parent.width - Style.spacing.lg * 2
      spacing: Style.spacing.labelGap

      Text {
        width: parent.width
        text: tileRoot.value
        color: tileRoot.valueColor
        font.family: tileRoot.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        text: tileRoot.label
        color: tileRoot.dim
        font.family: tileRoot.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }
    }
  }
}
