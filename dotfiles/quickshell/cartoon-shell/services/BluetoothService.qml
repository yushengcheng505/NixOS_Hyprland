pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    property var scanRequests: []
    property var scanAdapter: null
    property bool scanStarted: false
    property bool stopRequested: false
    property bool scanAttempted: false
    property var pairingAdapter: null

    function preparePairing(requestAdapter) {
        if (!requestAdapter?.enabled || requestAdapter.state !== BluetoothAdapterState.Enabled)
            return false;
        pairingAdapter = requestAdapter;
        requestAdapter.pairableTimeout = 120;
        requestAdapter.discoverableTimeout = 120;
        requestAdapter.pairable = true;
        requestAdapter.discoverable = true;
        return true;
    }

    function requestScan(requester, active) {
        const requests = scanRequests.filter(item => item !== requester);
        if (active)
            requests.push(requester);
        scanRequests = requests;
        syncDiscovery();
    }

    function syncDiscovery() {
        const needed = scanRequests.length > 0 && adapter?.enabled && adapter.state === BluetoothAdapterState.Enabled;
        if (pairingAdapter && (pairingAdapter !== adapter || !needed)) {
            if (pairingAdapter.enabled && pairingAdapter.state === BluetoothAdapterState.Enabled) {
                pairingAdapter.discoverable = false;
                pairingAdapter.pairable = false;
            }
            pairingAdapter = null;
        }
        if (needed && !pairingAdapter) {
            pairingAdapter = adapter;
            adapter.pairableTimeout = 120;
            adapter.discoverableTimeout = 120;
            adapter.pairable = true;
            adapter.discoverable = true;
        }
        if (!needed)
            scanAttempted = false;
        if (scanAdapter) {
            if (scanAdapter.state !== BluetoothAdapterState.Enabled) {
                scanAdapter = null;
            } else if (scanAdapter.discovering) {
                scanStarted = true;
                if ((scanAdapter !== adapter || !needed) && !stopRequested) {
                    stopRequested = true;
                    scanAdapter.discovering = false;
                }
            } else if (scanStarted) {
                scanAdapter = null;
            }
        }
        if (needed && !scanAdapter && !scanAttempted) {
            scanAttempted = true;
            scanAdapter = adapter;
            scanStarted = false;
            stopRequested = false;
            adapter.discovering = true;
        }
    }

    onAdapterChanged: {
        scanAttempted = false;
        Qt.callLater(root.syncDiscovery);
    }

    Connections {
        target: root.adapter
        function onStateChanged() { Qt.callLater(root.syncDiscovery); }
    }

    Connections {
        target: root.scanAdapter
        function onStateChanged() { Qt.callLater(root.syncDiscovery); }
        function onDiscoveringChanged() { Qt.callLater(root.syncDiscovery); }
    }
}
