import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.commons
import qs.components
import "." as Com

PanelWindow {
  id: root

  property string selectedFlag: Settings.appearance.countryFlag
  property real animationProgress: 0

  SequentialAnimation on animationProgress {
    running: true

    NumberAnimation {
      from: 0
      to: 1
      duration: 500
      easing.type: Easing.Linear
    }
  }

  implicitWidth: ScalerService.s(600)
  implicitHeight: ScalerService.s(380)

    property var flagList: [
      { name: "japan", displayName: "Japan" },
      { name: "usa", displayName: "United States" },
      { name: "spain", displayName: "Spain" },
      { name: "russia", displayName: "Russia" }
    ]

  anchors {
    top: Settings.bar.position === "top"
    bottom: Settings.bar.position === "bottom"
    left: Settings.bar.position === "top" || Settings.bar.position === "bottom" || Settings.bar.position === "left"
    right: Settings.bar.position === "right"
  }

  margins {
    top: Settings.bar.position === "top" ? ScalerService.s(10) : 0
    bottom: Settings.bar.position === "bottom" ? ScalerService.s(10) : 0
    left: (Settings.bar.position === "top" || Settings.bar.position === "bottom") ? ScalerService.s(720) : ScalerService.s(10)
    right: Settings.bar.position === "right" ? ScalerService.s(10) : 0
  }

  exclusiveZone: 0
  color: "transparent"

  Rectangle {
    anchors.centerIn: parent
    implicitWidth: root.animationProgress > 0 ? parent.width : 0
    implicitHeight: root.animationProgress > 0 ? parent.height : 0
    Behavior on implicitHeight {
      NumberAnimation {
        id: heightAnim
        duration: 500
        easing.type: Easing.OutCubic
      }
    }
    Behavior on implicitWidth {
      NumberAnimation {
        id: widthAnim
        duration: 500
        easing.type: Easing.OutCubic
      }
    }
    Loader {
      anchors.fill: parent

      active: !heightAnim.running && !widthAnim.running

      sourceComponent: FloatingCircles {
        circleColor: theme.button.text
        anchors.fill: parent
        circleCount: 2
        minOpacity: 0.02
        maxOpacity: 0.04
      }
    }
    color: theme.primary.background
    border.color: theme.button.border
    radius: ScalerService.s(Settings.appearance.radius1)
    border.width: Settings.appearance.enableBorder ? ScalerService.s(3) : 0

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: ScalerService.s(20)
      spacing: ScalerService.s(15)

      Com.FlagHeader {
        animationProgress: root.animationProgress
        Layout.fillWidth: true
        Layout.preferredHeight: ScalerService.s(40)
      }

      Com.FlagGrid {
        Layout.fillWidth: true
        Layout.fillHeight: true
        flagList: root.flagList
        selectedFlag: root.selectedFlag
        animationProgress: root.animationProgress
      }

      Com.FlagFooter {
        selectedFlag: root.selectedFlag
        animationProgress: root.animationProgress
      }
    }
    Loader {
      anchors.fill: parent

      active: !heightAnim.running && !widthAnim.running

      sourceComponent:     StarField {
        starCount: 10
        shootingStarCount: 2
      }
    }
  }
}
