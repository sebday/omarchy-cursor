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
  readonly property int usageStatTileCount: (showTokens ? 2 : 0) + (cycleDaysTotal > 0 ? 1 : 0)

  property bool loading: true
  property var data: Model.parsePayload("")

  property real shownCursorPercent: 0
  property real shownOtherPercent: 0
  property int usageCelebrateToken: 0

  NumberAnimation {
    id: cursorPercentAnim
    target: root
    property: "shownCursorPercent"
    easing.type: Easing.OutCubic
    onFinished: root.usageCelebrateToken++
  }

  NumberAnimation {
    id: otherPercentAnim
    target: root
    property: "shownOtherPercent"
    easing.type: Easing.OutCubic
  }

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
  readonly property string heroMeta: {
    if (loading) return "Refreshing…"
    if (isError) return data.error || "Unavailable"
    if (detail.membership) return String(detail.membership)
    if (hasData) return (data.cursorPercent || 0) + "% cursor · " + (data.otherPercent || 0) + "% other"
    return ""
  }

  function applyPayload(raw) {
    loading = false
    data = Model.parsePayload(raw)
    syncAnimatedStats(false)
  }

  function syncAnimatedStats(fromZero) {
    if (!hasData) {
      cursorPercentAnim.stop()
      otherPercentAnim.stop()
      shownCursorPercent = 0
      shownOtherPercent = 0
      return
    }

    animateStat(cursorPercentAnim, "shownCursorPercent", data.cursorPercent || 0, fromZero)
    animateStat(otherPercentAnim, "shownOtherPercent", data.otherPercent || 0, fromZero)
  }

  function animateStat(anim, propertyName, target, fromZero) {
    var next = Number(target) || 0
    var current = root[propertyName] || 0
    if (!fromZero && Math.round(current) === Math.round(next)) {
      root[propertyName] = next
      return
    }

    anim.stop()
    anim.from = fromZero ? 0 : current
    anim.to = next
    anim.duration = Math.min(900, Math.max(420, next * 10))
    anim.start()
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
    shownCursorPercent = 0
    shownOtherPercent = 0
    refresh()
    if (hasData) syncAnimatedStats(true)
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

          PanelHero {
            width: parent.width
            title: "Cursor"
            meta: root.heroMeta
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.loading ? 0.7 : (root.iconError ? 1 : (root.iconActive ? 1 : 0.7))

            iconComponent: Component {
              Text {
                text: "󰁨"
                color: root.iconError ? root.urgent : root.cursorColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                opacity: 0.92
              }
            }
          }

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

          Row {
            visible: !root.isError && (root.showTokens || root.cycleDaysTotal > 0)
            width: parent.width
            spacing: Style.space(8)

            PanelStatTile {
              visible: root.showTokens
              width: root.usageStatTileCount > 0
                ? (parent.width - parent.spacing * (root.usageStatTileCount - 1)) / root.usageStatTileCount
                : parent.width
              loading: root.loading
              value: Model.formatTokens(root.detail.tokensTotal || 0)
              label: "tokens"
              foreground: root.foreground
              dim: root.dim
              fontFamily: root.fontFamily
            }

            PanelStatTile {
              visible: root.showTokens
              width: root.usageStatTileCount > 0
                ? (parent.width - parent.spacing * (root.usageStatTileCount - 1)) / root.usageStatTileCount
                : parent.width
              loading: root.loading
              value: Model.formatTokens(root.detail.tokensToday || 0)
              label: "today"
              valueColor: root.accent
              foreground: root.foreground
              dim: root.dim
              fontFamily: root.fontFamily
            }

            PanelStatTile {
              visible: root.cycleDaysTotal > 0
              width: root.usageStatTileCount > 0
                ? (parent.width - parent.spacing * (root.usageStatTileCount - 1)) / root.usageStatTileCount
                : parent.width
              loading: root.loading
              value: root.loading ? "…" : String(Model.cycleDaysLeft(root.data))
              cycleSuffix: root.loading ? "" : (Model.cycleDaysLeft(root.data) === 1 ? "day left" : "days left")
              label: ""
              valueColor: root.cycleColor
              foreground: root.foreground
              dim: root.dim
              fontFamily: root.fontFamily
              showCycleChart: true
              cycleDaysTotal: root.cycleDaysTotal
              cycleDaysUsed: root.cycleDaysUsed
              accent: root.accent
              palette: root.palette
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

                UsageGauge {
                  width: root.gaugeSize
                  percent: root.shownCursorPercent
                  gaugeColor: root.cursorColor
                  title: "Cursor"
                  titleColor: root.cursorColor
                  loading: root.loading
                  gaugeSize: root.gaugeSize
                  labelFontSize: root.gaugeLabelFont
                  foreground: root.foreground
                  trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
                  fontFamily: root.fontFamily
                  celebrateToken: root.usageCelebrateToken
                }

                UsageGauge {
                  width: root.gaugeSize
                  percent: root.shownOtherPercent
                  gaugeColor: root.otherColor
                  title: "Other"
                  titleColor: root.otherColor
                  loading: root.loading
                  gaugeSize: root.gaugeSize
                  labelFontSize: root.gaugeLabelFont
                  foreground: root.foreground
                  trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
                  fontFamily: root.fontFamily
                }
              }
            }
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
              required property int index
              width: column.width
              spacing: Style.spacing.xs
              visible: !root.isError

              readonly property color barColor: Model.breakdownBarColor(root.palette, index)

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
                  color: barColor
                  opacity: 0.85
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(12)

                Text {
                  width: parent.width - detailText.implicitWidth - parent.spacing
                  text: Model.modelLabel(modelData.model)
                  color: root.palette[0]
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  id: detailText
                  text: root.loading
                    ? "…"
                    : Math.round(modelData.percent) + "% · "
                      + Model.formatTokens(modelData.tokens)
                  color: root.palette[0]
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
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

    property real percent: 0
    property color gaugeColor: Color.accent
    property bool loading: false
    property int gaugeSize: 130
    property int labelFontSize: Style.font.body
    property color foreground: Color.foreground
    property color trackColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
    property string fontFamily: Style.font.family
    property int celebrateToken: 0
    property string title: ""
    property color titleColor: gaugeColor

    property real popScale: 1

    onCelebrateTokenChanged: if (celebrateToken > 0) popAnim.restart()

    implicitWidth: gaugeRoot.gaugeSize
    implicitHeight: ring.height
    scale: popScale
    transformOrigin: Item.Center

    SequentialAnimation {
      id: popAnim
      NumberAnimation {
        target: gaugeRoot
        property: "popScale"
        to: 1.06
        duration: 140
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: gaugeRoot
        property: "popScale"
        to: 1
        duration: 220
        easing.type: Easing.OutBack
      }
    }

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

    Column {
      anchors.centerIn: ring
      spacing: Style.spacing.xs

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: gaugeRoot.loading ? "…" : (Math.round(gaugeRoot.percent) + "%")
        color: gaugeRoot.foreground
        font.family: gaugeRoot.fontFamily
        font.pixelSize: gaugeRoot.labelFontSize
        font.bold: true
      }

      Text {
        visible: gaugeRoot.title !== "" && !gaugeRoot.loading
        anchors.horizontalCenter: parent.horizontalCenter
        text: gaugeRoot.title
        color: gaugeRoot.titleColor
        font.family: gaugeRoot.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
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
    property bool loading: false
    property bool showCycleChart: false
    property string cycleSuffix: ""
    property int cycleDaysTotal: 0
    property int cycleDaysUsed: 0
    property color accent: Color.accent
    property var palette: []

    readonly property string displayValue: loading ? "…" : value

    readonly property color cycleTrackColor: palette && palette.length ? palette[0] : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.22)
    readonly property real cycleFill: cycleDaysTotal > 0
      ? Math.max(0, Math.min(1, cycleDaysUsed / cycleDaysTotal))
      : 0

    readonly property real cycleChartPad: Math.max(0, cycleLabelMetric.implicitHeight - Style.space(4) - Style.space(3))

    Text {
      id: cycleLabelMetric
      visible: false
      text: "today"
      font.family: tileRoot.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

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
        visible: !tileRoot.showCycleChart
        width: parent.width
        text: tileRoot.displayValue
        color: tileRoot.valueColor
        font.family: tileRoot.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }

      Row {
        visible: tileRoot.showCycleChart
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.spacing.xs

        Text {
          text: tileRoot.displayValue
          color: tileRoot.valueColor
          font.family: tileRoot.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          visible: !tileRoot.loading && tileRoot.cycleSuffix !== ""
          text: tileRoot.cycleSuffix
          color: tileRoot.valueColor
          font.family: tileRoot.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Text {
        visible: tileRoot.label !== ""
        width: parent.width
        text: tileRoot.label
        color: tileRoot.dim
        font.family: tileRoot.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }

      Item {
        id: cycleChart
        width: parent.width
        height: tileRoot.showCycleChart
          ? Style.space(4) + tileRoot.cycleChartPad + Style.space(3)
          : Style.space(4)
        visible: tileRoot.showCycleChart && tileRoot.cycleDaysTotal > 0

        Rectangle {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(3)
          width: parent.width
          height: Style.space(4)
          radius: height / 2
          color: tileRoot.cycleTrackColor
          opacity: 0.35
        }

        Rectangle {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(3)
          height: Style.space(4)
          width: parent.width * tileRoot.cycleFill
          radius: height / 2
          color: tileRoot.valueColor
        }
      }
    }
  }
}
