import QtQuick
import Quickshell.Io
import qs.commons
import qs.services

Item {
    id: root

    property bool simplePackage: true
    property int totalPackage: 0
    property var dataModel: []
    property var packages: []
    property var sourceCounts: ({system: 0, user: 0, both: 0})
    property bool loading: false
    property bool available: false
    property bool partial: false
    property string error: ""
    property var warnings: []
    property var errors: []

    property var packageInfo: null
    property var references: []
    property bool infoLoading: false
    property bool infoAvailable: false
    property bool infoPartial: false
    property string infoError: ""
    property var infoWarnings: []
    property var infoErrors: []
    property string selectedId: ""

    property bool _ready: false
    property bool _refreshPending: false
    property int _infoToken: 0
    property var _pendingInfo: null

    function message(key) {
        return LanguageService.t("packages", key);
    }

    function diagnosticText(items) {
        return items.map(function (item) { return item.message || item.code; }).join("\n");
    }

    function validDiagnostics(data) {
        return data && data.schemaVersion === 1 && typeof data.available === "boolean"
            && typeof data.partial === "boolean" && Array.isArray(data.warnings)
            && Array.isArray(data.errors) && data.warnings.concat(data.errors).every(function (item) {
                return item && typeof item.code === "string" && typeof item.message === "string";
            });
    }

    function validRecord(record) {
        return record && typeof record.id === "string" && record.id === record.storePath
            && typeof record.name === "string" && typeof record.version === "string"
            && typeof record.versionInferred === "boolean" && typeof record.outputName === "string"
            && typeof record.description === "string" && typeof record.homepage === "string"
            && (record.narSize === null || (typeof record.narSize === "number" && Number.isFinite(record.narSize) && record.narSize >= 0))
            && Array.isArray(record.sources) && record.sources.length > 0
            && record.sources.every(function (source) { return source === "system" || source === "user"; });
    }

    function prepare(process) {
        process.invocation += 1;
        process.awaitingExit = true;
        process.exitedSeen = false;
        process.outputDone = false;
        process.exitCode = -1;
        process.exitStatus = -1;
    }

    function deferFailure(process, handler) {
        const invocation = process.invocation;
        Qt.callLater(function () {
            if (process.running || !process.awaitingExit || process.invocation !== invocation)
                return;
            process.awaitingExit = false;
            handler();
        });
    }

    function refresh() {
        cancelPackageInfo();
        if (listProc.busy) {
            _refreshPending = true;
            return;
        }
        _refreshPending = false;
        loading = true;
        available = false;
        partial = false;
        error = "";
        warnings = [];
        errors = [];
        dataModel = [];
        packages = [];
        listProc.busy = true;
        prepare(listProc);
        listProc.command = ["python3", Directories.scriptsPath + "/packages.py", simplePackage ? "summary" : "list"];
        listProc.running = true;
    }

    function finishList(failedToStart) {
        if (!listProc.busy || (!failedToStart && (!listProc.exitedSeen || !listProc.outputDone)))
            return;
        if (failedToStart) {
            error = message("start_failed");
        } else {
            try {
                const data = JSON.parse(listOutput.text);
                if (!validDiagnostics(data) || !Number.isInteger(data.total) || data.total < 0
                    || !data.sourceCounts || !Array.isArray(data.packages) || !Array.isArray(data.groups)
                    || !["system", "user", "both"].every(function (id) {
                        return Number.isInteger(data.sourceCounts[id]) && data.sourceCounts[id] >= 0;
                    }) || !data.packages.every(validRecord) || data.groups.length > 3
                    || !data.groups.every(function (group) {
                        return ["system", "user", "both"].indexOf(group.id) >= 0
                            && Number.isInteger(group.count) && group.count >= 0
                            && Array.isArray(group.packages) && group.packages.every(validRecord);
                    }))
                    throw new Error("schema");
                totalPackage = data.total;
                sourceCounts = data.sourceCounts;
                packages = data.packages;
                dataModel = data.groups;
                warnings = data.warnings;
                errors = data.errors;
                partial = data.partial;
                available = data.available && listProc.exitStatus === 0;
                error = diagnosticText(errors);
                if (listProc.exitCode !== 0 || listProc.exitStatus !== 0) {
                    error = error || message("process_failed");
                    partial = available;
                }
                if (!available)
                    error = error || message("unavailable");
            } catch (e) {
                error = message("invalid_response");
            }
        }
        listProc.busy = false;
        loading = false;
        if (_refreshPending)
            Qt.callLater(root.refresh);
    }

    function cancelPackageInfo() {
        _infoToken += 1;
        _pendingInfo = null;
        selectedId = "";
        packageInfo = null;
        references = [];
        infoLoading = false;
        infoAvailable = false;
        infoPartial = false;
        infoError = "";
        infoWarnings = [];
        infoErrors = [];
        if (infoProc.running)
            infoProc.running = false;
    }

    function getPackageInfo(id, callback) {
        _infoToken += 1;
        selectedId = id;
        packageInfo = null;
        references = [];
        infoLoading = true;
        infoAvailable = false;
        infoPartial = false;
        infoError = "";
        infoWarnings = [];
        infoErrors = [];
        _pendingInfo = {id: id, token: _infoToken, callback: callback || null};
        if (infoProc.busy) {
            if (infoProc.running)
                infoProc.running = false;
        } else {
            startPendingInfo();
        }
    }

    function startPendingInfo() {
        if (infoProc.busy || !_pendingInfo)
            return;
        infoProc.request = _pendingInfo;
        _pendingInfo = null;
        infoProc.busy = true;
        prepare(infoProc);
        infoProc.command = ["python3", Directories.scriptsPath + "/packages.py", "info", "--id", infoProc.request.id];
        infoProc.running = true;
    }

    function finishInfo(failedToStart) {
        if (!infoProc.busy || (!failedToStart && (!infoProc.exitedSeen || !infoProc.outputDone)))
            return;
        const request = infoProc.request;
        if (request.token === _infoToken && request.id === selectedId) {
            if (failedToStart) {
                infoError = message("start_failed");
            } else {
                try {
                    const data = JSON.parse(infoOutput.text);
                    if (!validDiagnostics(data) || !Array.isArray(data.references)
                        || !data.references.every(function (path) { return typeof path === "string"; })
                        || (data.package !== null && (!validRecord(data.package) || data.package.id !== request.id)))
                        throw new Error("schema");
                    packageInfo = data.package;
                    references = data.references;
                    infoWarnings = data.warnings;
                    infoErrors = data.errors;
                    infoPartial = data.partial;
                    infoAvailable = data.available && data.package !== null && infoProc.exitStatus === 0;
                    infoError = diagnosticText(infoErrors);
                    if (infoProc.exitCode !== 0 || infoProc.exitStatus !== 0) {
                        infoError = infoError || message("process_failed");
                        infoPartial = infoAvailable;
                    }
                    if (!infoAvailable)
                        infoError = infoError || message("unavailable");
                } catch (e) {
                    infoError = message("invalid_response");
                }
            }
            infoLoading = false;
            if (request.callback)
                request.callback(packageInfo);
        }
        infoProc.busy = false;
        infoProc.request = null;
        Qt.callLater(root.startPendingInfo);
    }

    onSimplePackageChanged: if (_ready) refresh()
    Component.onCompleted: {
        _ready = true;
        refresh();
    }

    Process {
        id: listProc
        property bool busy: false
        property bool awaitingExit: false
        property int invocation: 0
        property bool exitedSeen: false
        property bool outputDone: false
        property int exitCode: -1
        property int exitStatus: -1
        stdout: StdioCollector {
            id: listOutput
            onStreamFinished: {
                listProc.outputDone = true;
                root.finishList(false);
            }
        }
        onRunningChanged: if (!running) root.deferFailure(listProc, function () { root.finishList(true); })
        onExited: (code, status) => {
            awaitingExit = false;
            exitedSeen = true;
            exitCode = code;
            exitStatus = status;
            root.finishList(false);
        }
    }

    Process {
        id: infoProc
        property bool busy: false
        property bool awaitingExit: false
        property int invocation: 0
        property bool exitedSeen: false
        property bool outputDone: false
        property int exitCode: -1
        property int exitStatus: -1
        property var request: null
        stdout: StdioCollector {
            id: infoOutput
            onStreamFinished: {
                infoProc.outputDone = true;
                root.finishInfo(false);
            }
        }
        onRunningChanged: if (!running) root.deferFailure(infoProc, function () { root.finishInfo(true); })
        onExited: (code, status) => {
            awaitingExit = false;
            exitedSeen = true;
            exitCode = code;
            exitStatus = status;
            root.finishInfo(false);
        }
    }
}
