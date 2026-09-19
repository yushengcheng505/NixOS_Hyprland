// Audio device settings
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.commons
import qs.services

Item {
  id: root
  property var lang: LanguageService.translations

  readonly property var outputDevices: devicesFor(PwNodeType.AudioSink)
  readonly property var inputDevices: devicesFor(PwNodeType.AudioSource)
  readonly property var outputNames: outputDevices.map(root.deviceName)
  readonly property var inputNames: inputDevices.map(root.deviceName)
  // Keep the larger cards inside the settings panel on short displays.
  readonly property real deviceCardHeight: Math.min(
    ScalerService.s(150),
    Math.max(ScalerService.s(112), (root.height - ScalerService.s(132)) / 2)
  )

  function devicesFor(typeFlag) {
    var devices = [];
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      // `ready` only becomes true after a node is explicitly bound by Quickshell.
      // Hardware sources can be valid and selectable before that happens.
      if (node && node.audio && !node.isStream && (node.type & typeFlag) === typeFlag)
        devices.push(node);
    }
    return devices;
  }

  function deviceName(node) {
    if (!node)
      return "Unknown device";
    return String(node.description || node.nickname || node.name || "Unknown device");
  }

  function deviceIndex(devices, current) {
    if (!current)
      return -1;
    for (var i = 0; i < devices.length; i++) {
      if (devices[i].id === current.id)
        return i;
    }
    return -1;
  }

  function selectOutput(index) {
    if (index >= 0 && index < outputDevices.length)
      Pipewire.preferredDefaultAudioSink = outputDevices[index];
  }

  function selectInput(index) {
    if (index >= 0 && index < inputDevices.length)
      Pipewire.preferredDefaultAudioSource = inputDevices[index];
  }

  function syncSelection() {
    if (outputCombo)
      outputCombo.currentIndex = deviceIndex(outputDevices, Pipewire.defaultAudioSink);
    if (inputCombo)
      inputCombo.currentIndex = deviceIndex(inputDevices, Pipewire.defaultAudioSource);
  }

  Connections {
    target: Pipewire

    function onDefaultAudioSinkChanged() {
      if (outputCombo)
        outputCombo.currentIndex = root.deviceIndex(root.outputDevices, Pipewire.defaultAudioSink);
    }

    function onDefaultAudioSourceChanged() {
      if (inputCombo)
        inputCombo.currentIndex = root.deviceIndex(root.inputDevices, Pipewire.defaultAudioSource);
    }
  }

  onOutputDevicesChanged: syncSelection()
  onInputDevicesChanged: syncSelection()

  Component.onCompleted: syncSelection()

  ScrollView {
    anchors.fill: parent
    anchors.topMargin: ScalerService.s(20)
    anchors.bottomMargin: ScalerService.s(20)
    anchors.leftMargin: ScalerService.s(10)
    anchors.rightMargin: ScalerService.s(10)
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: ScalerService.s(20)

      RowLayout {
        Layout.fillWidth: true
        spacing: ScalerService.s(10)

        Item {
          Layout.fillWidth: true
        }

        Text {
          text: "Audio Settings"
          color: theme.primary.foreground
          font.pixelSize: ScalerService.s(24)
          font.bold: true
          font.family: "ComicShannsMono Nerd Font"
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: ScalerService.s(1)
        color: theme.primary.foreground
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.deviceCardHeight
        color: Qt.alpha(theme.primary.background, 0.35)
        border.color: theme.button.border
        border.width: Settings.appearance.enableBorder ? ScalerService.s(1) : 0
        radius: ScalerService.s(Settings.appearance.radius2)

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: ScalerService.s(14)
          spacing: ScalerService.s(8)

          Text {
            text: root.lang?.mixer?.output_device || "Output Device"
            color: theme.primary.foreground
            font.pixelSize: ScalerService.s(15)
            font.bold: true
            font.family: "ComicShannsMono Nerd Font"
          }

          ComboBox {
            id: outputCombo
            Layout.fillWidth: true
            model: root.outputNames
            enabled: root.outputDevices.length > 0
            displayText: currentIndex >= 0 ? root.outputNames[currentIndex] : "No output devices available"
            onActivated: selectedIndex => root.selectOutput(selectedIndex)

            contentItem: Text {
              leftPadding: ScalerService.s(10)
              rightPadding: ScalerService.s(30)
              text: outputCombo.displayText
              color: outputCombo.enabled ? theme.primary.foreground : theme.primary.dim_foreground
              font.family: "ComicShannsMono Nerd Font"
              font.pixelSize: ScalerService.s(13)
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }

            background: Rectangle {
              color: theme.button.background
              border.color: outputCombo.activeFocus ? theme.button.border_select : theme.button.border
              border.width: ScalerService.s(1)
              radius: ScalerService.s(4)
            }

            delegate: ItemDelegate {
              width: outputCombo.width
              highlighted: outputCombo.highlightedIndex === index
              contentItem: Text {
                text: modelData
                color: highlighted ? theme.primary.foreground : theme.primary.dim_foreground
                font.family: "ComicShannsMono Nerd Font"
                font.pixelSize: ScalerService.s(13)
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
              }
              background: Rectangle {
                color: highlighted ? Qt.alpha(theme.accent, 0.3) : theme.button.background
              }
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.deviceCardHeight
        color: Qt.alpha(theme.primary.background, 0.35)
        border.color: theme.button.border
        border.width: Settings.appearance.enableBorder ? ScalerService.s(1) : 0
        radius: ScalerService.s(Settings.appearance.radius2)

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: ScalerService.s(14)
          spacing: ScalerService.s(8)

          Text {
            text: root.lang?.mixer?.input_device || "Input Device"
            color: theme.primary.foreground
            font.pixelSize: ScalerService.s(15)
            font.bold: true
            font.family: "ComicShannsMono Nerd Font"
          }

          ComboBox {
            id: inputCombo
            Layout.fillWidth: true
            model: root.inputNames
            enabled: root.inputDevices.length > 0
            displayText: currentIndex >= 0 ? root.inputNames[currentIndex] : "No input devices available"
            onActivated: selectedIndex => root.selectInput(selectedIndex)

            contentItem: Text {
              leftPadding: ScalerService.s(10)
              rightPadding: ScalerService.s(30)
              text: inputCombo.displayText
              color: inputCombo.enabled ? theme.primary.foreground : theme.primary.dim_foreground
              font.family: "ComicShannsMono Nerd Font"
              font.pixelSize: ScalerService.s(13)
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }

            background: Rectangle {
              color: theme.button.background
              border.color: inputCombo.activeFocus ? theme.button.border_select : theme.button.border
              border.width: ScalerService.s(1)
              radius: ScalerService.s(4)
            }

            delegate: ItemDelegate {
              width: inputCombo.width
              highlighted: inputCombo.highlightedIndex === index
              contentItem: Text {
                text: modelData
                color: highlighted ? theme.primary.foreground : theme.primary.dim_foreground
                font.family: "ComicShannsMono Nerd Font"
                font.pixelSize: ScalerService.s(13)
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
              }
              background: Rectangle {
                color: highlighted ? Qt.alpha(theme.accent, 0.3) : theme.button.background
              }
            }
          }
        }
      }
    }
  }
}
