import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Item {
    id: wifiManager

    property var wifiList: []
    property bool wifiEnabled: true
    property string connectedWifi: ""
    property bool isScanning: false
    property string openSsid: ""
    property bool userTyping: false
    enabled: false
    property string connectionError: ""
    property bool connectionInProgress: false
    property string currentAttemptSSID: ""
    property string currentAttemptUUID: ""
    property string connectionStage: ""
    property bool connectionProcessPending: false
    property var savedConnections: ({})
    property var savedUUIDQueue: []
    property var nextSavedConnections: ({})
    property bool savedRefreshInProgress: false
    property bool savedRefreshFailed: false
    property string metadataUUID: ""
    property var pendingNetworks: null
    property bool forgetInProgress: false
    property string forgetSSID: ""

    signal connectionFinished(string ssid, bool success, string errorMessage)
    signal forgetFinished(string ssid, bool success)

    property bool activeRefreshRequested: false

    Process {
        id: wifiToggleProcess
        property bool awaitingExit: false
        property int invocation: 0
        onRunningChanged: if (!running) deferProcessFailure(wifiToggleProcess, function () {
            checkWifiStatus();
            checkConnectedWifi();
        })
        onExited: (exitCode, exitStatus) => {
            awaitingExit = false;
            if (wifiManager.enabled) {
                checkWifiStatus();
                checkConnectedWifi();
                scanWifiNetworks();
            }
        }
    }

    Process {
        id: wifiStatusProcess
        property bool awaitingExit: false
        property int invocation: 0
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector { id: radioOutput }
        onRunningChanged: if (!running) deferProcessFailure(wifiStatusProcess, function () {})
        onExited: (exitCode, exitStatus) => {
            awaitingExit = false;
            if (wifiManager.enabled && exitCode === 0 && exitStatus === 0) {
                wifiManager.wifiEnabled = radioOutput.text.trim() === "enabled";
                if (wifiManager.wifiEnabled) {
                    scanWifiNetworks();
                } else {
                    wifiManager.connectedWifi = "";
                    wifiManager.pendingNetworks = [];
                    applyPendingNetworks();
                }
            }
        }
    }

    Process {
        id: activeWifiProcess
        property bool awaitingExit: false
        property int invocation: 0
        command: ["nmcli", "--terse", "--escape", "yes", "--fields", "IN-USE,SSID", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector { id: activeWifiOutput }
        onRunningChanged: if (!running) deferProcessFailure(activeWifiProcess, function () {
            if (wifiManager.activeRefreshRequested)
                checkConnectedWifi();
        })
        onExited: (exitCode, exitStatus) => {
            awaitingExit = false;
            if (!wifiManager.enabled)
                return;
            if (exitCode === 0 && exitStatus === 0 && !wifiManager.connectionInProgress) {
                wifiManager.connectedWifi = parseActiveSSID(activeWifiOutput.text);
                applyPendingNetworks();
            }
            if (wifiManager.activeRefreshRequested)
                checkConnectedWifi();
        }
    }

    Process {
        id: wifiScanProcess
        property bool awaitingExit: false
        property int invocation: 0
        command: ["nmcli", "--terse", "--escape", "yes", "--fields", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        stdout: StdioCollector { id: scanOutput }
        onRunningChanged: if (!running) deferProcessFailure(wifiScanProcess, function () {
            wifiManager.isScanning = false;
        })
        onExited: (exitCode, exitStatus) => {
            awaitingExit = false;
            wifiManager.isScanning = false;
            if (wifiManager.enabled && exitCode === 0 && exitStatus === 0)
                parseWifiList(scanOutput.text);
        }
    }

    Process {
        id: savedListProcess
        property bool awaitingExit: false
        property int invocation: 0
        command: ["nmcli", "--terse", "--escape", "yes", "--fields", "TYPE,UUID", "connection", "show"]
        stdout: StdioCollector { id: savedListOutput }
        onRunningChanged: if (!running) deferProcessFailure(savedListProcess, abortSavedRefresh)
        onExited: (exitCode, exitStatus) => {
            awaitingExit = false;
            if (!wifiManager.enabled || !wifiManager.savedRefreshInProgress)
                return;
            if (exitCode !== 0 || exitStatus !== 0) {
                abortSavedRefresh();
                return;
            }
            wifiManager.savedUUIDQueue = parseSavedUUIDs(savedListOutput.text);
            readNextSavedSSID();
        }
    }

    Process {
        id: savedSsidProcess
        property bool awaitingExit: false
        property int invocation: 0
        stdout: StdioCollector { id: savedSsidOutput }
        onRunningChanged: if (!running) deferProcessFailure(savedSsidProcess, abortSavedRefresh)
        onExited: (exitCode, exitStatus) => {
            awaitingExit = false;
            if (!wifiManager.enabled || !wifiManager.savedRefreshInProgress)
                return;
            if (exitCode === 0 && exitStatus === 0) {
                const ssid = decodeNmcliValue(savedSsidOutput.text.replace(/\n$/, ""));
                if (ssid.length > 0 && !Object.prototype.hasOwnProperty.call(wifiManager.nextSavedConnections, ssid))
                    wifiManager.nextSavedConnections[ssid] = wifiManager.metadataUUID;
            } else {
                wifiManager.savedRefreshFailed = true;
            }
            readNextSavedSSID();
        }
    }

    Process {
        id: wifiConnectProcess
        property bool awaitingExit: false
        property int invocation: 0
        onRunningChanged: if (!running) deferProcessFailure(wifiConnectProcess, function () {
            if (!wifiManager.connectionProcessPending)
                return;
            wifiManager.connectionProcessPending = false;
            wifiConnectProcess.command = [];
            if (wifiManager.connectionInProgress)
                finishConnection(false);
            else
                checkConnectedWifi();
        })
        onExited: (exitCode, exitStatus) => {
            awaitingExit = false;
            wifiManager.connectionProcessPending = false;
            wifiConnectProcess.command = [];
            if (!wifiManager.connectionInProgress) {
                checkConnectedWifi();
                return;
            }
            if (exitCode === 0 && exitStatus === 0 && wifiManager.connectionStage === "updatePassword") {
                wifiManager.connectionStage = "activate";
                wifiManager.connectionProcessPending = true;
                wifiConnectProcess.command = ["nmcli", "connection", "up", "uuid", wifiManager.currentAttemptUUID];
                startProcess(wifiConnectProcess);
                return;
            }
            finishConnection(exitCode === 0 && exitStatus === 0);
        }
    }

    Process {
        id: forgetProcess
        property bool awaitingExit: false
        property int invocation: 0
        onRunningChanged: if (!running) deferProcessFailure(forgetProcess, function () {
            finishForget(false);
        })
        onExited: (exitCode, exitStatus) => {
            awaitingExit = false;
            finishForget(exitCode === 0 && exitStatus === 0);
        }
    }

    function startProcess(process) {
        process.invocation++;
        process.awaitingExit = true;
        process.running = true;
    }

    function deferProcessFailure(process, failureHandler) {
        const invocation = process.invocation;
        Qt.callLater(function () {
            if (process.running || !process.awaitingExit || process.invocation !== invocation)
                return;
            process.awaitingExit = false;
            failureHandler();
        });
    }

    function abortSavedRefresh() {
        savedRefreshInProgress = false;
        savedRefreshFailed = true;
        savedUUIDQueue = [];
        applyPendingNetworks();
    }

    function finishForget(success) {
        if (!forgetInProgress)
            return;
        const ssid = forgetSSID;
        forgetInProgress = false;
        forgetSSID = "";
        forgetFinished(ssid, success);
        checkConnectedWifi();
        if (success)
            refreshSavedConnections();
    }

    function parseActiveSSID(text) {
        const lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            const fields = splitNmcliFields(lines[i]);
            if (fields.length === 2 && fields[0] === "*" && fields[1].length > 0)
                return fields[1];
        }
        return "";
    }

    function decodeNmcliValue(value) {
        var decoded = "";
        for (var i = 0; i < value.length; i++) {
            if (value[i] === "\\" && i + 1 < value.length && (value[i + 1] === ":" || value[i + 1] === "\\"))
                i++;
            decoded += value[i];
        }
        return decoded;
    }

    function splitNmcliFields(line) {
        var fields = [];
        var field = "";
        for (var i = 0; i < line.length; i++) {
            const character = line[i];
            if (character === "\\" && i + 1 < line.length && (line[i + 1] === ":" || line[i + 1] === "\\")) {
                field += line[++i];
            } else if (character === ":") {
                fields.push(field);
                field = "";
            } else {
                field += character;
            }
        }
        fields.push(field);
        return fields;
    }

    function parseSavedUUIDs(text) {
        var uuids = [];
        const lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            const fields = splitNmcliFields(lines[i]);
            if (fields.length === 2 && (fields[0] === "802-11-wireless" || fields[0] === "wifi") && fields[1].length > 0)
                uuids.push(fields[1]);
        }
        return uuids;
    }

    function savedUUIDForSSID(ssid) {
        return Object.prototype.hasOwnProperty.call(savedConnections, ssid) ? savedConnections[ssid] : "";
    }

    function refreshSavedConnections() {
        if (!enabled || savedRefreshInProgress || savedListProcess.running || savedListProcess.awaitingExit || savedSsidProcess.running || savedSsidProcess.awaitingExit || connectionInProgress || forgetInProgress)
            return;
        savedRefreshInProgress = true;
        savedRefreshFailed = false;
        nextSavedConnections = Object.create(null);
        startProcess(savedListProcess);
    }

    function readNextSavedSSID() {
        if (savedUUIDQueue.length === 0) {
            savedRefreshInProgress = false;
            if (!savedRefreshFailed)
                savedConnections = nextSavedConnections;
            applyPendingNetworks();
            return;
        }
        metadataUUID = savedUUIDQueue.shift();
        savedSsidProcess.command = ["nmcli", "--terse", "--escape", "yes", "--get-values", "802-11-wireless.ssid", "connection", "show", "uuid", metadataUUID];
        startProcess(savedSsidProcess);
    }

    function checkWifiStatus() {
        if (enabled && !wifiStatusProcess.running && !wifiStatusProcess.awaitingExit)
            startProcess(wifiStatusProcess);
    }

    function scanWifiNetworks() {
        if (!enabled || !wifiEnabled || wifiScanProcess.running || wifiScanProcess.awaitingExit || connectionInProgress || userTyping || openSsid !== "")
            return;
        refreshSavedConnections();
        isScanning = true;
        startProcess(wifiScanProcess);
    }

    function toggleWifi() {
        if (!enabled || wifiToggleProcess.running || wifiToggleProcess.awaitingExit || connectionInProgress || connectionProcessPending || forgetInProgress)
            return;
        wifiToggleProcess.command = ["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"];
        startProcess(wifiToggleProcess);
    }

    function connectToWifi(ssid, password) {
        if (!enabled || !wifiEnabled || connectionInProgress || connectionProcessPending || wifiConnectProcess.running || wifiToggleProcess.running || wifiToggleProcess.awaitingExit || forgetInProgress || ssid.length === 0)
            return false;
        connectionError = "";
        currentAttemptSSID = ssid;
        currentAttemptUUID = savedUUIDForSSID(ssid);
        connectionStage = "activate";
        if (currentAttemptUUID !== "" && password !== undefined && password.length > 0) {
            connectionStage = "updatePassword";
            wifiConnectProcess.command = ["nmcli", "connection", "modify", "uuid", currentAttemptUUID, "802-11-wireless-security.psk", password];
        } else if (currentAttemptUUID !== "") {
            wifiConnectProcess.command = ["nmcli", "connection", "up", "uuid", currentAttemptUUID];
        } else if (password !== undefined && password.length > 0) {
            wifiConnectProcess.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password];
        } else {
            wifiConnectProcess.command = ["nmcli", "device", "wifi", "connect", ssid];
        }
        connectionInProgress = true;
        connectionProcessPending = true;
        startProcess(wifiConnectProcess);
        return true;
    }

    function finishConnection(success) {
        const ssid = currentAttemptSSID;
        connectionError = success ? "" : (LanguageService.translations?.wifi?.connection_failed || "Connection failed. Check credentials and network availability.");
        if (success)
            connectedWifi = ssid;
        connectionInProgress = false;
        currentAttemptSSID = "";
        currentAttemptUUID = "";
        connectionStage = "";
        connectionFinished(ssid, success, connectionError);
        checkConnectedWifi();
        if (success) {
            refreshSavedConnections();
            scanWifiNetworks();
        }
    }

    function cancelConnection() {
        currentAttemptSSID = "";
        connectionInProgress = false;
        currentAttemptUUID = "";
        connectionStage = "";
        connectionError = "";
        wifiConnectProcess.running = false;
        wifiConnectProcess.command = [];
        checkConnectedWifi();
    }

    function forgetPassword(ssid) {
        const uuid = savedUUIDForSSID(ssid);
        if (!enabled || uuid === "" || connectionInProgress || connectionProcessPending || forgetInProgress || forgetProcess.running || forgetProcess.awaitingExit)
            return false;
        forgetSSID = ssid;
        forgetInProgress = true;
        forgetProcess.command = ["nmcli", "connection", "delete", "uuid", uuid];
        startProcess(forgetProcess);
        return true;
    }

    function checkConnectedWifi() {
        if (!enabled)
            return;
        if (activeWifiProcess.running || activeWifiProcess.awaitingExit) {
            activeRefreshRequested = true;
            return;
        }
        activeRefreshRequested = false;
        startProcess(activeWifiProcess);
    }

    function parseWifiList(text) {
        const lines = text.split("\n");
        var networksMap = Object.create(null);
        var activeSSID = "";
        for (var i = 0; i < lines.length; i++) {
            const parts = splitNmcliFields(lines[i]);
            if (parts.length !== 4 || parts[1].length === 0)
                continue;
            const ssid = parts[1];
            const signal = parseInt(parts[2], 10) || 0;
            const active = parts[0] === "*";
            if (active)
                activeSSID = ssid;
            if (!Object.prototype.hasOwnProperty.call(networksMap, ssid)) {
                networksMap[ssid] = { ssid: ssid, signal: signal, security: parts[3] || "--", isConnected: active, hasSavedConnection: false };
            } else {
                const network = networksMap[ssid];
                network.isConnected = network.isConnected || active;
                if (signal > network.signal) {
                    network.signal = signal;
                    network.security = parts[3] || "--";
                }
            }
        }
        if (!connectionInProgress)
            connectedWifi = activeSSID;
        pendingNetworks = Object.values(networksMap).sort((a, b) => b.signal - a.signal);
        applyPendingNetworks();
    }

    function applyPendingNetworks() {
        if (!enabled || connectionInProgress || userTyping || openSsid !== "" || savedRefreshInProgress)
            return;
        const networks = pendingNetworks !== null ? pendingNetworks : wifiList;
        wifiList = networks.map(function (network) {
            return { ssid: network.ssid, signal: network.signal, security: network.security, isConnected: network.ssid === connectedWifi, hasSavedConnection: savedUUIDForSSID(network.ssid) !== "" };
        });
        pendingNetworks = null;
    }

    onOpenSsidChanged: applyPendingNetworks()
    onUserTypingChanged: applyPendingNetworks()

    Component.onCompleted: start()

    Timer {
        interval: 10000
        running: wifiManager.enabled
        repeat: true
        onTriggered: {
            if (!wifiManager.connectionInProgress && !wifiManager.userTyping && wifiManager.openSsid === "") {
                checkWifiStatus();
                scanWifiNetworks();
            }
        }
    }

    function start() {
        enabled = true;
        checkWifiStatus();
        checkConnectedWifi();
        scanWifiNetworks();
    }

    function stop() {
        enabled = false;
        cancelConnection();
        forgetInProgress = false;
        forgetSSID = "";
        savedRefreshInProgress = false;
        activeRefreshRequested = false;
        activeWifiProcess.running = false;
        wifiStatusProcess.running = false;
        wifiScanProcess.running = false;
        savedListProcess.running = false;
        savedSsidProcess.running = false;
        wifiToggleProcess.running = false;
        forgetProcess.running = false;
        isScanning = false;
        pendingNetworks = null;
        userTyping = false;
        openSsid = "";
    }
}
