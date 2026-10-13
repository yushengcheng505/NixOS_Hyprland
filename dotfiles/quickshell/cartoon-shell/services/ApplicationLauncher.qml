pragma Singleton

import Quickshell

Singleton {
    function launchDesktopEntry(entry) {
        if (!entry || !entry.id)
            return;

        Quickshell.execDetached(["app2unit", "-t", "service", "-C", "--", entry.id + ".desktop"]);
    }

    function openUrl(url) {
        if (!url)
            return;

        Quickshell.execDetached(["app2unit", "-t", "service", "-C", "-O", "--", url]);
    }
}
