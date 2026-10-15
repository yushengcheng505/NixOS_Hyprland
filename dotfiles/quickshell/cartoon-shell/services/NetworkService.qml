pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: networkService

    property string connectedWifi: "Checking..."
    property bool wifiConnected: false
    property string wifi_icon: "wifi/no-wifi.png"
    property string wifi_icon_text_1: "wifi_off"
    property string wifi_icon_text_2: "signal_wifi_off"
    property int signal_current: 0

    signal wifiUpdated

    Process {
        id: wifiQueryProcess
        property bool awaitingExit: false
        property int invocation: 0
        command: ["nmcli", "--wait", "3", "--terse", "--escape", "yes", "--fields", "IN-USE,SSID,SIGNAL,DEVICE", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {}
        onRunningChanged: if (!running)
            networkService.deferProcessFailure(wifiQueryProcess, function () {
                networkService.setDisconnected();
            })
        onExited: (exitCode, exitStatus) => {
            awaitingExit = false;
            if (exitCode === 0 && exitStatus === 0)
                networkService.applyActiveAp(wifiQueryProcess.stdout.text);
            else
                networkService.setDisconnected();
            networkService.wifiUpdated();
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
            networkService.wifiUpdated();
        });
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

    function parseActiveAp(text) {
        const lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            const fields = splitNmcliFields(lines[i]);
            if (fields.length !== 4 || fields[0] !== "*" || fields[3].length === 0)
                continue;
            if (!/^\d+$/.test(fields[2]))
                continue;
            const signal = parseInt(fields[2], 10);
            if (signal > 100)
                continue;
            return {
                ssid: fields[1],
                signal: signal
            };
        }
        return null;
    }

    function applyActiveAp(text) {
        const ap = parseActiveAp(text);
        if (ap === null) {
            setDisconnected();
            return;
        }
        connectedWifi = ap.ssid.length > 0 ? ap.ssid : "Connected";
        signal_current = ap.signal;
        wifiConnected = true;
        updateWifiIcon();
    }

    function setDisconnected() {
        connectedWifi = "Disconnected";
        signal_current = 0;
        wifiConnected = false;
        wifi_icon = "wifi/no-wifi.png";
        wifi_icon_text_1 = "wifi_off";
        wifi_icon_text_2 = "signal_wifi_off";
    }

    function updateWifi() {
        if (!wifiQueryProcess.running && !wifiQueryProcess.awaitingExit)
            startProcess(wifiQueryProcess);
    }

    function updateSignalWifi() {
        updateWifi();
    }

    function updateWifiIcon() {
        if (!wifiConnected) {
            wifi_icon = "wifi/no-wifi.png";
            wifi_icon_text_1 = "wifi_off";
            wifi_icon_text_2 = "signal_wifi_off";
        } else if (signal_current <= 40) {
            wifi_icon = "wifi/wifi_1.png";
            wifi_icon_text_1 = "wifi_1_bar";
            wifi_icon_text_2 = "network_wifi_1_bar";
        } else if (signal_current <= 70) {
            wifi_icon = "wifi/wifi_2.png";
            wifi_icon_text_1 = "wifi_2_bar";
            wifi_icon_text_2 = "network_wifi_3_bar";
        } else {
            wifi_icon = "wifi/wifi.png";
            wifi_icon_text_1 = "android_wifi_3_bar";
            wifi_icon_text_2 = "signal_wifi_4_bar";
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: networkService.updateWifi()
    }
}
