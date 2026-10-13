import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.components

Rectangle {
  id: passwordBox
  property var wifiManager
  property var networkData

  property bool showPassword: false
  property bool hasError: false
  property string errorMessage: ""
  readonly property bool hasSavedConnection: !!networkData.hasSavedConnection
  readonly property bool isConnected: networkData.ssid === wifiManager.connectedWifi
  readonly property bool isOpenNetwork: networkData.security === "--" || networkData.security === "Open" || networkData.security === ""
  readonly property bool busy: wifiManager.connectionInProgress || wifiManager.forgetInProgress
  readonly property bool connecting: wifiManager.connectionInProgress && wifiManager.currentAttemptSSID === networkData.ssid
  property bool useNewPassword: false
  property bool attemptPending: false
  property bool forgetPending: false

  implicitHeight: content.implicitHeight + ScalerService.s(24)
  color: theme.primary.dim_background
  radius: ScalerService.s(12)
  border.width: ScalerService.s(2)
  border.color: theme.button.border_select

  Behavior on height {
    NumberAnimation {
      duration: 200
    }
  }

  function connect(useSavedConnection) {
    if (busy)
      return;
    const password = useSavedConnection || isOpenNetwork ? undefined : wifiPassword.text;
    if (!useSavedConnection && !isOpenNetwork && password.length === 0) {
      hasError = true;
      errorMessage = lang?.wifi?.password_required || "Enter password";
      return;
    }
    hasError = false;
    errorMessage = "";
    attemptPending = wifiManager.connectToWifi(networkData.ssid, password);
  }

  Connections {
    target: wifiManager

    function onConnectionFinished(ssid, success, errorMessage) {
      if (!passwordBox.attemptPending || ssid !== passwordBox.networkData.ssid)
        return;
      passwordBox.attemptPending = false;
      passwordBox.hasError = !success;
      passwordBox.errorMessage = errorMessage;
      if (success) {
        wifiPassword.text = "";
        passwordBox.showPassword = false;
        passwordBox.useNewPassword = false;
        wifiManager.userTyping = false;
        wifiManager.openSsid = "";
      } else if (passwordBox.hasSavedConnection && !passwordBox.isOpenNetwork) {
        passwordBox.useNewPassword = true;
      }
    }

    function onForgetFinished(ssid, success) {
      if (!passwordBox.forgetPending || ssid !== passwordBox.networkData.ssid)
        return;
      passwordBox.forgetPending = false;
      passwordBox.hasError = !success;
      passwordBox.errorMessage = success ? "" : (lang?.wifi?.forget_failed || "Could not forget the saved connection.");
      if (success) {
        wifiPassword.text = "";
        wifiManager.userTyping = false;
        wifiManager.openSsid = "";
      }
    }

    function onConnectionInProgressChanged() {
      if (!wifiManager.connectionInProgress && wifiManager.currentAttemptSSID === "")
        passwordBox.attemptPending = false;
    }
  }

  ColumnLayout {
    id: content
    anchors.fill: parent
    anchors.margins: ScalerService.s(12)
    spacing: ScalerService.s(8)

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: errorText.implicitHeight + ScalerService.s(12)
      visible: passwordBox.hasError
      color: theme.normal.red
      radius: ScalerService.s(6)
      Text {
        id: errorText
        anchors.centerIn: parent
        width: parent.width - ScalerService.s(12)
        text: passwordBox.errorMessage
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        color: theme.primary.foreground
        font.pixelSize: ScalerService.s(12)
        font.family: "ComicShannsMono Nerd Font"
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: ScalerService.s(8)
      visible: !passwordBox.useNewPassword && (passwordBox.hasSavedConnection || passwordBox.isOpenNetwork)

      Text {
        Layout.fillWidth: true
        text: passwordBox.hasSavedConnection ? (lang?.wifi?.saved_connection || "Saved connection") : (lang?.wifi?.no_password || "No password required")
        wrapMode: Text.Wrap
        font.family: "ComicShannsMono Nerd Font"
        color: theme.primary.foreground
        font.pixelSize: ScalerService.s(14)
      }

      ButtonText {
        name: passwordBox.connecting ? (lang?.wifi?.connecting || "Connecting…") : (lang?.wifi?.connect || "Connect")
        size: "xs"
        implicitHeight: ScalerService.s(30)
        visible: !passwordBox.isConnected
        enabled: !passwordBox.busy
        opacity: enabled ? 1 : 0.5
        onClicked: passwordBox.connect(true)
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: ScalerService.s(8)
      visible: !passwordBox.isOpenNetwork && (!passwordBox.hasSavedConnection || passwordBox.useNewPassword)

      TextField {
        id: wifiPassword
        Layout.fillWidth: true
        implicitHeight: ScalerService.s(40)
        placeholderText: lang?.wifi?.enter_password || "Enter password"
        echoMode: passwordBox.showPassword ? TextInput.Normal : TextInput.Password
        enabled: !passwordBox.busy
        font.family: "ComicShannsMono Nerd Font"
        font.pixelSize: ScalerService.s(14)
        horizontalAlignment: TextInput.AlignHCenter
        color: theme.primary.foreground
        background: Rectangle {
          color: theme.primary.background
          radius: ScalerService.s(8)
          border.color: theme.button.border_select
          border.width: ScalerService.s(1)
        }
        onActiveFocusChanged: wifiManager.userTyping = activeFocus
        onAccepted: passwordBox.connect(false)
      }

      ButtonText {
        name: passwordBox.showPassword ? "visibility" : "visibility_off"
        size: "xs"
        implicitHeight: ScalerService.s(30)
        fontFamily: "Material Symbols Rounded"
        enabled: !passwordBox.busy
        opacity: enabled ? 1 : 0.5
        onClicked: passwordBox.showPassword = !passwordBox.showPassword
      }

      ButtonText {
        name: passwordBox.connecting ? (lang?.wifi?.connecting || "Connecting…") : (lang?.wifi?.connect || "Connect")
        size: "xs"
        implicitHeight: ScalerService.s(30)
        enabled: !passwordBox.busy
        opacity: enabled ? 1 : 0.5
        onClicked: passwordBox.connect(false)
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: ScalerService.s(8)
      visible: passwordBox.hasSavedConnection

      ButtonText {
        name: passwordBox.useNewPassword ? (lang?.wifi?.use_saved_connection || "Use saved connection") : (lang?.wifi?.change_password || "Change password")
        size: "xs"
        implicitHeight: ScalerService.s(30)
        visible: !passwordBox.isOpenNetwork
        enabled: !passwordBox.busy
        opacity: enabled ? 1 : 0.5
        onClicked: passwordBox.useNewPassword = !passwordBox.useNewPassword
      }

      Item { Layout.fillWidth: true }

      ButtonText {
        name: lang?.wifi?.forget || "Forget"
        size: "xs"
        implicitHeight: ScalerService.s(30)
        enabled: !passwordBox.busy
        opacity: enabled ? 1 : 0.5
        onClicked: {
          passwordBox.hasError = false;
          passwordBox.errorMessage = "";
          passwordBox.forgetPending = wifiManager.forgetPassword(networkData.ssid);
        }
      }
    }
  }
}
