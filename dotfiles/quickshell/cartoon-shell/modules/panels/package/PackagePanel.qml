import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Fusion
import Quickshell
import qs.commons
import qs.components
import qs.services

PanelWindow {
    id: root
    implicitWidth: ScalerService.s(1000)
    implicitHeight: ScalerService.s(750)
    color: "transparent"

    property string currentView: "groups"
    property string selectedGroup: ""
    readonly property bool isDetail: currentView === "info"
    readonly property var info: packageService.packageInfo
    readonly property var group: packageService.dataModel.find(function (item) { return item.id === root.selectedGroup; }) || null
    readonly property var groupPackages: group ? group.packages : []
    readonly property bool busy: isDetail ? packageService.infoLoading : packageService.loading
    readonly property bool available: isDetail ? packageService.infoAvailable : packageService.available
    readonly property string failure: isDetail ? packageService.infoError : packageService.error
    readonly property bool partial: isDetail ? packageService.infoPartial : packageService.partial
    readonly property var warnings: isDetail ? packageService.infoWarnings : packageService.warnings
    readonly property string notice: [partial ? tr("partial") : "", failure,
        packageService.diagnosticText(warnings)].filter(function (text) { return text.length > 0; }).join("\n")

    PackageService {
        id: packageService
        simplePackage: false
    }

    function tr(key) {
        return LanguageService.t("packages", key);
    }

    function sourceName(id) {
        return tr("source_" + id);
    }

    function versionLabel(record) {
        return record.version ? record.version + (record.versionInferred ? " " + tr("inferred") : "") : tr("unknown");
    }

    function openPackage(id) {
        currentView = "info";
        packageService.getPackageInfo(id);
    }

    function back() {
        packageService.cancelPackageInfo();
        currentView = isDetail ? "packages" : "groups";
    }

    function refresh() {
        currentView = "groups";
        selectedGroup = "";
        packageService.refresh();
    }

    function retry() {
        if (isDetail)
            packageService.getPackageInfo(packageService.selectedId);
        else
            refresh();
    }

    Rectangle {
        anchors.fill: parent
        radius: ScalerService.s(Settings.appearance.radius1)
        border.width: Settings.appearance.enableBorder ? ScalerService.s(3) : 0
        border.color: theme.primary.foreground
        color: theme.primary.background

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: ScalerService.s(24)
            spacing: ScalerService.s(14)

            RowLayout {
                Layout.fillWidth: true
                spacing: ScalerService.s(16)

                ButtonText {
                    visible: root.currentView !== "groups"
                    name: root.tr("back")
                    size: "small"
                    implicitHeight: ScalerService.s(44)
                    activeFocusOnTab: true
                    Keys.onReturnPressed: root.back()
                    Keys.onSpacePressed: root.back()
                    onClicked: root.back()
                }

                CustomText {
                    Layout.fillWidth: true
                    name: root.currentView === "groups" ? root.tr("title") : root.sourceName(root.selectedGroup)
                    size: "large"
                    isBold: true
                    elide: Text.ElideRight
                }

                ButtonText {
                    name: root.tr("refresh")
                    size: "small"
                    implicitHeight: ScalerService.s(44)
                    enabled: !packageService.loading
                    opacity: enabled ? 1 : 0.5
                    activeFocusOnTab: true
                    Keys.onReturnPressed: root.refresh()
                    Keys.onSpacePressed: root.refresh()
                    onClicked: root.refresh()
                }
            }

            CustomText {
                Layout.fillWidth: true
                name: root.tr("explanation")
                size: "small"
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }

            Rectangle {
                visible: root.notice !== ""
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(noticeText.implicitHeight + ScalerService.s(24), ScalerService.s(130))
                radius: ScalerService.s(12)
                color: theme.button.background
                border.color: theme.normal.yellow
                border.width: ScalerService.s(1)

                Flickable {
                    anchors.fill: parent
                    anchors.margins: ScalerService.s(12)
                    contentWidth: width
                    contentHeight: noticeText.implicitHeight
                    clip: true
                    ScrollBar.vertical: ScrollBar {}
                    CustomText {
                        id: noticeText
                        width: parent.width
                        name: root.notice
                        size: "small"
                        wrapMode: Text.WrapAnywhere
                        textFormat: Text.PlainText
                        textColor: theme.button.text
                    }
                }
            }

            ButtonText {
                visible: !root.busy && (root.failure !== "" || root.partial)
                name: root.tr("retry")
                size: "small"
                implicitHeight: ScalerService.s(44)
                activeFocusOnTab: true
                Keys.onReturnPressed: root.retry()
                Keys.onSpacePressed: root.retry()
                onClicked: root.retry()
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                CustomText {
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    size: "normal"
                    visible: root.busy || !root.available || (!root.isDetail && (root.currentView === "groups" ? packageService.totalPackage === 0 : root.groupPackages.length === 0))
                    name: root.busy ? root.tr(root.isDetail ? "loading_info" : "loading")
                        : !root.available ? root.tr("unavailable") : root.tr("empty")
                }

                RowLayout {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: ScalerService.s(18)
                    visible: root.currentView === "groups" && !root.busy && root.available && packageService.totalPackage > 0

                    Repeater {
                        model: packageService.dataModel
                        delegate: Item {
                            id: groupItem
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScalerService.s(280)
                            Rectangle {
                                id: bubble
                                anchors.centerIn: parent
                                width: Math.min(parent.width, ScalerService.s(250))
                                height: width
                                radius: width / 2
                                color: [theme.normal.green, theme.normal.blue, theme.normal.magenta][groupItem.index % 3]
                                border.width: ScalerService.s(activeFocus ? 4 : 2)
                                border.color: theme.primary.foreground
                                activeFocusOnTab: true
                                Accessible.name: root.sourceName(groupItem.modelData.id) + ": " + groupItem.modelData.count
                                Accessible.role: Accessible.Button
                                function openGroup() {
                                    root.selectedGroup = groupItem.modelData.id;
                                    root.currentView = "packages";
                                }
                                Keys.onReturnPressed: openGroup()
                                Keys.onSpacePressed: openGroup()
                                scale: bubbleMouse.containsMouse ? 1.03 : 1
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.8
                                    spacing: ScalerService.s(8)
                                    CustomText {
                                        Layout.fillWidth: true
                                        name: root.sourceName(groupItem.modelData.id)
                                        size: "normal"
                                        isBold: true
                                        textColor: theme.primary.background
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                    }
                                    CustomText {
                                        Layout.fillWidth: true
                                        name: String(groupItem.modelData.count)
                                        size: "xl"
                                        textColor: theme.primary.background
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                                MouseArea {
                                    id: bubbleMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bubble.openGroup()
                                }
                            }
                        }
                    }
                }

                ListView {
                    id: packageList
                    anchors.fill: parent
                    visible: root.currentView === "packages" && !root.busy && root.available
                    model: root.groupPackages
                    clip: true
                    spacing: ScalerService.s(8)
                    reuseItems: true
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        id: packageRow
                        required property var modelData
                        width: packageList.width - ScalerService.s(14)
                        height: ScalerService.s(98)
                        radius: ScalerService.s(14)
                        color: rowMouse.containsMouse ? theme.button.background_select : theme.button.background
                        border.width: ScalerService.s(activeFocus ? 2 : 1)
                        border.color: activeFocus ? theme.button.border_select : theme.button.border
                        activeFocusOnTab: true
                        Accessible.name: modelData.name + " " + root.versionLabel(modelData)
                        Accessible.role: Accessible.Button
                        Keys.onReturnPressed: root.openPackage(modelData.id)
                        Keys.onSpacePressed: root.openPackage(modelData.id)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: ScalerService.s(12)
                            spacing: ScalerService.s(2)
                            RowLayout {
                                Layout.fillWidth: true
                                CustomText {
                                    Layout.fillWidth: true
                                    name: packageRow.modelData.name
                                    isBold: true
                                    size: "normal"
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    textColor: theme.button.text
                                }
                                CustomText {
                                    Layout.maximumWidth: packageRow.width / 2
                                    name: root.versionLabel(packageRow.modelData) + " · " + (packageRow.modelData.outputName || root.tr("unknown"))
                                    size: "small"
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    textColor: theme.button.text
                                }
                            }
                            CustomText {
                                Layout.fillWidth: true
                                name: packageRow.modelData.storePath
                                size: "small"
                                elide: Text.ElideMiddle
                                textFormat: Text.PlainText
                                textColor: theme.button.text
                            }
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openPackage(packageRow.modelData.id)
                        }
                    }
                }

                Flickable {
                    anchors.fill: parent
                    visible: root.isDetail && !root.busy && root.available && root.info !== null
                    contentWidth: width
                    contentHeight: infoColumn.implicitHeight
                    clip: true
                    ScrollBar.vertical: ScrollBar {}

                    ColumnLayout {
                        id: infoColumn
                        width: parent.width - ScalerService.s(16)
                        spacing: ScalerService.s(12)
                        Repeater {
                            model: root.info ? [
                                [root.tr("name"), root.info.name],
                                [root.tr("version"), root.versionLabel(root.info)],
                                [root.tr("output"), root.info.outputName],
                                [root.tr("sources"), root.info.sources.map(root.sourceName).join(", ")],
                                [root.tr("store_path"), root.info.storePath],
                                [root.tr("description"), root.info.description],
                                [root.tr("homepage"), root.info.homepage],
                                [root.tr("nar_size"), typeof root.info.narSize === "number" && root.info.narSize >= 0
                                    ? (root.info.narSize / 1048576).toFixed(2) + " MiB" : root.tr("unknown")],
                                [root.tr("references"), packageService.references.length ? packageService.references.join("\n")
                                    : root.tr(packageService.infoPartial ? "unknown" : "none")]
                            ] : []
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: detailColumn.implicitHeight + ScalerService.s(28)
                                radius: ScalerService.s(14)
                                color: theme.button.background
                                border.width: ScalerService.s(1)
                                border.color: theme.button.border
                                ColumnLayout {
                                    id: detailColumn
                                    anchors.fill: parent
                                    anchors.margins: ScalerService.s(14)
                                    spacing: ScalerService.s(6)
                                    CustomText {
                                        Layout.fillWidth: true
                                        name: modelData[0]
                                        size: "normal"
                                        isBold: true
                                        textColor: theme.button.text
                                        textFormat: Text.PlainText
                                    }
                                    CustomText {
                                        Layout.fillWidth: true
                                        name: modelData[1] || root.tr("none")
                                        size: "small"
                                        wrapMode: Text.WrapAnywhere
                                        textFormat: Text.PlainText
                                        textColor: theme.button.text
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
