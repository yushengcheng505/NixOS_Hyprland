import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Fusion
import qs.services
import qs.components
import qs.commons

Item {
    id: root
    property int count: 0
    property real displayedCount: 0
    property real animationProgress: 0
    property bool loading: false
    property bool available: false
    property bool partial: false
    property string error: ""
    property var warnings: []
    readonly property bool revealCount: animationProgress > 0.9 && !loading && available

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumWidth: ScalerService.s(150)

    function updateCount() {
        countAnimation.stop();
        if (!revealCount)
            return;
        countAnimation.from = displayedCount;
        countAnimation.to = count;
        countAnimation.start();
    }

    onCountChanged: updateCount()
    onRevealCountChanged: updateCount()

    NumberAnimation {
        id: countAnimation
        target: root
        property: "displayedCount"
        duration: 400
        easing.type: Easing.OutCubic
    }

    Rectangle {
        anchors.centerIn: parent
        implicitWidth: root.animationProgress > 0.6 ? parent.width : 0
        implicitHeight: root.animationProgress > 0.6 ? parent.height : 0
        Behavior on implicitHeight {
            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
        }
        Behavior on implicitWidth {
            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
        }
        color: theme.primary.background
        radius: ScalerService.s(Settings.appearance.radius1)
        border.width: Settings.appearance.enableBorder ? ScalerService.s(3) : 0
        border.color: theme.button.border

        RowLayout {
            anchors.fill: parent
            anchors.margins: ScalerService.s(12)
            spacing: ScalerService.s(8)
            opacity: root.animationProgress > 0.8 ? 1 : 0

            IconText {
                name: "inventory_2"
                size: "normal"
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: ScalerService.s(2)
                CustomText {
                    Layout.fillWidth: true
                    name: LanguageService.t("packages", "title")
                    size: "small"
                    isBold: true
                    elide: Text.ElideRight
                }
                CustomText {
                    Layout.fillWidth: true
                    name: root.loading ? LanguageService.t("packages", "loading")
                        : !root.available ? LanguageService.t("packages", "unavailable")
                        : String(Math.round(root.displayedCount)) + (root.partial || root.error !== "" ? " · " + LanguageService.t("packages", "partial_short") : "")
                    size: "small"
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: VisibleService.togglePanel("packagePanel")
        }
        activeFocusOnTab: true
        Accessible.name: LanguageService.t("packages", "title")
        Accessible.role: Accessible.Button
        Keys.onReturnPressed: VisibleService.togglePanel("packagePanel")
        Keys.onSpacePressed: VisibleService.togglePanel("packagePanel")
        ToolTip.visible: cardMouse.containsMouse
        ToolTip.delay: 500
        ToolTip.text: [LanguageService.t("packages", "explanation"), root.error,
            root.warnings.map(function (item) { return item.message || item.code; }).join("\n")].filter(function (text) { return text.length > 0; }).join("\n")
    }
}
