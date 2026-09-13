// PanelWindow cập nhật
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.commons
import Quickshell.Services.SystemTray
import qs.components
import qs.services

PanelWindow {
  id: root

  // Sử dụng TrayService thay vì SystemTray trực tiếp
  property int trayCount: TrayService.validTrayCount  // Sử dụng validTrayCount
  property int maxColumns: 4
  property int actualColumns: Math.min(trayCount, maxColumns)
  property int actualRows: Math.ceil(trayCount / maxColumns)
  
  property real trayItemSize: ScalerService.s(36)
  property real traySpacing: ScalerService.s(6)
  property real trayPadding: ScalerService.s(10)
  property real minimumPanelWidth: ScalerService.s(120)
  property real barThickness: (Settings.bar.position === "left" || Settings.bar.position === "right") ? (Settings.bar.style === "style2" ? ScalerService.s(38) : (Settings.bar.style === "style3" ? ScalerService.s(35) : ScalerService.s(40))) : (Settings.bar.style === "style2" ? ScalerService.s(40) : ScalerService.s(50))
  property real popupGap: ScalerService.s(10)

  // Keep native SNI menus anchored to the clicked tray icon.
  function showItemMenu(item, sourceItem) {
    var point = sourceItem.mapToItem(backgroundRect, sourceItem.width / 2, sourceItem.height / 2);
    item.display(root, Math.round(point.x), Math.round(point.y));
  }
  
  property real calculatedWidth: {
    if (trayCount === 0) return ScalerService.s(180);
    var cols = Math.min(trayCount, maxColumns);
    var itemWidth = trayItemSize;
    var spacing = traySpacing;
    var padding = trayPadding * 2;
    return Math.max(minimumPanelWidth, cols * itemWidth + (cols - 1) * spacing + padding);
  }
  
  property real calculatedHeight: {
    if (trayCount === 0) return ScalerService.s(60);
    var rows = actualRows;
    var itemHeight = trayItemSize;
    var spacing = traySpacing;
    var padding = trayPadding * 2;
    return rows * itemHeight + (rows - 1) * spacing + padding;
  }

  implicitWidth: calculatedWidth
  implicitHeight: calculatedHeight
  
  // Animation khi mở/đóng
  property real animationProgress: 0
  SequentialAnimation on animationProgress {
    running: true
    NumberAnimation {
      from: 0
      to: 1
      duration: 300
      easing.type: Easing.OutCubic
    }
  }
  
  Behavior on implicitHeight {
    NumberAnimation {
      duration: 200
      easing.type: Easing.OutCubic
    }
  }
  Behavior on implicitWidth {
    NumberAnimation {
      duration: 200
      easing.type: Easing.OutCubic
    }
  }

  anchors {
    left: Settings.bar.position === "left"
    right: Settings.bar.position === "right" || Settings.bar.position === "top" || Settings.bar.position === "bottom"
    top: Settings.bar.position === "top"
    bottom: Settings.bar.position === "left" || Settings.bar.position === "right" || Settings.bar.position === "bottom"
  }

  margins {
    top: Settings.bar.position === "top" ? root.barThickness + root.popupGap : 0
    bottom: Settings.bar.position === "bottom" ? root.barThickness + root.popupGap : (Settings.bar.position === "left" || Settings.bar.position === "right" ? root.popupGap : 0)
    left: Settings.bar.position === "left" ? root.barThickness + root.popupGap : 0
    right: Settings.bar.position === "right" ? root.barThickness + root.popupGap : (Settings.bar.position === "top" || Settings.bar.position === "bottom" ? ScalerService.s(300) : 0)
  }
  
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.exclusiveZone: 0
  // Make the popup an interactive Wayland surface.  Without an explicit
  // focusable window, SNI context menus (including Quit/Close) are ignored by
  // some applications under the direct Hyprland session.
  focusable: true

  // Background với hiệu ứng mờ (acrylic) giống Windows 11
  Rectangle {
    id: backgroundRect
    anchors.fill: parent
    implicitWidth: root.animationProgress > 0 ? parent.width : 0
    implicitHeight: root.animationProgress > 0 ? parent.height : 0
    
    Behavior on implicitHeight {
      NumberAnimation {
        id: heightAnim
        duration: 300
        easing.type: Easing.OutCubic
      }
    }
    Behavior on implicitWidth {
      NumberAnimation {
        id: widthAnim
        duration: 300
        easing.type: Easing.OutCubic
      }
    }
    
    color: theme.primary.background
    clip: true
    border.color: theme.button.border
    radius: ScalerService.s(Settings.appearance.radius1)
    border.width: Settings.appearance.enableBorder ? ScalerService.s(3) : 0
    
    // Grid System Tray - Windows 11 Style
    GridLayout {
      id: trayGrid
      anchors.fill: parent
      anchors.margins: root.trayPadding
      columns: Math.max(1, Math.min(root.trayCount, root.maxColumns))
      rowSpacing: traySpacing
      columnSpacing: traySpacing
      
      Repeater {
        id: trayRepeater
        model: TrayService.items

        Rectangle {
          id: trayItemContainer
          Layout.preferredWidth: trayItemSize
          Layout.preferredHeight: trayItemSize
          Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
          color: "transparent"
          radius: ScalerService.s(8)
          transformOrigin: Item.Center

          visible: modelData.icon !== ""
          property var trayItem: modelData

          Image {
            id: trayIcon
            anchors.centerIn: parent
            width: ScalerService.s(24)
            height: ScalerService.s(24)
            source: trayItemContainer.trayItem?.icon || ""
            fillMode: Image.PreserveAspectFit
            smooth: true
          }

          MouseArea {
            id: trayTooltipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onEntered: {
              trayItemContainer.scale = 1.05
            }
            onPressed: {
              trayItemContainer.scale = 0.92
            }
            onReleased: {
              trayItemContainer.scale = containsMouse ? 1.05 : 1.0
            }

            onClicked: function (mouse) {
              if (!trayItemContainer.trayItem)
                return;
              if (mouse.button === Qt.LeftButton) {
                trayItemContainer.trayItem.secondaryActivate();
              } else if (mouse.button === Qt.RightButton) {
                if (trayItemContainer.trayItem.hasMenu) {
                  // display() expects coordinates in the parent window.
                  showItemMenu(trayItemContainer.trayItem, trayItemContainer);
                } else {
                  // Some status items have no menu but still implement the
                  // secondary action (often a close/quit action).
                  trayItemContainer.trayItem.secondaryActivate();
                }
              }
            }

            onWheel: function (wheel) {
              if (!trayItemContainer.trayItem)
                return;
              trayItemContainer.trayItem.scroll(wheel.angleDelta.y, wheel.angleDelta.x !== 0);
            }
          }

          Behavior on scale {
            NumberAnimation {
              duration: 100
              easing.type: Easing.OutCubic
            }
          }
        }
      }
    }
  }

  Component.onCompleted: {
    console.log("PanelWindow tray items:", TrayService.items.values.length)
    console.log("Valid tray items:", TrayService.validTrayCount)
  }
}
