pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Keep BlueZ discovery active independently of the panel loader. The panel is
// created only while visible, but the device model should continue receiving
// nearby-device announcements between openings.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter

    Timer {
        interval: 10000
        repeat: true
        running: root.adapter?.enabled ?? false
        onTriggered: root.ensureAdapterReady()
    }

    Connections {
        target: root.adapter
        enabled: !!root.adapter

        function onEnabledChanged() {
            if (root.adapter?.enabled)
                root.ensureAdapterReady();
        }
    }

    function ensureAdapterReady() {
        if (!root.adapter?.enabled)
            return;

        root.adapter.pairable = true;
        if (!root.adapter.discovering)
            root.adapter.discovering = true;
    }

    Component.onCompleted: ensureAdapterReady()
}
