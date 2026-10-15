pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    function applicationPath() {
        const home = Quickshell.env("HOME");
        const user = Quickshell.env("USER");
        const paths = [];
        if (home) {
            paths.push(home + "/.local/bin", home + "/.nix-profile/bin");
            paths.push((Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/nix/profile/bin");
        }
        if (user)
            paths.push("/etc/profiles/per-user/" + user + "/bin");
        const inherited = Quickshell.env("PATH");
        if (inherited)
            paths.push(inherited);
        return paths.join(":");
    }

    function launch(arguments) {
        const path = applicationPath();
        Quickshell.execDetached({
            command: ["app2unit", "-t", "service", "-C", "-p", "Environment=PATH=" + path].concat(arguments),
            environment: { PATH: path }
        });
    }

    function launchDesktopEntry(entry) {
        if (!entry || !entry.id)
            return;

        launch(["--", entry.id + ".desktop"]);
    }

    function openUrl(url) {
        if (!url)
            return;

        launch(["-O", "--", url]);
    }
}
