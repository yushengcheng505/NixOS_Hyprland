pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.commons

Singleton {
    id: root

    property bool ready: false

    readonly property alias appearance: adapter.appearance
    readonly property alias wallpaper: adapter.wallpaper
    readonly property alias general: adapter.general
    readonly property alias effects: adapter.effects
    readonly property alias clock: adapter.clock
    readonly property alias weather: adapter.weather
    readonly property alias bar: adapter.bar
    readonly property alias dashboard: adapter.dashboard

    signal settingsLoaded
    signal settingsSaved

    Component.onCompleted: {
        settingsFileView.adapter = adapter;
    }

    Timer {
        id: saveTimer
        running: false
        interval: 1000
        onTriggered: {
            root.saveImmediate();
        }
    }

    function saveImmediate() {
        settingsFileView.writeAdapter();
        root.ready = true;
        root.settingsSaved();
    }

    FileView {
        id: settingsFileView
        path: Directories.shellConfigSettingsPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: saveTimer.start()
        onPathChanged: {
            if (path !== undefined) {
                reload();
            }
        }
        onLoaded: function () {
            if (!root.ready) {
                root.ready = true;
                root.settingsLoaded();
            }
        }
        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound) {
                writeAdapter();
            }
        }
    }

    JsonAdapter {
        id: adapter

        property Wallpaper wallpaper: Wallpaper {}
        property Appearance appearance: Appearance {}
        property General general: General {}
        property Effects effects: Effects {}
        property Clock clock: Clock {}
        property Weather weather: Weather {}
        property Bar bar: Bar {}
        property Dashboard dashboard: Dashboard {}
    }

    component Effects: JsonObject {
        property string workspaceAnimation: ""
    }
    component Dashboard: JsonObject {
        property string fullname: "long"
        property string urlAvatar: ""
        property string username: "klenko"
        property var appGrid: [
            {
                "name": "firefox"
            },
            {
                "name": "firefox"
            },
            {
                "name": "firefox"
            },
            {
                "name": "firefox"
            },
            {
                "name": "firefox"
            },
            {
                "name": "firefox"
            },
            {
                "name": "firefox"
            },
            {
                "name": "firefox"
            },
            {
                "name": "firefox"
            }
        ]
    }

    component Bar: JsonObject {
        property string position: "top"
        property string style: "style3"
        property string styleWorkspace: "image"
        property string iconWorkspace: "pacman"
        property string iconLauncher: "default"
        property int workspaceCount: 9
        property var ram: {
            "style": 1,
            "active": true
        }
        property var cpu: {
            "style": 1,
            "active": true
        }
        property var disk: {
            "style": 1,
            "active": true
        }
        property var brightness: {
            "style": 1,
            "active": true
        }
        property var battery: {
            "style": 1,
            "active": true
        }
        property var bluetooth: {
            "style": 1,
            "active": true
        }
        property var wifi: {
            "style": 1,
            "active": true
        }
        property var volume: {
            "style": 1,
            "active": true
        }
    }

    component Clock: JsonObject {
        property string timeFormat: "24h"
        property bool enableWidget: false
        property string positionWidget: "top"
    }

    component Weather: JsonObject {
        property string keyApi: ""
        property string location: "Moscow,Russia"
    }

    component Appearance: JsonObject {
        property string theme: "matugen"
        property string mode: "dark"
        property string countryFlag: "russia"
        property string fonts: ""
        property string styleIcons: "image"
        property int radius1: 22
        property int radius2: 16
        property int radius3: 8
        property bool enableBorder: false
        // Thêm các properties cho dynamic theme
        property bool dynamic: false
        property string light: "light"
        property string dark: "dark"
        property string matugenType: "scheme-tonal-spot"
        property string font: "ComicShannsMono Nerd Font"
    }

    component General: JsonObject {
        property string lang: "ru"
        property bool showSideWidgets: false
        property real screenHeight: 2080
        property real screenWidth: 3120
        property real scale: 1.7
    }

    component Wallpaper: JsonObject {
        property bool enabled: true
        property bool overviewEnabled: true
        property string directory: Directories.defaultWallpaperDir
        property bool enableMultiMonitorDirectories: false
        property bool recursiveSearch: false
        property bool setWallpaperOnAllMonitors: true
        property string defaultWallpaper: ""
        property string fillMode: "crop"
        property color fillColor: "#000000"
        property int shaders: 0
        property list<var> monitors: []
        property int transitionDuration: 1500
        property real transitionEdgeSmoothness: 0.1
        // Video-specific properties
        property bool videoMuted: true
        property bool videoLoop: true
        property real videoPlaybackRate: 1.0
    }
}
