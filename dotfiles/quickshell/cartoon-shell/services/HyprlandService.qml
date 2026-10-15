import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

Item {
    id: root

    // Properties that match the facade interface
    property ListModel workspaces: ListModel {}
    property var windows: []
    property int focusedWindowIndex: -1
    property int focusedWorkspaceId: -1

    // Signals that match the facade interface
    signal workspaceChanged
    signal activeWindowChanged
    signal windowListChanged
    signal displayScalesChanged

    // Hyprland-specific properties
    property bool initialized: false
    property var workspaceCache: ({})
    property var windowCache: ({})

    property bool windowsDirty: false
    property bool workspacesDirty: false
    property bool scalesDirty: false

    Timer {
        id: updateTimer
        interval: 50
        repeat: false
        onTriggered: root.flushUpdates()
    }

    // Initialization
    function initialize() {
        if (initialized)
            return;
        try {
            Hyprland.refreshToplevels();
            Qt.callLater(() => {
                safeUpdateWorkspaces();
                safeUpdateWindows();
                queryDisplayScales();
            });
            initialized = true;
        } catch (e) {}
    }

    function markWindowsDirty() {
        if (!windowsDirty) {
            windowsDirty = true;
            updateTimer.restart();
        }
    }

    function markWorkspacesDirty() {
        if (!workspacesDirty) {
            workspacesDirty = true;
            updateTimer.restart();
        }
    }

    function markScalesDirty() {
        if (!scalesDirty) {
            scalesDirty = true;
            updateTimer.restart();
        }
    }

    function flushUpdates() {
        if (windowsDirty) {
            windowsDirty = false;
            safeUpdateWindows();
            windowListChanged();
        }
        if (workspacesDirty) {
            workspacesDirty = false;
            safeUpdateWorkspaces();
            workspaceChanged();
        }
        if (scalesDirty) {
            scalesDirty = false;
            queryDisplayScales();
        }
    }

    // Query display scales
    function queryDisplayScales() {
        hyprlandMonitorsProcess.running = true;
    }

    // Hyprland monitors process for display scale detection
    Process {
        id: hyprlandMonitorsProcess
        running: false
        command: ["hyprctl", "monitors", "-j"]

        property string accumulatedOutput: ""

        stdout: SplitParser {
            onRead: function (line) {
                // Accumulate lines instead of parsing each one
                hyprlandMonitorsProcess.accumulatedOutput += line;
            }
        }

        onExited: function (exitCode) {
            if (exitCode !== 0 || !accumulatedOutput) {
                accumulatedOutput = "";
                return;
            }

            try {
                const monitorsData = JSON.parse(accumulatedOutput);
                const scales = {};

                for (const monitor of monitorsData) {
                    if (monitor.name) {
                        scales[monitor.name] = {
                            "name": monitor.name,
                            "scale": monitor.scale || 1.0,
                            "width": monitor.width || 0,
                            "height": monitor.height || 0,
                            "refresh_rate": monitor.refreshRate || 0,
                            "x": monitor.x || 0,
                            "y": monitor.y || 0,
                            "active_workspace": monitor.activeWorkspace ? monitor.activeWorkspace.id : -1,
                            "vrr": monitor.vrr || false,
                            "focused": monitor.focused || false
                        };
                    }
                }

                // Notify CompositorService (it will emit displayScalesChanged)
                if (CompositorService && CompositorService.onDisplayScalesUpdated) {
                    CompositorService.onDisplayScalesUpdated(scales);
                }
            } catch (e) {} finally {
                // Clear accumulated output for next query
                accumulatedOutput = "";
            }
        }
    }

    // Safe workspace update
    function safeUpdateWorkspaces() {
        try {
            workspaces.clear();
            workspaceCache = {};

            if (!Hyprland.workspaces || !Hyprland.workspaces.values) {
                root.focusedWorkspaceId = -1;
                return;
            }

            const hlWorkspaces = Hyprland.workspaces.values;
            const occupiedIds = getOccupiedWorkspaceIds();
            let newFocusedId = -1;

            for (var i = 0; i < hlWorkspaces.length; i++) {
                const ws = hlWorkspaces[i];
                if (!ws || ws.id < 1)
                    continue;
                const wsData = {
                    "id": ws.id,
                    "idx": ws.id,
                    "name": ws.name || "",
                    "output": (ws.monitor && ws.monitor.name) ? ws.monitor.name : "",
                    "isActive": ws.active === true,
                    "isFocused": ws.focused === true,
                    "isUrgent": ws.urgent === true,
                    "isOccupied": occupiedIds[ws.id] === true
                };

                workspaceCache[ws.id] = wsData;
                workspaces.append(wsData);

                if (wsData.isFocused) {
                    newFocusedId = wsData.id;
                }
            }
            root.focusedWorkspaceId = newFocusedId;
        } catch (e) {}
    }

    // Get occupied workspace IDs safely
    function getOccupiedWorkspaceIds() {
        const occupiedIds = {};

        try {
            if (!Hyprland.toplevels || !Hyprland.toplevels.values) {
                return occupiedIds;
            }

            const hlToplevels = Hyprland.toplevels.values;
            for (var i = 0; i < hlToplevels.length; i++) {
                const toplevel = hlToplevels[i];
                if (!toplevel)
                    continue;
                try {
                    const wsId = toplevel.workspace ? toplevel.workspace.id : null;
                    if (wsId !== null && wsId !== undefined) {
                        occupiedIds[wsId] = true;
                    }
                } catch (e) {

                    // Ignore individual toplevel errors
                }
            }
        } catch (e) {

            // Return empty if we can't determine occupancy
        }

        return occupiedIds;
    }

    // Safe window update
    function safeUpdateWindows() {
        try {
            const windowsList = [];
            windowCache = {};

            if (!Hyprland.toplevels || !Hyprland.toplevels.values) {
                windows = [];
                focusedWindowIndex = -1;
                return;
            }

            const hlToplevels = Hyprland.toplevels.values;
            let newFocusedIndex = -1;

            for (var i = 0; i < hlToplevels.length; i++) {
                const toplevel = hlToplevels[i];
                if (!toplevel)
                    continue;
                const windowData = extractWindowData(toplevel);
                if (windowData) {
                    windowsList.push(windowData);
                    windowCache[windowData.id] = windowData;

                    if (windowData.isFocused) {
                        newFocusedIndex = windowsList.length - 1;
                    }
                }
            }

            windows = windowsList;

            if (newFocusedIndex !== focusedWindowIndex) {
                focusedWindowIndex = newFocusedIndex;
                activeWindowChanged();
            }
        } catch (e) {}
    }

    // Extract window data safely from a toplevel
    function extractWindowData(toplevel) {
        if (!toplevel)
            return null;

        try {
            // Safely extract properties
            const windowId = safeGetProperty(toplevel, "address", "");
            if (!windowId)
                return null;

            const appId = getAppId(toplevel);
            const title = getAppTitle(toplevel);
            const wsId = toplevel.workspace ? toplevel.workspace.id : null;
            const focused = toplevel.activated === true;
            const output = toplevel.monitor?.name || "";

            return {
                "id": windowId,
                "title": title,
                "appId": appId,
                "workspaceId": wsId || -1,
                "isFocused": focused,
                "output": output
            };
        } catch (e) {
            return null;
        }
    }

    function getAppTitle(toplevel) {
        try {
            var title = toplevel.wayland.title;
            if (title)
                return title;
        } catch (e) {}

        return safeGetProperty(toplevel, "title", "");
    }

    function getAppId(toplevel) {
        if (!toplevel)
            return "";

        var appId = "";

        // Try the wayland object first!
        // From my (Lemmy) testing it works fine so we could probably get rid of all the other attempts below.
        // Leaving them in for now, just in case...
        try {
            appId = toplevel.wayland.appId;
            if (appId)
                return appId;
        } catch (e) {}

        // Try direct properties
        appId = safeGetProperty(toplevel, "class", "");
        if (appId)
            return appId;

        appId = safeGetProperty(toplevel, "initialClass", "");
        if (appId)
            return appId;

        appId = safeGetProperty(toplevel, "appId", "");
        if (appId)
            return appId;

        // Try lastIpcObject
        try {
            const ipcData = toplevel.lastIpcObject;
            if (ipcData) {
                return String(ipcData.class || ipcData.initialClass || ipcData.appId || ipcData.wm_class || "");
            }
        } catch (e) {}

        return "";
    }

    // Safe property getter
    function safeGetProperty(obj, prop, defaultValue) {
        try {
            const value = obj[prop];
            if (value !== undefined && value !== null) {
                return String(value);
            }
        } catch (e) {

            // Property access failed
        }
        return defaultValue;
    }

    // Connections to Hyprland
    Connections {
        target: Hyprland.workspaces
        enabled: root.initialized
        function onValuesChanged() {
            if (VisibleService.getPanelVisible("shortcutMenu")) {
                VisibleService.togglePanel("shortcutMenu");
            }
            if (VisibleService.getPanelVisible("hasPanel")) {
                VisibleService.closeAllPanels();
            }
            root.safeUpdateWorkspaces();
            root.workspacesDirty = false;
            root.workspaceChanged();
        }
    }

    Connections {
        target: Hyprland.toplevels
        enabled: root.initialized
        function onValuesChanged() {
            root.markWindowsDirty();
            root.markWorkspacesDirty();
        }
    }

    Connections {
        target: Hyprland.monitors
        enabled: root.initialized
        function onValuesChanged() {
            root.markWindowsDirty();
            root.markWorkspacesDirty();
            root.markScalesDirty();
        }
    }

    Connections {
        target: Hyprland
        enabled: root.initialized

        function onFocusedWorkspaceChanged() {
            root.markWorkspacesDirty();
        }
        function onFocusedMonitorChanged() {
            root.markWindowsDirty();
            root.markWorkspacesDirty();
        }
        function onActiveToplevelChanged() {
            root.markWindowsDirty();
        }

        function onRawEvent(event) {
            const name = event ? event.name : "";
            const windowOnly = ["windowtitle", "windowtitlev2"];
            const workspaceOnly = ["workspace", "workspacev2", "renameworkspace", "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "urgent", "focusedmon", "activespecial", "activespecialv2"];
            const windowAndWorkspace = ["activewindow", "activewindowv2", "moveworkspace", "moveworkspacev2", "openwindow", "closewindow", "movewindow", "movewindowv2", "fullscreen"];
            const monitors = ["monitoradded", "monitorremoved", "monitoraddedv2", "monitorremovedv2", "configreloaded"];

            if (windowOnly.includes(name)) {
                root.markWindowsDirty();
            } else if (workspaceOnly.includes(name)) {
                root.markWorkspacesDirty();
            } else if (windowAndWorkspace.includes(name)) {
                root.markWindowsDirty();
                root.markWorkspacesDirty();
            } else if (monitors.includes(name)) {
                root.markWindowsDirty();
                root.markWorkspacesDirty();
                root.markScalesDirty();
            }
        }
    }

    Instantiator {
        model: Hyprland.workspaces ? Hyprland.workspaces.values : []
        active: root.initialized
        delegate: Connections {
            required property var modelData
            target: modelData

            function onNameChanged() {
                root.markWorkspacesDirty();
            }
            function onActiveChanged() {
                root.markWorkspacesDirty();
            }
            function onFocusedChanged() {
                root.markWorkspacesDirty();
            }
            function onUrgentChanged() {
                root.markWorkspacesDirty();
            }
            function onHasFullscreenChanged() {
                root.markWindowsDirty();
                root.markWorkspacesDirty();
            }
            function onMonitorChanged() {
                root.markWindowsDirty();
                root.markWorkspacesDirty();
            }
        }
    }

    Instantiator {
        model: Hyprland.toplevels ? Hyprland.toplevels.values : []
        active: root.initialized
        delegate: Connections {
            required property var modelData
            target: modelData

            function onTitleChanged() {
                root.markWindowsDirty();
            }
            function onActivatedChanged() {
                root.markWindowsDirty();
                root.markWorkspacesDirty();
            }
            function onUrgentChanged() {
                root.markWorkspacesDirty();
            }
            function onWorkspaceChanged() {
                root.markWindowsDirty();
                root.markWorkspacesDirty();
            }
            function onMonitorChanged() {
                root.markWindowsDirty();
            }
        }
    }

    Instantiator {
        model: Hyprland.monitors ? Hyprland.monitors.values : []
        active: root.initialized
        delegate: Connections {
            required property var modelData
            target: modelData

            function onScaleChanged() {
                root.markScalesDirty();
            }
            function onXChanged() {
                root.markScalesDirty();
            }
            function onYChanged() {
                root.markScalesDirty();
            }
            function onWidthChanged() {
                root.markScalesDirty();
            }
            function onHeightChanged() {
                root.markScalesDirty();
            }
            function onActiveWorkspaceChanged() {
                root.markWorkspacesDirty();
            }
            function onFocusedChanged() {
                root.markWorkspacesDirty();
            }
        }
    }

    // Public functions
    function switchToWorkspace(workspace) {
        try {
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspace.idx}})`);
        } catch (e) {}
    }

    function focusWindow(window) {
        try {
            Hyprland.dispatch(`focuswindow address:0x${window.id.toString()}`);
        } catch (e) {}
    }

    function closeWindow(window) {
        try {
            Hyprland.dispatch(`killwindow address:0x${window.id}`);
        } catch (e) {}
    }

    function logout() {
        try {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]);
        } catch (e) {}
    }
}
