import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Services.Notifications
import qs.services
import qs.commons

PanelWindow {
  id: root

  implicitWidth: ScalerService.s(430)
  anchors {
    top: true
  }
  margins {
    top: ScalerService.s(10)
  }
  exclusiveZone: 0
  visible: notificationModel.count > 0
  color: "transparent"

  // Cấu hình kích thước cố định
  property int maxNotifications: 4
  property int notificationHeight: ScalerService.s(100)
  property int notificationSpacing: ScalerService.s(10)
  property int containerMargin: ScalerService.s(10)

  // Tính toán chiều cao dựa trên số lượng thông báo
  implicitHeight: containerMargin * 2 + notificationList.contentHeight

  Behavior on implicitHeight {
    NumberAnimation {
      duration: 10
      easing.type: Easing.OutCubic
    }
  }

  function notifLive(notification) {
    if (!notification)
      return false;
    try {
      return !notification.Retainable.retained;
    } catch (e) {
      return false;
    }
  }

  function safeDismiss(notification) {
    if (notifLive(notification)) {
      try {
        notification.dismiss();
      } catch (e) {}
    }
  }

  function rowIndexOf(notificationId) {
    for (var i = 0; i < notificationModel.count; i++) {
      if (notificationModel.get(i).notificationId === notificationId)
        return i;
    }
    return -1;
  }

  function closeRow(notificationId) {
    root.setRowClosing(notificationId, true);
  }

  function setRowClosing(notificationId, value) {
    var i = rowIndexOf(notificationId);
    if (i >= 0)
      notificationModel.setProperty(i, "closing", value);
  }

  function removeRow(notificationId) {
    var i = rowIndexOf(notificationId);
    if (i >= 0)
      notificationModel.remove(i);
  }

  // Container chính cho popup
  Rectangle {
    anchors.fill: parent
    color: "transparent"

    // Danh sách notification
    ListView {
      id: notificationList
      anchors.fill: parent
      anchors.margins: ScalerService.s(10)
      spacing: ScalerService.s(10)
      clip: true
      model: ListModel {
        id: notificationModel
      }
      interactive: false

      // Giới hạn chiều cao tối đa
      property int maxHeight: maxNotifications * (notificationHeight + notificationSpacing)
      height: Math.min(contentHeight, maxHeight)

      Behavior on height {
        NumberAnimation {
          duration: 10
          easing.type: Easing.OutCubic
        }
      }

      delegate: Rectangle {
        id: notificationDelegate
        width: notificationList.width
        height: isExpanded ? contentColumn.implicitHeight + ScalerService.s(24) : notificationHeight
        border.color: theme.button.border
        radius: ScalerService.s(Settings.appearance.radius1)
        border.width: Settings.appearance.enableBorder ? ScalerService.s(3) : 0
        color: theme.primary.background

        property var notification: notificationRef || null
        property string appName: notification ? notification.appName : ""
        property string summary: notification ? notification.summary : ""
        property string body: notification ? notification.body : ""
        property int urgency: notification ? notification.urgency : NotificationUrgency.Normal
        property var actions: notification ? notification.actions : []
        property real expireTimeout: notification ? notification.expireTimeout : -1
        property bool isExpanded: false
        property bool hasLongContent: false
        readonly property bool isClosing: model.closing

        onIsClosingChanged: {
          if (isClosing)
            removalTimer.restart();
        }

        Component.onCompleted: {
          if (isClosing)
            removalTimer.restart();
        }

        Behavior on height {
          NumberAnimation {
            duration: 20
            easing.type: Easing.OutCubic
          }
        }

        // Hiệu ứng mờ dần khi xóa
        opacity: model.closing ? 0 : 1
        Behavior on opacity {
          NumberAnimation {
            duration: 200
          }
        }

        // Timer tự động xóa
        Timer {
          id: autoDismiss
          interval: notificationDelegate.expireTimeout > 0 ? notificationDelegate.expireTimeout : 10000
          running: notificationDelegate.expireTimeout !== 0
          onTriggered: {
            if (!notificationDelegate.isClosing)
              notificationDelegate.removeNotification();
          }
        }

        Connections {
          target: notificationDelegate.notification
          ignoreUnknownSignals: true

          function onSummaryChanged() {
            notificationDelegate.resetForUpdate();
          }
          function onBodyChanged() {
            notificationDelegate.resetForUpdate();
          }
          function onAppNameChanged() {
            notificationDelegate.resetForUpdate();
          }
          function onUrgencyChanged() {
            notificationDelegate.resetForUpdate();
          }
          function onActionsChanged() {
            notificationDelegate.resetForUpdate();
          }
          function onExpireTimeoutChanged() {
            notificationDelegate.resetForUpdate();
          }
        }

        Column {
          id: contentColumn
          anchors.fill: parent
          anchors.margins: ScalerService.s(12)
          spacing: ScalerService.s(6)

          // Header với app icon và tên
          Row {
            width: parent.width
            spacing: ScalerService.s(8)
            height: ScalerService.s(24)

            Rectangle {
              width: ScalerService.s(24)
              height: ScalerService.s(24)
              radius: ScalerService.s(12)
              color: {
                switch (notificationDelegate.urgency) {
                  case NotificationUrgency.Critical:
                  return theme.normal.red;
                  case NotificationUrgency.Normal:
                  return theme.normal.blue;
                  case NotificationUrgency.Low:
                  return theme.normal.green;
                  default:
                  return theme.button.background;
                }
              }

              Text {
                anchors.centerIn: parent
                text: notificationDelegate.appName ? notificationDelegate.appName.charAt(0).toUpperCase() : "N"
                font.bold: true
                color: theme.primary.background
                font.pixelSize: ScalerService.s(12)
              }
            }

            Text {
              text: notificationDelegate.appName || "Unknown App"
              font.bold: true
              color: theme.button.text
              elide: Text.ElideRight
              width: parent.width - (hasLongContent ? ScalerService.s(104) : ScalerService.s(80))
              font.pixelSize: ScalerService.s(12)
            }

            // Expand button (only show if content is long)
            MouseArea {
              width: ScalerService.s(24)
              height: ScalerService.s(24)
              anchors.verticalCenter: parent.verticalCenter
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              visible: hasLongContent
              onClicked: isExpanded = !isExpanded

              Rectangle {
                anchors.fill: parent
                radius: ScalerService.s(12)
                color: parent.containsMouse ? theme.button.background_select : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: isExpanded ? "▲" : "▼"
                  font.pixelSize: ScalerService.s(10)
                  color: parent.parent.containsMouse ? theme.primary.foreground : theme.primary.dim_foreground
                  font.bold: true
                }
              }
            }

            // Close button
            MouseArea {
              width: ScalerService.s(24)
              height: ScalerService.s(24)
              anchors.verticalCenter: parent.verticalCenter
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: dismissNotification()

              Rectangle {
                anchors.fill: parent
                radius: ScalerService.s(12)
                color: parent.containsMouse ? theme.normal.red : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: "×"
                  font.pixelSize: ScalerService.s(16)
                  color: parent.parent.containsMouse ? theme.primary.foreground : theme.primary.dim_foreground
                  font.bold: true
                }
              }
            }
          }

          // Tiêu đề
          Text {
            id: summaryText
            width: parent.width
            text: notificationDelegate.summary
            font.bold: true
            font.pixelSize: ScalerService.s(14)
            wrapMode: Text.WordWrap
            color: theme.primary.foreground
            maximumLineCount: isExpanded ? 2 : 1
            elide: Text.ElideRight
          }

          // Nội dung
          Text {
            id: bodyText
            width: parent.width
            text: notificationDelegate.body
            font.pixelSize: ScalerService.s(12)
            wrapMode: Text.WordWrap
            color: theme.primary.foreground
            maximumLineCount: isExpanded ? 5 : 2
            elide: Text.ElideRight

            onTruncatedChanged: {
              if (!isExpanded) {
                hasLongContent = truncated;
              }
            }

            Component.onCompleted: {
              Qt.callLater(function () {
                  if (!isExpanded) {
                    hasLongContent = truncated;
                  }
              });
            }
          }

          // Actions (nếu có)
          Flow {
            width: parent.width
            spacing: ScalerService.s(5)
            visible: notificationDelegate.actions.length > 0

            Repeater {
              model: notificationDelegate.actions

              Rectangle {
                height: ScalerService.s(26)
                width: Math.min(actionText.width + ScalerService.s(16), ScalerService.s(120))
                radius: ScalerService.s(5)
                color: {
                  switch (notificationDelegate.urgency) {
                    case NotificationUrgency.Critical:
                    return theme.normal.red;
                    case NotificationUrgency.Normal:
                    return theme.normal.blue;
                    case NotificationUrgency.Low:
                    return theme.normal.green;
                    default:
                    return theme.button.background;
                  }
                }

                Text {
                  id: actionText
                  anchors.centerIn: parent
                  text: modelData.text || modelData.identifier
                  color: theme.primary.foreground
                  font.pixelSize: ScalerService.s(10)
                  font.bold: true
                  elide: Text.ElideRight
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    try {
                      modelData.invoke();
                    } catch (e) {}
                  }
                }
              }
            }
          }
        }

        function resetForUpdate() {
          removalTimer.stop();
          root.setRowClosing(model.notificationId, false);
          autoDismiss.stop();
          if (expireTimeout !== 0)
            autoDismiss.restart();
        }

        function removeNotification() {
          if (root.notifLive(notification)) {
            try {
              notification.expire();
              return;
            } catch (e) {}
          }
          root.closeRow(model.notificationId);
        }

        function dismissNotification() {
          if (root.notifLive(notification)) {
            try {
              notification.dismiss();
              return;
            } catch (e) {}
          }
          root.closeRow(model.notificationId);
        }

        Timer {
          id: removalTimer
          interval: 200
          onTriggered: {
            var ref = notificationDelegate.notification;
            root.removeRow(model.notificationId);
            root.safeDismiss(ref);
          }
        }
      }
    }
  }

  NotificationServer {
    id: server
    actionsSupported: true
    imageSupported: true
    inlineReplySupported: true

    onNotification: function (notification) {
      notification.tracked = true;

      var nid = notification.id;
      notification.closed.connect(function (reason) {
        root.closeRow(nid);
      });

      var existing = root.rowIndexOf(notification.id);
      if (existing >= 0) {
        notificationModel.setProperty(existing, "notificationRef", notification);
      } else {
        notificationModel.insert(0, {
            notificationId: notification.id,
            notificationRef: notification,
            closing: false
        });
      }

      // Giữ tối đa 4 notification
      while (notificationModel.count > maxNotifications) {
        var victimRef = notificationModel.get(notificationModel.count - 1).notificationRef;
        notificationModel.remove(notificationModel.count - 1);
        root.safeDismiss(victimRef);
      }
    }
  }
}
